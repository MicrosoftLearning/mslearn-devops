using Microsoft.eShopWeb.ChatShared;
using Xunit;

namespace Microsoft.eShopWeb.UnitTests.Web.Chat;

public class ChatReferencesTests
{
    private static readonly CatalogProduct[] Products =
    [
        new(2, "Mug", "A mug", 8.5m, ".NET", "Mug", 2, 1, "/images/products/2.png"),
        new(9, "Cup<T>", "Another mug", 12m, "Other", "Mug", 5, 1, "/images/products/9.png")
    ];

    [Fact]
    public void RemovesCitationsAndKeepsDistinctReferencesInMentionOrder()
    {
        var result = ChatReferences.Complete(
            "Compare Cup<T> [[product:9]] and Mug [[product:2]]. Mug [[product:2]] is cheaper.", Products);

        Assert.Equal([9, 2], result.ProductIds);
        Assert.Equal("Compare Cup<T>  and Mug . Mug  is cheaper.", result.Text);
    }

    [Theory]
    [InlineData("Unknown mug [[product:999]].")]
    [InlineData("Overflow [[product:999999999999999999999]].")]
    [InlineData("Broken [[product:2].")]
    [InlineData("[[product:2]]")]
    public void RejectsUnusableOrUnverifiableProductAnswers(string answer)
    {
        Assert.Throws<InvalidDataException>(() => ChatReferences.Complete(answer, Products));
    }
}
