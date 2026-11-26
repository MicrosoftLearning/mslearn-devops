using System.Text.Json.Serialization;

namespace Microsoft.eShopWeb.ChatShared;

public sealed record ChatMessage(string Role, string Content);

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record ShopperChatRequest(ChatMessage[] Messages);

public sealed record CatalogProduct(
    int Id, string Name, string Description, decimal Price,
    string Brand, string Type, int BrandId, int TypeId, string PictureUri);

public sealed record GroundedChatRequest(ChatMessage[] Messages, CatalogProduct[] Products);

public sealed record ProductCard(int Id, string Name, decimal Price, string PictureUri, string Url);

public sealed record ChatEvent(
    string Type, string? Text = null, int[]? ProductIds = null,
    ProductCard[]? Products = null, string? Error = null);
