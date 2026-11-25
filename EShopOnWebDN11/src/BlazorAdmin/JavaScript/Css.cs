using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Microsoft.JSInterop;

namespace BlazorAdmin.JavaScript;

public class Css
{
    private readonly IJSRuntime _jsRuntime;
    private readonly ILogger _logger;

    public Css(IJSRuntime jsRuntime, ILogger logger)
    {
        _jsRuntime = jsRuntime;
        _logger = logger;
    }

    public async Task ShowBodyOverflow()
    {
        try
        {
            await _jsRuntime.InvokeVoidAsync(JSInteropConstants.ShowBodyOverflow);
        }
        catch (JSException exception)
        {
            _logger.LogError(exception, "Unable to restore body scrolling.");
            throw;
        }
    }

    public async Task HideBodyOverflow()
    {
        try
        {
            await _jsRuntime.InvokeVoidAsync(JSInteropConstants.HideBodyOverflow);
        }
        catch (JSException exception)
        {
            _logger.LogError(exception, "Unable to disable body scrolling.");
            throw;
        }
    }
}
