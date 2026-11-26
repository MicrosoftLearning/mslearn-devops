using BlazorAdmin.JavaScript;
using Microsoft.Extensions.Logging;
using Microsoft.JSInterop;
using NSubstitute;
using Xunit;

namespace Microsoft.eShopWeb.UnitTests.Web.JavaScript;

public class InteropFailureTests
{
    [Theory]
    [InlineData(nameof(Route.RouteOutside))]
    [InlineData(nameof(Css.ShowBodyOverflow))]
    [InlineData(nameof(Css.HideBodyOverflow))]
    [InlineData(nameof(Cookies.DeleteCookie))]
    [InlineData(nameof(Cookies.GetCookie))]
    public async Task LogsAndPropagatesJavaScriptFailures(string operation)
    {
        var exception = new JSException("JavaScript operation failed.");
        var runtime = new ThrowingJsRuntime(exception);
        var logger = Substitute.For<ILogger>();
        Func<Task> invoke = operation switch
        {
            nameof(Route.RouteOutside) => () => new Route(runtime, logger).RouteOutside("/"),
            nameof(Css.ShowBodyOverflow) => () => new Css(runtime, logger).ShowBodyOverflow(),
            nameof(Css.HideBodyOverflow) => () => new Css(runtime, logger).HideBodyOverflow(),
            nameof(Cookies.DeleteCookie) => () => new Cookies(runtime, logger).DeleteCookie("sample"),
            nameof(Cookies.GetCookie) => () => new Cookies(runtime, logger).GetCookie("sample"),
            _ => throw new ArgumentOutOfRangeException(nameof(operation))
        };

        var actual = await Assert.ThrowsAsync<JSException>(invoke);

        Assert.Same(exception, actual);
        var log = Assert.Single(logger.ReceivedCalls(), call => call.GetMethodInfo().Name == nameof(ILogger.Log));
        Assert.Equal(LogLevel.Error, log.GetArguments()[0]);
        Assert.Same(exception, log.GetArguments()[3]);
    }

    private sealed class ThrowingJsRuntime : IJSRuntime
    {
        private readonly JSException _exception;

        public ThrowingJsRuntime(JSException exception)
        {
            _exception = exception;
        }

        public ValueTask<TValue> InvokeAsync<TValue>(string identifier, object?[]? args)
        {
            return ValueTask.FromException<TValue>(_exception);
        }

        public ValueTask<TValue> InvokeAsync<TValue>(string identifier, CancellationToken cancellationToken, object?[]? args)
        {
            return ValueTask.FromException<TValue>(_exception);
        }
    }
}
