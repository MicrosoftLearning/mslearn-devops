namespace Microsoft.eShopWeb.ChatApi;

public sealed class ChatAuthenticationOptions
{
    public bool Enabled { get; set; }
    public string TenantId { get; set; } = "";
    public string ClientId { get; set; } = "";
    public string AllowedClientId { get; set; } = "";

    public bool IsValid() =>
        Guid.TryParse(TenantId, out _) && Guid.TryParse(ClientId, out _) &&
        Guid.TryParse(AllowedClientId, out _);
}
