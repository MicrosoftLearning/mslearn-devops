using Azure.Core;
using Azure.Identity;
using MediatR;
using Microsoft.eShopWeb.Web.Interfaces;
using Microsoft.eShopWeb.Web.Services;
using Microsoft.Extensions.Options;

namespace Microsoft.eShopWeb.Web.Configuration;

public static class ConfigureWebServices
{
    public static IServiceCollection AddWebServices(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddMediatR(cfg => 
            cfg.RegisterServicesFromAssembly(typeof(BasketViewModelService).Assembly));
        services.AddScoped<IBasketViewModelService, BasketViewModelService>();
        services.AddScoped<CatalogViewModelService>();
        services.AddScoped<ICatalogItemViewModelService, CatalogItemViewModelService>();
        services.Configure<CatalogSettings>(configuration);
        services.AddScoped<ICatalogViewModelService, CachedCatalogViewModelService>();
        services.AddOptions<ShopChatOptions>()
            .BindConfiguration("ShopChat")
            .Validate(options => !options.Enabled || options.HasValidBaseUrl(),
                "ShopChat requires a loopback root URL, or an HTTPS root URL with an api://<client-guid>/.default AuthenticationScope; ManagedIdentityClientId must be a GUID when configured.")
            .ValidateOnStart();
        services.AddKeyedSingleton<TokenCredential>("catalog-chat", (provider, _) =>
        {
            var options = provider.GetRequiredService<IOptions<ShopChatOptions>>().Value;
            return options.ManagedIdentityClientId is null
                ? new ManagedIdentityCredential(ManagedIdentityId.SystemAssigned)
                : new ManagedIdentityCredential(ManagedIdentityId.FromUserAssignedClientId(options.ManagedIdentityClientId));
        });
        services.AddTransient<ShopChatAuthenticationHandler>();
        services.AddHttpClient<ShopChatService>((provider, client) =>
        {
            var options = provider.GetRequiredService<IOptions<ShopChatOptions>>().Value;
            client.BaseAddress = new Uri(options.BaseUrl);
            client.Timeout = Timeout.InfiniteTimeSpan;
        }).AddHttpMessageHandler<ShopChatAuthenticationHandler>();

        return services;
    }
}
