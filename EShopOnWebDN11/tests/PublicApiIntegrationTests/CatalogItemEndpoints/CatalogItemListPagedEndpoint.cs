using Microsoft.eShopWeb;
using Microsoft.eShopWeb.PublicApi.CatalogItemEndpoints;
using Microsoft.eShopWeb.Web.ViewModels;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Net;
using System.Threading.Tasks;
using System.Text.Json;

namespace PublicApiIntegrationTests.CatalogItemEndpoints;

[TestClass]
public class CatalogItemListPagedEndpoint
{
    [TestMethod]
    public async Task ReturnsFirst10CatalogItems()
    {
        var client = ProgramTest.NewClient;
        var response = await client.GetAsync("/api/catalog-items?pageSize=10");
        response.EnsureSuccessStatusCode();
        var stringResponse = await response.Content.ReadAsStringAsync();
        var model = stringResponse.FromJson<CatalogIndexViewModel>();

        Assert.AreEqual(10, model!.CatalogItems.Count());
    }

    [TestMethod]
    public async Task ReturnsSameItemDetailsAsGetById()
    {
        var client = ProgramTest.NewClient;
        var listResponse = await client.GetAsync("/api/catalog-items?pageSize=20");
        listResponse.EnsureSuccessStatusCode();
        var list = (await listResponse.Content.ReadAsStringAsync()).FromJson<ListPagedCatalogItemResponse>();
        var actual = list!.CatalogItems.Single(item => item.Id == 1);

        var itemResponse = await client.GetAsync("/api/catalog-items/1");
        itemResponse.EnsureSuccessStatusCode();
        var expected = (await itemResponse.Content.ReadAsStringAsync()).FromJson<GetByIdCatalogItemResponse>()!.CatalogItem;

        Assert.AreEqual(expected.Id, actual.Id);
        Assert.AreEqual(expected.Name, actual.Name);
        Assert.AreEqual(expected.Description, actual.Description);
        Assert.AreEqual(expected.Price, actual.Price);
        Assert.AreEqual(expected.PictureUri, actual.PictureUri);
        Assert.AreEqual(expected.CatalogBrandId, actual.CatalogBrandId);
        Assert.AreEqual(expected.CatalogTypeId, actual.CatalogTypeId);
    }

    [DataTestMethod]
    [DataRow("catalog-brands", "catalogBrands", ".NET")]
    [DataRow("catalog-types", "catalogTypes", "Mug")]
    public async Task ReturnsLookupNames(string endpoint, string collectionName, string expectedName)
    {
        var response = await ProgramTest.NewClient.GetAsync($"/api/{endpoint}");
        response.EnsureSuccessStatusCode();
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var items = document.RootElement.GetProperty(collectionName).EnumerateArray().ToList();

        Assert.IsTrue(items.Any(item => item.GetProperty("name").GetString() == expectedName));
        Assert.IsTrue(items.All(item => item.GetProperty("id").GetInt32() > 0 &&
            !string.IsNullOrWhiteSpace(item.GetProperty("name").GetString())));
    }

    [TestMethod]
    public async Task ReturnsCorrectCatalogItemsGivenPageIndex1()
    {

        var pageSize = 10;
        var pageIndex = 1;

        var client = ProgramTest.NewClient;
        var response = await client.GetAsync($"/api/catalog-items");
        response.EnsureSuccessStatusCode();
        var stringResponse = await response.Content.ReadAsStringAsync();
        var model = stringResponse.FromJson<ListPagedCatalogItemResponse>();
        var totalItem = model!.CatalogItems.Count();

        var response2 = await client.GetAsync($"/api/catalog-items?pageSize={pageSize}&pageIndex={pageIndex}");
        response.EnsureSuccessStatusCode();
        var stringResponse2 = await response2.Content.ReadAsStringAsync();
        var model2 = stringResponse2.FromJson<ListPagedCatalogItemResponse>();

        var totalExpected = totalItem - (pageSize * pageIndex);

        Assert.AreEqual(totalExpected, model2!.CatalogItems.Count());
    }

    [DataTestMethod]
    [DataRow("catalog-items")]
    [DataRow("catalog-brands")]
    [DataRow("catalog-types")]
    [DataRow("catalog-items/1")]
    public async Task SuccessFullMutipleParallelCall(string endpointName)
    {
        var client = ProgramTest.NewClient;
        var tasks = new List<Task<HttpResponseMessage>>();

        for (int i = 0; i < 100; i++)
        {
            var task = client.GetAsync($"/api/{endpointName}");
            tasks.Add(task);
        }
        await Task.WhenAll(tasks.ToList());
        var totalKO = tasks.Count(t => t.Result.StatusCode != HttpStatusCode.OK);

        Assert.AreEqual(0, totalKO);
    }
}
