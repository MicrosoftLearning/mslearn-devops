using System.Text.Json;

namespace Microsoft.eShopWeb.ChatShared;

public static class ChatLimits
{
    public const int MaxMessages = 11;
    public const int MaxQuestionLength = 1000;
    public const int MaxAnswerLength = 8000;
    public const int MaxHistoryLength = 24000;
    public const int MaxProducts = 50;
    public const int MaxCatalogLength = 32000;
    public const int MaxRequestBytes = 131072;
    public const int TimeoutSeconds = 90;

    public static string? ValidateMessages(ChatMessage[]? messages)
    {
        if (messages is null || messages.Length == 0 || messages.Length > MaxMessages)
        {
            return $"Send between 1 and {MaxMessages} messages.";
        }

        var totalLength = 0;
        for (var i = 0; i < messages.Length; i++)
        {
            var message = messages[i];
            var expectedRole = i % 2 == 0 ? "user" : "assistant";
            if (message is null || message.Role != expectedRole)
            {
                return "Messages must alternate between user and assistant, starting with user.";
            }

            var limit = expectedRole == "user" ? MaxQuestionLength : MaxAnswerLength;
            if (string.IsNullOrWhiteSpace(message.Content) || message.Content.Length > limit)
            {
                return $"A {expectedRole} message must contain between 1 and {limit} characters.";
            }
            totalLength += message.Content.Length;
        }

        if (messages.Length % 2 == 0)
        {
            return "The final message must be a user question.";
        }

        return totalLength > MaxHistoryLength ? "The conversation is too long. Start a new chat." : null;
    }

    public static string? ValidateCatalog(CatalogProduct[]? products)
    {
        if (products is null || products.Length == 0 || products.Length > MaxProducts)
        {
            return $"The catalog must contain between 1 and {MaxProducts} products.";
        }

        if (products.Any(p => p is null || p.Id <= 0 || p.Price < 0 ||
            string.IsNullOrWhiteSpace(p.Name) || string.IsNullOrWhiteSpace(p.Description) ||
            string.IsNullOrWhiteSpace(p.Brand) || string.IsNullOrWhiteSpace(p.Type)) ||
            products.Select(p => p.Id).Distinct().Count() != products.Length)
        {
            return "The catalog contains invalid or duplicate products.";
        }

        return JsonSerializer.Serialize(products).Length > MaxCatalogLength
            ? "The catalog context is too large." : null;
    }
}
