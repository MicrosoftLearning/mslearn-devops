using System.Net.Http.Headers;
using Azure.Core;
using Microsoft.Extensions.Options;

namespace Microsoft.eShopWeb.Web.Services;

public sealed class ShopChatAuthenticationHandler(
    IOptions<ShopChatOptions> options,
    [FromKeyedServices("catalog-chat")] TokenCredential credential) : DelegatingHandler
{
    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        if (options.Value.AuthenticationScope.Length > 0)
        {
            var token = await credential.GetTokenAsync(
                new TokenRequestContext([options.Value.AuthenticationScope]), cancellationToken);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
        }
        return await base.SendAsync(request, cancellationToken);
    }
}
