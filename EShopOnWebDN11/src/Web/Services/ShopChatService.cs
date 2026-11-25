using System.Net.Http.Json;
using System.Runtime.CompilerServices;
using Microsoft.eShopWeb.ApplicationCore.Entities;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.ChatShared;

namespace Microsoft.eShopWeb.Web.Services;

public sealed class ShopChatService
{
    private readonly HttpClient _client;
    private readonly IReadRepository<CatalogItem> _items;
    private readonly IReadRepository<CatalogBrand> _brands;
    private readonly IReadRepository<CatalogType> _types;
    private readonly IUriComposer _uriComposer;

    public ShopChatService(HttpClient client, IReadRepository<CatalogItem> items,
        IReadRepository<CatalogBrand> brands, IReadRepository<CatalogType> types, IUriComposer uriComposer)
    {
        _client = client;
        _items = items;
        _brands = brands;
        _types = types;
        _uriComposer = uriComposer;
    }

    public async Task<CatalogProduct[]> GetCatalogAsync(CancellationToken cancellationToken)
    {
        var items = await _items.ListAsync(cancellationToken);
        var brands = (await _brands.ListAsync(cancellationToken)).ToDictionary(b => b.Id, b => b.Brand);
        var types = (await _types.ListAsync(cancellationToken)).ToDictionary(t => t.Id, t => t.Type);
        var products = items.OrderBy(p => p.Id).Select(p => new CatalogProduct(
            p.Id, p.Name, p.Description, p.Price, brands[p.CatalogBrandId], types[p.CatalogTypeId],
            p.CatalogBrandId, p.CatalogTypeId, _uriComposer.ComposePicUri(p.PictureUri))).ToArray();
        var error = ChatLimits.ValidateCatalog(products);
        if (error is not null)
        {
            throw new InvalidDataException(error);
        }
        return products;
    }

    public async IAsyncEnumerable<ChatEvent> StreamAsync(
        ShopperChatRequest conversation, CatalogProduct[] products,
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "chat")
        {
            Content = JsonContent.Create(new GroundedChatRequest(conversation.Messages, products))
        };
        using var response = await _client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        response.EnsureSuccessStatusCode();
        if (response.Content.Headers.ContentType?.MediaType != "text/event-stream")
        {
            throw new InvalidDataException("ChatApi did not return an event stream.");
        }
        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        await foreach (var item in ChatStream.ReadAsync(stream, cancellationToken))
        {
            yield return item;
        }
    }
}
