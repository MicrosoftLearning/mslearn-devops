using System.Text;
using Azure.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.eShopWeb.ChatShared;

namespace Microsoft.eShopWeb.ChatApi.Controllers;

[ApiController]
[Route("chat")]
public sealed class CatalogChatController : ControllerBase
{
    private readonly FoundryChatClient _client;
    private readonly ILogger<CatalogChatController> _logger;

    public CatalogChatController(FoundryChatClient client, ILogger<CatalogChatController> logger)
    {
        _client = client;
        _logger = logger;
    }

    [HttpPost]
    [EnableRateLimiting("chat")]
    [RequestSizeLimit(ChatLimits.MaxRequestBytes)]
    public async Task<IActionResult> Post(GroundedChatRequest request)
    {
        var validationError = ChatLimits.ValidateMessages(request.Messages) ??
            ChatLimits.ValidateCatalog(request.Products);
        if (validationError is not null)
        {
            _logger.LogWarning("Rejected invalid grounded chat request: {Reason}", validationError);
            return Problem(validationError, statusCode: StatusCodes.Status400BadRequest);
        }

        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(HttpContext.RequestAborted);
        timeout.CancelAfter(TimeSpan.FromSeconds(ChatLimits.TimeoutSeconds));
        using var operation = new ChatOperation();
        Response.ContentType = "text/event-stream";
        Response.Headers.CacheControl = "no-store";
        Response.Headers["X-Accel-Buffering"] = "no";
        try
        {
            var answer = new StringBuilder();
            await foreach (var text in _client.StreamAsync(request, timeout.Token))
            {
                if (answer.Length + text.Length > ChatLimits.MaxAnswerLength)
                {
                    throw new InvalidDataException("The assistant answer is too large.");
                }
                answer.Append(text);
                await ChatStream.WriteAsync(Response.Body, new ChatEvent("delta", Text: text), timeout.Token);
            }
            var completed = ChatReferences.Complete(answer.ToString(), request.Products);
            await ChatStream.WriteAsync(Response.Body,
                new ChatEvent("completed", Text: completed.Text, ProductIds: completed.ProductIds), timeout.Token);
            operation.Complete();
        }
        catch (OperationCanceledException) when (HttpContext.RequestAborted.IsCancellationRequested)
        {
            operation.Cancel();
            _logger.LogDebug("Catalog chat request was cancelled by the client.");
        }
        catch (OperationCanceledException ex)
        {
            operation.Fail("timeout");
            _logger.LogWarning(ex, "Catalog chat request timed out.");
            return await ReportFailureAsync("The catalog assistant timed out. Please try again.");
        }
        catch (Exception ex) when (ex is HttpRequestException or IOException or System.Text.Json.JsonException
            or AuthenticationFailedException or CredentialUnavailableException)
        {
            operation.Fail("upstream_error");
            _logger.LogError(ex, "Catalog chat could not complete a Foundry response.");
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
