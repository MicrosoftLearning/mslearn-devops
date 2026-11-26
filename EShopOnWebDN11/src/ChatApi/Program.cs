using Azure.Core;
using Azure.Identity;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.eShopWeb.ChatApi;
using Microsoft.eShopWeb.ChatShared;
using Microsoft.Extensions.Options;

var builder = WebApplication.CreateBuilder(args);
builder.AddShopObservability("eshop-chat");

builder.Services.AddOptions<ChatAuthenticationOptions>()
    .BindConfiguration("Authentication")
    .Validate(options => options.Enabled || builder.Environment.IsDevelopment(),
        "Hosted ChatApi requires Authentication:Enabled=true.")
    .Validate(options => !options.Enabled || options.IsValid(),
        "Configure Authentication:TenantId, ClientId and AllowedClientId as GUIDs.")
    .ValidateOnStart();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options => options.MapInboundClaims = false);
builder.Services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
    .Configure<IOptions<ChatAuthenticationOptions>>((options, settings) =>
    {
        var authentication = settings.Value;
        if (authentication.Enabled)
        {
            options.Authority = $"https://login.microsoftonline.com/{authentication.TenantId}/v2.0";
            options.Audience = authentication.ClientId;
        }
    });
builder.Services.AddAuthorization();
builder.Services.AddOptions<AuthorizationOptions>()
    .Configure<IOptions<ChatAuthenticationOptions>>((options, settings) =>
        options.AddPolicy("Storefront", policy =>
            policy.RequireAuthenticatedUser().RequireAssertion(context =>
                context.User.FindFirst("azp")?.Value == settings.Value.AllowedClientId &&
                !context.User.HasClaim(claim => claim.Type == "scp"))));
builder.Services.AddOptions<FoundryOptions>()
    .BindConfiguration("Foundry")
    .Validate(options => options.HasValidEndpoint(), "Foundry:Endpoint must be a valid HTTPS resource or project endpoint.")
    .Validate(options => !string.IsNullOrWhiteSpace(options.DeploymentName), "Configure Foundry:DeploymentName.")
    .Validate(options => options.Credential is "AzureDeveloperCli" or "AzureCli" or "ManagedIdentity",
        "Foundry:Credential must be AzureDeveloperCli, AzureCli or ManagedIdentity.")
    .Validate(options => builder.Environment.IsDevelopment() || options.Credential == "ManagedIdentity",
        "Hosted ChatApi requires Foundry:Credential=ManagedIdentity.")
    .Validate(options => options.ManagedIdentityClientId is null || Guid.TryParse(options.ManagedIdentityClientId, out _),
        "Foundry:ManagedIdentityClientId must be a client GUID when configured.")
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
        "ManagedIdentity" => options.ManagedIdentityClientId is null
            ? new ManagedIdentityCredential(ManagedIdentityId.SystemAssigned)
            : new ManagedIdentityCredential(ManagedIdentityId.FromUserAssignedClientId(options.ManagedIdentityClientId)),
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
var authentication = app.Services.GetRequiredService<IOptions<ChatAuthenticationOptions>>().Value;
if (!authentication.Enabled)
{
    app.Urls.Clear();
    app.Urls.Add("http://localhost:5100");
}
app.UseExceptionHandler();
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();
app.MapGet("/health", () => Results.Ok(new { status = "Healthy" })).AllowAnonymous();
var controllers = app.MapControllers();
if (authentication.Enabled)
{
    controllers.RequireAuthorization("Storefront");
}
app.Run();
