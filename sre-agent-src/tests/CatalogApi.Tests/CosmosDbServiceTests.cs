using System.Net;
using CatalogApi.Models;
using CatalogApi.Services;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace CatalogApi.Tests;

public class CosmosDbServiceTests
{
    private readonly Mock<CosmosClient> _client = new(MockBehavior.Strict);
    private readonly Mock<Container> _products = new(MockBehavior.Strict);
    private readonly Mock<Container> _orders = new(MockBehavior.Strict);

    public CosmosDbServiceTests()
    {
        _client.Setup(c => c.GetContainer("catalogdb", "products")).Returns(_products.Object);
        _client.Setup(c => c.GetContainer("catalogdb", "orders")).Returns(_orders.Object);
        SetupContainer(_products, 0);
        SetupContainer(_orders, 0);
        _products.SetupGet(c => c.Id).Returns("products");
        _orders.SetupGet(c => c.Id).Returns("orders");
        _products.Setup(c => c.CreateItemAsync(
                It.IsAny<Product>(), It.IsAny<PartitionKey?>(), It.IsAny<ItemRequestOptions>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(Mock.Of<ItemResponse<Product>>());
        _orders.Setup(c => c.CreateItemAsync(
                It.IsAny<Order>(), It.IsAny<PartitionKey?>(), It.IsAny<ItemRequestOptions>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(Mock.Of<ItemResponse<Order>>());
    }

    [Fact]
    public async Task InitializationSeedsBothProvisionedContainers()
    {
        var products = new List<Product>();
        var orders = new List<Order>();
        _products.Setup(c => c.CreateItemAsync(
                It.IsAny<Product>(), It.IsAny<PartitionKey?>(), It.IsAny<ItemRequestOptions>(), It.IsAny<CancellationToken>()))
            .Callback((Product product, PartitionKey? key, ItemRequestOptions options, CancellationToken token) =>
            {
                Assert.Equal(new PartitionKey(product.Category), key);
                products.Add(product);
            })
            .ReturnsAsync(Mock.Of<ItemResponse<Product>>());
        _orders.Setup(c => c.CreateItemAsync(
                It.IsAny<Order>(), It.IsAny<PartitionKey?>(), It.IsAny<ItemRequestOptions>(), It.IsAny<CancellationToken>()))
            .Callback((Order order, PartitionKey? key, ItemRequestOptions options, CancellationToken token) =>
            {
                Assert.Equal(new PartitionKey(order.CustomerId), key);
                orders.Add(order);
            })
            .ReturnsAsync(Mock.Of<ItemResponse<Order>>());
        SetupQuery(_products, products);
        SetupQuery(_orders, orders);
        var service = CreateService();
        await service.InitializeAsync();

        Assert.Equal(8, (await service.GetProductsAsync()).Count());
        Assert.Equal(4, (await service.GetOrdersAsync()).Count());
        Assert.Equal(8, products.Select(p => p.Id).Distinct().Count());
        Assert.Equal(4, orders.Select(o => o.Id).Distinct().Count());

        VerifySeedCounts(8, 4);
        _products.Verify(c => c.ReadContainerAsync(null, It.IsAny<CancellationToken>()), Times.Once);
        _orders.Verify(c => c.ReadContainerAsync(null, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Theory]
    [InlineData("products")]
    [InlineData("orders")]
    public async Task RestartCompletesPartialSeedsWithoutOverwritingExistingDocuments(string containerName)
    {
        var container = containerName == "products" ? _products : _orders;
        SetupContainer(container, 1);
        SetupSeedCount(container, 1);
        if (containerName == "products")
        {
            _products.Setup(c => c.CreateItemAsync(
                    It.Is<Product>(p => p.Id == "sample-product-001"),
                    It.IsAny<PartitionKey?>(), It.IsAny<ItemRequestOptions>(), It.IsAny<CancellationToken>()))
                .ThrowsAsync(CosmosFailure(HttpStatusCode.Conflict));
        }
        else
        {
            _orders.Setup(c => c.CreateItemAsync(
                    It.Is<Order>(o => o.Id == "sample-order-001"),
                    It.IsAny<PartitionKey?>(), It.IsAny<ItemRequestOptions>(), It.IsAny<CancellationToken>()))
                .ThrowsAsync(CosmosFailure(HttpStatusCode.Conflict));
        }

        await CreateService().InitializeAsync();

        VerifySeedCounts(8, 4);
    }

    [Theory]
    [InlineData("products-list")]
    [InlineData("product-by-id")]
    [InlineData("product-create")]
    [InlineData("orders-list")]
    [InlineData("order-by-id")]
    [InlineData("order-create")]
    public async Task AllDatabaseOperationsRequireSuccessfulInitialization(string operation)
    {
        var service = CreateService();
        _orders.Setup(c => c.ReadContainerAsync(null, It.IsAny<CancellationToken>()))
            .ThrowsAsync(CosmosFailure(HttpStatusCode.NotFound));

        await Assert.ThrowsAsync<CosmosException>(async () =>
        {
            switch (operation)
            {
                case "products-list": await service.GetProductsAsync(); break;
                case "product-by-id": await service.GetProductByIdAsync("test"); break;
                case "product-create": await service.CreateProductAsync(new Product()); break;
                case "orders-list": await service.GetOrdersAsync(); break;
                case "order-by-id": await service.GetOrderByIdAsync("test"); break;
                case "order-create": await service.CreateOrderAsync(new Order()); break;
                default: throw new InvalidOperationException($"Unknown operation: {operation}");
            }
        });
        VerifySeedCounts(0, 0);
    }

    [Fact]
    public async Task RepeatedAndConcurrentInitializationDoesNotDuplicateSeeds()
    {
        var service = CreateService();
        var entered = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var release = new TaskCompletionSource<ContainerResponse>(TaskCreationOptions.RunContinuationsAsynchronously);
        _products.Setup(c => c.ReadContainerAsync(null, It.IsAny<CancellationToken>()))
            .Returns(() =>
            {
                entered.TrySetResult();
                return release.Task;
            });

        var first = service.InitializeAsync();
        await entered.Task;
        var second = service.InitializeAsync();
        Assert.False(second.IsCompleted);
        release.SetResult(Mock.Of<ContainerResponse>());
        await Task.WhenAll(first, second);
        await service.InitializeAsync();

        VerifySeedCounts(8, 4);
        _products.Verify(c => c.ReadContainerAsync(null, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ExistingDataIsNotReseeded()
    {
        SetupContainer(_products, 8);
        SetupContainer(_orders, 4);

        await CreateService().InitializeAsync();

        VerifySeedCounts(0, 0);
    }

    [Fact]
    public async Task MissingOrdersPreventsSeedingAndProductRequestRetriesInitialization()
    {
        var service = CreateService();
        _orders.SetupSequence(c => c.ReadContainerAsync(null, It.IsAny<CancellationToken>()))
            .ThrowsAsync(CosmosFailure(HttpStatusCode.NotFound))
            .ReturnsAsync(Mock.Of<ContainerResponse>());
        SetupQuery(_products, Array.Empty<Product>());

        await Assert.ThrowsAsync<CosmosException>(() => service.InitializeAsync());
        VerifySeedCounts(0, 0);
        await service.GetProductsAsync();

        VerifySeedCounts(8, 4);
        _orders.Verify(c => c.ReadContainerAsync(null, It.IsAny<CancellationToken>()), Times.Exactly(2));
    }

    [Fact]
    public async Task HealthRetriesAfterPermissionRecovery()
    {
        var service = CreateService();
        _products.SetupSequence(c => c.ReadContainerAsync(null, It.IsAny<CancellationToken>()))
            .ThrowsAsync(CosmosFailure(HttpStatusCode.Forbidden))
            .ReturnsAsync(Mock.Of<ContainerResponse>())
            .ReturnsAsync(Mock.Of<ContainerResponse>());

        Assert.False(await service.CheckHealthAsync());
        Assert.True(await service.CheckHealthAsync());
        VerifySeedCounts(8, 4);
    }

    [Theory]
    [InlineData("products")]
    [InlineData("orders")]
    public async Task HealthDetectsContainerFailureAfterSuccessfulInitialization(string containerName)
    {
        var service = CreateService();
        await service.InitializeAsync();
        var container = containerName == "products" ? _products : _orders;
        container.Setup(c => c.ReadContainerAsync(null, It.IsAny<CancellationToken>()))
            .ThrowsAsync(CosmosFailure(HttpStatusCode.NotFound));

        Assert.False(await service.CheckHealthAsync());
    }

    [Fact]
    public async Task StartupCancellationReleasesLockAndAllowsRequestRetry()
    {
        var service = CreateService();
        using var cts = new CancellationTokenSource();
        _products.Setup(c => c.ReadContainerAsync(null, It.IsAny<CancellationToken>()))
            .Returns(async (ContainerRequestOptions options, CancellationToken token) =>
            {
                await Task.Delay(Timeout.Infinite, token);
                return Mock.Of<ContainerResponse>();
            });

        var initialization = service.InitializeAsync(cts.Token);
        cts.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => initialization);
        SetupContainer(_products, 0);
        SetupQuery(_orders, Array.Empty<Order>());

        await service.GetOrdersAsync();
        VerifySeedCounts(8, 4);
    }

    [Fact]
    public async Task HealthPropagatesCallerCancellation()
    {
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => CreateService().CheckHealthAsync(cts.Token));
    }

    private CosmosDbService CreateService() =>
        new(new ConfigurationBuilder().Build(), _client.Object, NullLogger<CosmosDbService>.Instance);

    private static void SetupContainer(Mock<Container> container, int count)
    {
        container.Setup(c => c.ReadContainerAsync(null, It.IsAny<CancellationToken>()))
            .ReturnsAsync(Mock.Of<ContainerResponse>());
        SetupQuery(container, new[] { count });
        SetupSeedCount(container, 0);
    }

    private static void SetupSeedCount(Mock<Container> container, int count)
    {
        var response = new Mock<FeedResponse<int>>();
        response.Setup(r => r.Resource).Returns(new[] { count });
        var iterator = new Mock<FeedIterator<int>>();
        iterator.Setup(i => i.ReadNextAsync(It.IsAny<CancellationToken>())).ReturnsAsync(response.Object);
        container.Setup(c => c.GetItemQueryIterator<int>(
                It.IsAny<QueryDefinition>(), It.IsAny<string>(), It.IsAny<QueryRequestOptions>()))
            .Returns(iterator.Object);
    }

    private static void SetupQuery<T>(Mock<Container> container, IReadOnlyList<T> items)
    {
        var response = new Mock<FeedResponse<T>>();
        response.Setup(r => r.Resource).Returns(items);
        response.Setup(r => r.GetEnumerator()).Returns(() => items.GetEnumerator());
        var iterator = new Mock<FeedIterator<T>>();
        iterator.SetupSequence(i => i.HasMoreResults).Returns(true).Returns(false);
        iterator.Setup(i => i.ReadNextAsync(It.IsAny<CancellationToken>())).ReturnsAsync(response.Object);
        container.Setup(c => c.GetItemQueryIterator<T>(
                It.IsAny<string>(), It.IsAny<string>(), It.IsAny<QueryRequestOptions>()))
            .Returns(iterator.Object);
    }

    private void VerifySeedCounts(int products, int orders)
    {
        _products.Verify(c => c.CreateItemAsync(
            It.IsAny<Product>(), It.IsAny<PartitionKey?>(), It.IsAny<ItemRequestOptions>(), It.IsAny<CancellationToken>()),
            Times.Exactly(products));
        _orders.Verify(c => c.CreateItemAsync(
            It.IsAny<Order>(), It.IsAny<PartitionKey?>(), It.IsAny<ItemRequestOptions>(), It.IsAny<CancellationToken>()),
            Times.Exactly(orders));
    }

    private static CosmosException CosmosFailure(HttpStatusCode statusCode) =>
        new("Cosmos DB unavailable for test", statusCode, 0, "test", 0);
}
