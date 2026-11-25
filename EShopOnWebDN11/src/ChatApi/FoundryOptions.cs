namespace Microsoft.eShopWeb.ChatApi;

public sealed class FoundryOptions
{
    public string Endpoint { get; set; } = "";
    public string DeploymentName { get; set; } = "";
    public string Credential { get; set; } = "AzureDeveloperCli";
    public string? TenantId { get; set; }

    public bool HasValidEndpoint()
    {
        return Uri.TryCreate(Endpoint, UriKind.Absolute, out var endpoint) &&
            endpoint.Scheme == Uri.UriSchemeHttps &&
            string.IsNullOrEmpty(endpoint.UserInfo) &&
            string.IsNullOrEmpty(endpoint.Query) &&
            string.IsNullOrEmpty(endpoint.Fragment) &&
            (endpoint.AbsolutePath == "/" ||
             endpoint.AbsolutePath.TrimEnd('/') == "/openai/v1" ||
             endpoint.AbsolutePath.StartsWith("/api/projects/", StringComparison.Ordinal));
    }

    public Uri GetChatEndpoint()
    {
        if (!HasValidEndpoint())
        {
            throw new InvalidOperationException("Configure a valid HTTPS Foundry resource or project endpoint.");
        }
        var endpoint = new Uri(Endpoint);
        return new Uri(endpoint.GetLeftPart(UriPartial.Authority) + "/openai/v1/chat/completions");
    }
}
