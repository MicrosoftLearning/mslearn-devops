using Azure.Core;
using Azure.Identity;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.eShopWeb.ChatApi;
using Microsoft.Extensions.Options;

var builder = WebApplication.CreateBuilder(args);

if (!builder.Environment.IsDevelopment())
{
    throw new InvalidOperationException(
        "This ChatApi prototype is local Development only. Authenticated Azure hosting will be configured in the infrastructure phase.");
}

builder.WebHost.UseUrls("http://localhost:5100");
builder.Services.AddOptions<FoundryOptions>()
    .BindConfiguration("Foundry")
    .Validate(options => options.HasValidEndpoint(), "Foundry:Endpoint must be a valid HTTPS resource or project endpoint.")
    .Validate(options => !string.IsNullOrWhiteSpace(options.DeploymentName), "Configure Foundry:DeploymentName.")
    .Validate(options => options.Credential is "AzureDeveloperCli" or "AzureCli",
        "Foundry:Credential must be AzureDeveloperCli or AzureCli.")
    .Validate(options => options.TenantId is null || Guid.TryParse(options.TenantId, out _),
        "Foundry:TenantId must be a valid tenant GUID when configured.")
    .ValidateOnStart();
builder.Services.AddSingleton<TokenCredential>(services =>
{
    var options = services.GetRequiredService<IOptions<FoundryOptions>>().Value;
    return options.Credential switch
    {
        "AzureDeveloperCli" => new AzureDeveloperCliCredential(
            new AzureDeveloperCliCredentialOptions { TenantId = options.TenantId }),
        "AzureCli" => new AzureCliCredential(new AzureCliCredentialOptions { TenantId = options.TenantId }),
        _ => throw new InvalidOperationException("Unsupported Foundry credential.")
    };
});
builder.Services.AddHttpClient<FoundryChatClient>(client => client.Timeout = Timeout.InfiniteTimeSpan);
builder.Services.AddControllers();
builder.Services.AddProblemDetails();
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddFixedWindowLimiter("chat", limiter =>
    {
        limiter.PermitLimit = 12;
        limiter.Window = TimeSpan.FromMinutes(1);
        limiter.QueueLimit = 0;
    });
});

var app = builder.Build();
app.UseExceptionHandler();
app.UseRateLimiter();
app.MapGet("/health", () => Results.Ok(new { status = "Healthy" }));
app.MapControllers();
app.Run();
