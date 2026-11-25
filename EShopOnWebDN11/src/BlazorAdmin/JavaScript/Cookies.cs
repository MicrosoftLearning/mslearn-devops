using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Microsoft.JSInterop;

namespace BlazorAdmin.JavaScript;

public class Cookies
{
    private readonly IJSRuntime _jsRuntime;
    private readonly ILogger _logger;

    public Cookies(IJSRuntime jsRuntime, ILogger logger)
    {
        _jsRuntime = jsRuntime;
        _logger = logger;
    }

    public async Task DeleteCookie(string name)
    {
        try
        {
            await _jsRuntime.InvokeVoidAsync(JSInteropConstants.DeleteCookie, name);
        }
        catch (JSException exception)
        {
            _logger.LogError(exception, "Unable to delete a cookie.");
            throw;
        }
    }

    public async Task<string> GetCookie(string name)
    {
        try
        {
            return await _jsRuntime.InvokeAsync<string>(JSInteropConstants.GetCookie, name);
        }
        catch (JSException exception)
        {
            _logger.LogError(exception, "Unable to read a cookie.");
            throw;
        }
    }
}
