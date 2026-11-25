namespace Microsoft.eShopWeb.Web.Services;

public sealed class ShopChatOptions
{
    public bool Enabled { get; set; }
    public string BaseUrl { get; set; } = "http://localhost:5100/";

    public bool HasValidBaseUrl()
    {
        return Uri.TryCreate(BaseUrl, UriKind.Absolute, out var uri) && uri.IsLoopback &&
            uri.Scheme is "http" or "https" && string.IsNullOrEmpty(uri.UserInfo) &&
            string.IsNullOrEmpty(uri.Query) && string.IsNullOrEmpty(uri.Fragment) &&
            uri.AbsolutePath == "/";
    }
}
