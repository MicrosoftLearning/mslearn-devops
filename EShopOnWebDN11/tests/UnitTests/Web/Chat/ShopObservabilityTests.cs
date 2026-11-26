using System.Diagnostics;
using Microsoft.AspNetCore.Builder;
using Microsoft.eShopWeb.ChatShared;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Microsoft.eShopWeb.UnitTests.Web.Chat;

public class ShopObservabilityTests
{
    [Theory]
    [InlineData("completed", ActivityStatusCode.Unset)]
    [InlineData("failed", ActivityStatusCode.Error)]
    [InlineData("cancelled", ActivityStatusCode.Unset)]
    [InlineData("incomplete", ActivityStatusCode.Error)]
    public void RecordsTheChatOutcomeIndependentlyOfHttpStatus(string outcome, ActivityStatusCode status)
    {
        var sourceName = ShopObservability.Activities.Name;
        using var listener = new ActivityListener
        {
            ShouldListenTo = source => source.Name == sourceName,
            Sample = (ref ActivityCreationOptions<ActivityContext> options) => ActivitySamplingResult.AllData
        };
        ActivitySource.AddActivityListener(listener);
        Activity? activity;
        using (var operation = new ChatOperation())
        {
            activity = Activity.Current;
            switch (outcome)
            {
                case "completed": operation.Complete(); break;
                case "failed": operation.Fail("upstream_error"); break;
                case "cancelled": operation.Cancel(); break;
            }
        }

        Assert.NotNull(activity);
        Assert.Equal(outcome == "incomplete" ? "failed" : outcome, activity.GetTagItem("chat.outcome"));
        Assert.Equal(status, activity.Status);
        Assert.Null(activity.GetTagItem("prompt"));
    }

    [Fact]
    public void DisabledObservabilityRequiresNoAzureConfiguration()
    {
        var builder = WebApplication.CreateBuilder();
        builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Observability:Enabled"] = "false"
        });
        builder.AddShopObservability("eshop-web");
    }

    [Fact]
    public void EnabledObservabilityRejectsMissingConfiguration()
    {
        var builder = WebApplication.CreateBuilder();
        builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Observability:Enabled"] = "true",
            ["Observability:ConnectionString"] = ""
        });
        var error = Assert.Throws<InvalidOperationException>(() => builder.AddShopObservability("eshop-web"));
        Assert.Contains("Observability:ConnectionString", error.Message);
    }
}
