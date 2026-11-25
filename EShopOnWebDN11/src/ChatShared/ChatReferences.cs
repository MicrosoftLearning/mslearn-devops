using System.Text.RegularExpressions;

namespace Microsoft.eShopWeb.ChatShared;

public static partial class ChatReferences
{
    [GeneratedRegex(@"\[\[product:([0-9]+)\]\]")]
    private static partial Regex ProductReference();

    public static (string Text, int[] ProductIds) Complete(string answer, CatalogProduct[] products)
    {
        if (string.IsNullOrWhiteSpace(answer) || answer.Length > ChatLimits.MaxAnswerLength)
        {
            throw new InvalidDataException("The assistant returned an empty or oversized answer.");
        }

        var knownIds = products.Select(p => p.Id).ToHashSet();
        var ids = new List<int>();
        foreach (Match match in ProductReference().Matches(answer))
        {
            if (!int.TryParse(match.Groups[1].Value, out var id) || !knownIds.Contains(id))
            {
                throw new InvalidDataException("The assistant referenced a product outside the catalog.");
            }
            if (!ids.Contains(id))
            {
                ids.Add(id);
            }
        }

        var text = ProductReference().Replace(answer, "").Trim();
        if (text.Contains("[[product:", StringComparison.Ordinal) || string.IsNullOrWhiteSpace(text))
        {
            throw new InvalidDataException("The assistant returned an invalid product reference.");
        }
        return (text, ids.ToArray());
    }
}
