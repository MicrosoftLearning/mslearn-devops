using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.eShopWeb.ChatShared;
using Microsoft.eShopWeb.Web.Services;
using Microsoft.Extensions.Options;

namespace Microsoft.eShopWeb.Web.Pages;

public sealed class ChatModel : PageModel
{
    private readonly ShopChatOptions _options;

    public ChatModel(IOptions<ShopChatOptions> options)
    {
        _options = options.Value;
    }

    public int MaxQuestionLength => ChatLimits.MaxQuestionLength;
    public int MaxMessages => ChatLimits.MaxMessages;
    public int MaxHistoryLength => ChatLimits.MaxHistoryLength;

    public IActionResult OnGet()
    {
        return _options.Enabled ? Page() : NotFound();
    }
}
