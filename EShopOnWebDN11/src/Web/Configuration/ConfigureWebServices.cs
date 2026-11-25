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
                "ShopChat:BaseUrl must be a loopback HTTP(S) root URL for this local prototype.")
            .ValidateOnStart();
        services.AddHttpClient<ShopChatService>((provider, client) =>
        {
            var options = provider.GetRequiredService<IOptions<ShopChatOptions>>().Value;
            client.BaseAddress = new Uri(options.BaseUrl);
            client.Timeout = Timeout.InfiniteTimeSpan;
        });

        return services;
    }
}
