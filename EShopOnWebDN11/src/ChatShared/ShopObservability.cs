using System.Diagnostics;
using Azure.Identity;
using Azure.Monitor.OpenTelemetry.AspNetCore;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using OpenTelemetry;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

namespace Microsoft.eShopWeb.ChatShared;

public static class ShopObservability
{
    public static readonly ActivitySource Activities = new("Microsoft.eShopWeb.Chat");

    public static void AddShopObservability(this WebApplicationBuilder builder, string serviceName)
    {
        if (!builder.Configuration.GetValue<bool>("Observability:Enabled"))
        {
            return;
        }

        string Required(string key) => builder.Configuration[$"Observability:{key}"] is { Length: > 0 } value
            && !string.IsNullOrWhiteSpace(value) ? value
            : throw new InvalidOperationException($"Configure Observability:{key} when observability is enabled.");

        var connectionString = Required("ConnectionString");
        var environment = Required("EnvironmentName");
        var sourceVersion = Required("SourceVersion");
        var identity = Guid.Parse(Required("ManagedIdentityClientId"));

        builder.Services.AddOpenTelemetry()
            .ConfigureResource(resource => resource.AddService(serviceName, serviceVersion: sourceVersion))
            .UseAzureMonitor(options =>
            {
                options.ConnectionString = connectionString;
                options.Credential = new ManagedIdentityCredential(
                    ManagedIdentityId.FromUserAssignedClientId(identity.ToString()));
                options.EnableLiveMetrics = false;
            })
            .WithTracing(tracing => tracing
                .AddSource(Activities.Name)
                .SetSampler(new AlwaysOnSampler())
                .AddProcessor(new ReleaseMetadataProcessor(environment, sourceVersion)));
    }

    private sealed class ReleaseMetadataProcessor(string environment, string sourceVersion) : BaseProcessor<Activity>
    {
        public override void OnStart(Activity activity)
        {
            activity.SetTag("deployment.environment", environment);
            activity.SetTag("source.commit", sourceVersion);
            activity.SetTag("release.id", sourceVersion);
        }
    }
}

public sealed class ChatOperation : IDisposable
{
    private readonly Activity? _activity = ShopObservability.Activities.StartActivity("eshop.chat");
    private string _outcome = "failed";
    private string _reason = "incomplete";

    public void Complete()
    {
        _outcome = "completed";
        _reason = "none";
    }

    public void Fail(string reason)
    {
        _outcome = "failed";
        _reason = reason;
    }

    public void Cancel()
    {
        _outcome = "cancelled";
        _reason = "client_cancelled";
    }

    public void Dispose()
    {
        _activity?.SetTag("chat.outcome", _outcome);
        _activity?.SetTag("chat.failure_reason", _reason);
        if (_outcome == "failed")
        {
            _activity?.SetStatus(ActivityStatusCode.Error, _reason);
        }
        _activity?.Dispose();
    }
}
