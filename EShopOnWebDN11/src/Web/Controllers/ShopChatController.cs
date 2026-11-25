using System.Text;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.eShopWeb.ChatShared;
using Microsoft.eShopWeb.Web.Services;
using Microsoft.Extensions.Options;

namespace Microsoft.eShopWeb.Web.Controllers;

[ApiController]
[Route("api/chat")]
public sealed class ShopChatController : ControllerBase
{
    private readonly ShopChatService _service;
    private readonly ShopChatOptions _options;
    private readonly ILogger<ShopChatController> _logger;

    public ShopChatController(ShopChatService service, IOptions<ShopChatOptions> options,
        ILogger<ShopChatController> logger)
    {
        _service = service;
        _options = options.Value;
        _logger = logger;
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting("catalog-chat")]
    [RequestSizeLimit(ChatLimits.MaxRequestBytes)]
    public async Task<IActionResult> Post(ShopperChatRequest request)
    {
        if (!_options.Enabled)
        {
            _logger.LogWarning("A catalog chat request was made while chat is disabled.");
            return Problem("The catalog assistant is not enabled.", statusCode: StatusCodes.Status503ServiceUnavailable);
        }
        var validationError = ChatLimits.ValidateMessages(request.Messages);
        if (validationError is not null)
        {
            _logger.LogWarning("Rejected shopper chat request: {Reason}", validationError);
            return Problem(validationError, statusCode: StatusCodes.Status400BadRequest);
        }

        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(HttpContext.RequestAborted);
        timeout.CancelAfter(TimeSpan.FromSeconds(ChatLimits.TimeoutSeconds));
        try
        {
            var products = await _service.GetCatalogAsync(timeout.Token);
            Response.ContentType = "text/event-stream";
            Response.Headers.CacheControl = "no-store";
            Response.Headers["X-Accel-Buffering"] = "no";
            var answer = new StringBuilder();
            await foreach (var item in _service.StreamAsync(request, products, timeout.Token))
            {
                switch (item.Type)
                {
                    case "delta" when item.Text is not null:
                        if (answer.Length + item.Text.Length > ChatLimits.MaxAnswerLength)
                        {
                            throw new InvalidDataException("ChatApi returned an oversized answer.");
                        }
                        answer.Append(item.Text);
                        await ChatStream.WriteAsync(Response.Body, new ChatEvent("delta", Text: item.Text), timeout.Token);
                        break;
                    case "completed":
                        var completed = ChatReferences.Complete(answer.ToString(), products);
                        if (item.Text != completed.Text || item.ProductIds is null ||
                            !item.ProductIds.SequenceEqual(completed.ProductIds))
                        {
                            throw new InvalidDataException("ChatApi returned inconsistent product references.");
                        }
                        var cards = completed.ProductIds.Select(id =>
                        {
                            var product = products.Single(p => p.Id == id);
                            var url = Url.Page("/Index", new
                            {
                                BrandFilterApplied = product.BrandId,
                                TypesFilterApplied = product.TypeId
                            }) ?? throw new InvalidOperationException("The catalog page URL could not be generated.");
                            return new ProductCard(product.Id, product.Name, product.Price, product.PictureUri, url);
                        }).ToArray();
                        await ChatStream.WriteAsync(Response.Body,
                            new ChatEvent("completed", Text: completed.Text, Products: cards), timeout.Token);
                        return new EmptyResult();
                    case "error":
                        throw new InvalidDataException("ChatApi reported a failure.");
                    default:
                        throw new InvalidDataException("ChatApi returned an invalid event.");
                }
            }
            throw new InvalidDataException("ChatApi ended the stream without completing the answer.");
        }
        catch (OperationCanceledException) when (HttpContext.RequestAborted.IsCancellationRequested)
        {
            _logger.LogDebug("The shopper cancelled the chat request.");
        }
        catch (OperationCanceledException ex)
        {
            _logger.LogWarning(ex, "The catalog assistant timed out.");
            return await ReportFailureAsync("The catalog assistant timed out. Please try again.");
        }
        catch (Exception ex) when (ex is HttpRequestException or IOException or System.Text.Json.JsonException)
        {
            _logger.LogError(ex, "The catalog assistant could not complete a response.");
            return await ReportFailureAsync("The catalog assistant is unavailable. Please try again.");
        }
        return new EmptyResult();
    }

    private async Task<IActionResult> ReportFailureAsync(string message)
    {
        if (!Response.HasStarted)
        {
            return Problem(message, statusCode: StatusCodes.Status503ServiceUnavailable);
        }
        await ChatStream.WriteAsync(Response.Body, new ChatEvent("error", Error: message), HttpContext.RequestAborted);
        return new EmptyResult();
    }
}
