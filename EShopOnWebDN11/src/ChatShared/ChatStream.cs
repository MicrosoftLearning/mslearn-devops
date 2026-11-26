using System.Net.ServerSentEvents;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;

namespace Microsoft.eShopWeb.ChatShared;

public static class ChatStream
{
    public static async Task WriteAsync(Stream stream, ChatEvent item, CancellationToken cancellationToken)
    {
        var data = Encoding.UTF8.GetBytes($"data: {JsonSerializer.Serialize(item, JsonSerializerOptions.Web)}\n\n");
        await stream.WriteAsync(data, cancellationToken);
        await stream.FlushAsync(cancellationToken);
    }

    public static async IAsyncEnumerable<ChatEvent> ReadAsync(
        Stream stream, [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        await foreach (var item in SseParser.Create(stream).EnumerateAsync(cancellationToken))
        {
            if (item.Data.Length > ChatLimits.MaxAnswerLength + ChatLimits.MaxCatalogLength)
            {
                throw new InvalidDataException("The chat service returned an oversized event.");
            }
            var message = JsonSerializer.Deserialize<ChatEvent>(item.Data, JsonSerializerOptions.Web);
            if (message is null || string.IsNullOrWhiteSpace(message.Type))
            {
                throw new InvalidDataException("The chat service returned an invalid event.");
            }
            yield return message;
        }
    }
}
