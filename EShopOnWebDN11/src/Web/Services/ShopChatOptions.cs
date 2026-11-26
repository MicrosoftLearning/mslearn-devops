namespace Microsoft.eShopWeb.Web.Services;

public sealed class ShopChatOptions
{
    public bool Enabled { get; set; }
    public string BaseUrl { get; set; } = "http://localhost:5100/";
    public string AuthenticationScope { get; set; } = "";
    public string? ManagedIdentityClientId { get; set; }

    public bool HasValidBaseUrl()
    {
        var validScope = AuthenticationScope.StartsWith("api://", StringComparison.Ordinal) &&
            AuthenticationScope.EndsWith("/.default", StringComparison.Ordinal) &&
            Guid.TryParse(AuthenticationScope["api://".Length..^"/.default".Length], out _);
        return Uri.TryCreate(BaseUrl, UriKind.Absolute, out var uri) &&
            uri.Scheme is "http" or "https" && string.IsNullOrEmpty(uri.UserInfo) &&
            string.IsNullOrEmpty(uri.Query) && string.IsNullOrEmpty(uri.Fragment) &&
            uri.AbsolutePath == "/" &&
            (uri.IsLoopback || (uri.Scheme == "https" && validScope)) &&
            (AuthenticationScope.Length == 0 || validScope) &&
            (ManagedIdentityClientId is null || Guid.TryParse(ManagedIdentityClientId, out _));
    }
}
