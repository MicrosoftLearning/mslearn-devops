using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Microsoft.JSInterop;

namespace BlazorAdmin.JavaScript;

public class Route
{
    private readonly IJSRuntime _jsRuntime;
    private readonly ILogger _logger;

    public Route(IJSRuntime jsRuntime, ILogger logger)
    {
        _jsRuntime = jsRuntime;
        _logger = logger;
    }

    public async Task RouteOutside(string path)
    {
        try
        {
            await _jsRuntime.InvokeVoidAsync(JSInteropConstants.RouteOutside, path);
        }
        catch (JSException exception)
        {
            _logger.LogError(exception, "Unable to navigate outside the admin application.");
            throw;
        }
    }
}
