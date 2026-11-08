using System.Net;
using Microsoft.Azure.Cosmos;
using CatalogApi.Models;

namespace CatalogApi.Services;

public class CosmosDbService
{
    private readonly CosmosClient _client;
    private readonly string _databaseName;
    private readonly string _productsContainerName;
    private readonly string _ordersContainerName;
    private readonly Container _productsContainer;
    private readonly Container _ordersContainer;
    private readonly SemaphoreSlim _initializationLock = new(1, 1);
    private bool _initialized;
    private readonly ILogger<CosmosDbService> _logger;

    public CosmosDbService(IConfiguration configuration, CosmosClient client, ILogger<CosmosDbService> logger)
    {
        _logger = logger;

        _databaseName = configuration["COSMOS_DATABASE_NAME"] ?? "catalogdb";
        _productsContainerName = configuration["COSMOS_PRODUCTS_CONTAINER_NAME"]
            ?? configuration["COSMOS_CONTAINER_NAME"]
            ?? "products";
        _ordersContainerName = configuration["COSMOS_ORDERS_CONTAINER_NAME"] ?? "orders";

        _client = client;
        _productsContainer = _client.GetContainer(_databaseName, _productsContainerName);
        _ordersContainer = _client.GetContainer(_databaseName, _ordersContainerName);
    }

    /// <summary>
    /// Validates infrastructure-provisioned containers and seeds empty containers.
    /// Failed startup initialization is retried by subsequent database requests.
    /// </summary>
    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        await _initializationLock.WaitAsync(cancellationToken);
        try
        {
            if (_initialized)
                return;

            await _productsContainer.ReadContainerAsync(cancellationToken: cancellationToken);
            await _ordersContainer.ReadContainerAsync(cancellationToken: cancellationToken);

            using var productsCountQuery = _productsContainer.GetItemQueryIterator<int>("SELECT VALUE COUNT(1) FROM c");
            var productsCountResponse = await productsCountQuery.ReadNextAsync(cancellationToken);
            if (productsCountResponse.Resource.First() == 0 ||
                await HasIncompleteSeedAsync(_productsContainer, "sample-product-", 8, cancellationToken))
            {
                _logger.LogInformation("Seeding sample product data...");
                await SeedProductsAsync(cancellationToken);
            }

            using var ordersCountQuery = _ordersContainer.GetItemQueryIterator<int>("SELECT VALUE COUNT(1) FROM c");
            var ordersCountResponse = await ordersCountQuery.ReadNextAsync(cancellationToken);
            if (ordersCountResponse.Resource.First() == 0 ||
                await HasIncompleteSeedAsync(_ordersContainer, "sample-order-", 4, cancellationToken))
            {
                _logger.LogInformation("Seeding sample order data...");
                await SeedOrdersAsync(cancellationToken);
            }

            _initialized = true;
            _logger.LogInformation(
                "Cosmos DB initialized: database={Database}, productsContainer={ProductsContainer}, ordersContainer={OrdersContainer}",
                _databaseName, _productsContainerName, _ordersContainerName);
        }
        finally
        {
            _initializationLock.Release();
        }
    }

    private async Task SeedProductsAsync(CancellationToken cancellationToken)
    {
        var products = new List<Product>
        {
            new() { Name = "Wireless Keyboard",  Category = "Electronics", Description = "Ergonomic wireless keyboard with backlight",          Price = 79.99m,  Stock = 150 },
            new() { Name = "USB-C Monitor",       Category = "Electronics", Description = "27-inch 4K USB-C monitor",                          Price = 449.99m, Stock = 45 },
            new() { Name = "Standing Desk",        Category = "Furniture",   Description = "Electric height-adjustable standing desk",           Price = 599.99m, Stock = 30 },
            new() { Name = "Desk Lamp",            Category = "Furniture",   Description = "LED desk lamp with adjustable brightness",           Price = 34.99m,  Stock = 200 },
            new() { Name = "Webcam HD",            Category = "Electronics", Description = "1080p HD webcam with noise-canceling microphone",    Price = 89.99m,  Stock = 120 },
            new() { Name = "Office Chair",         Category = "Furniture",   Description = "Mesh office chair with lumbar support",              Price = 349.99m, Stock = 25 },
            new() { Name = "Laptop Stand",         Category = "Accessories", Description = "Aluminum laptop stand with ventilation",             Price = 49.99m,  Stock = 300 },
            new() { Name = "Mouse Pad XL",         Category = "Accessories", Description = "Extended mouse pad with stitched edges",             Price = 19.99m,  Stock = 500 },
        };

        for (var index = 0; index < products.Count; index++)
        {
            var product = products[index];
            product.Id = $"sample-product-{index + 1:000}";
            await CreateSeedItemAsync(_productsContainer, product, new PartitionKey(product.Category), cancellationToken);
        }

        _logger.LogInformation("Seeded {Count} products.", products.Count);
    }

    private async Task SeedOrdersAsync(CancellationToken cancellationToken)
    {
        var orders = new List<Order>
        {
            new() { CustomerId = "cust-001", Description = "Bulk keyboard order",            ProductName = "Wireless Keyboard", Quantity = 50, Total = 3999.50m, Status = "completed" },
            new() { CustomerId = "cust-002", Description = "Monitor refresh for office",      ProductName = "USB-C Monitor",     Quantity = 10, Total = 4499.90m, Status = "completed" },
            new() { CustomerId = "cust-003", Description = "Standing desks for new floor",    ProductName = "Standing Desk",     Quantity = 20, Total = 11999.80m, Status = "shipped" },
            new() { CustomerId = "cust-004", Description = "Webcams for remote team",         ProductName = "Webcam HD",         Quantity = 30, Total = 2699.70m, Status = "pending" }
        };

        for (var index = 0; index < orders.Count; index++)
        {
            var order = orders[index];
            order.Id = $"sample-order-{index + 1:000}";
            await CreateSeedItemAsync(_ordersContainer, order, new PartitionKey(order.CustomerId), cancellationToken);
        }

        _logger.LogInformation("Seeded {Count} orders.", orders.Count);
    }

    private static async Task<bool> HasIncompleteSeedAsync(
        Container container, string idPrefix, int expectedCount, CancellationToken cancellationToken)
    {
        var queryDefinition = new QueryDefinition(
            "SELECT VALUE COUNT(1) FROM c WHERE STARTSWITH(c.id, @prefix)")
            .WithParameter("@prefix", idPrefix);
        using var query = container.GetItemQueryIterator<int>(queryDefinition);
        var response = await query.ReadNextAsync(cancellationToken);
        var count = response.Resource.First();
        return count > 0 && count < expectedCount;
    }

    private async Task CreateSeedItemAsync<T>(
        Container container, T item, PartitionKey partitionKey, CancellationToken cancellationToken)
    {
        try
        {
            await container.CreateItemAsync(item, partitionKey, cancellationToken: cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            // A retry or another app instance may already have created this sample.
            _logger.LogInformation("Sample document already exists; preserving it in container {Container}.", container.Id);
        }
    }

    /// <summary>Returns all products in the container.</summary>
    public async Task<IEnumerable<Product>> GetProductsAsync(CancellationToken cancellationToken = default)
    {
        await InitializeAsync(cancellationToken);
        using var query = _productsContainer.GetItemQueryIterator<Product>("SELECT * FROM c");
        var results = new List<Product>();
        while (query.HasMoreResults)
        {
            var response = await query.ReadNextAsync(cancellationToken);
            results.AddRange(response);
        }
        return results;
    }

    /// <summary>Returns a single product by id (cross-partition query).</summary>
    public async Task<Product?> GetProductByIdAsync(string id, CancellationToken cancellationToken = default)
    {
        await InitializeAsync(cancellationToken);
        var queryDef = new QueryDefinition("SELECT * FROM c WHERE c.id = @id")
            .WithParameter("@id", id);
        using var iterator = _productsContainer.GetItemQueryIterator<Product>(queryDef);
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync(cancellationToken);
            var match = response.FirstOrDefault();
            if (match is not null) return match;
        }
        return null;
    }

    /// <summary>Creates a new product.</summary>
    public async Task<Product> CreateProductAsync(Product product, CancellationToken cancellationToken = default)
    {
        await InitializeAsync(cancellationToken);
        product.Id = Guid.NewGuid().ToString();
        var response = await _productsContainer.CreateItemAsync(product, new PartitionKey(product.Category), cancellationToken: cancellationToken);
        return response.Resource;
    }

    public async Task<IEnumerable<Order>> GetOrdersAsync(CancellationToken cancellationToken = default)
    {
        await InitializeAsync(cancellationToken);
        using var query = _ordersContainer.GetItemQueryIterator<Order>("SELECT * FROM c");
        var results = new List<Order>();
        while (query.HasMoreResults)
        {
            var response = await query.ReadNextAsync(cancellationToken);
            results.AddRange(response);
        }
        return results;
    }

    public async Task<Order?> GetOrderByIdAsync(string id, CancellationToken cancellationToken = default)
    {
        await InitializeAsync(cancellationToken);
        var queryDef = new QueryDefinition("SELECT * FROM c WHERE c.id = @id")
            .WithParameter("@id", id);
        using var iterator = _ordersContainer.GetItemQueryIterator<Order>(queryDef);
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync(cancellationToken);
            var match = response.FirstOrDefault();
            if (match is not null) return match;
        }
        return null;
    }

    public async Task<Order> CreateOrderAsync(Order order, CancellationToken cancellationToken = default)
    {
        await InitializeAsync(cancellationToken);
        order.Id = Guid.NewGuid().ToString();
        order.CreatedAt = DateTime.UtcNow;
        order.Status = "pending";
        var response = await _ordersContainer.CreateItemAsync(order, new PartitionKey(order.CustomerId), cancellationToken: cancellationToken);
        return response.Resource;
    }

    /// <summary>Validates initialization and availability of both required containers.</summary>
    public async Task<bool> CheckHealthAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            await InitializeAsync(cancellationToken);
            await _productsContainer.ReadContainerAsync(cancellationToken: cancellationToken);
            await _ordersContainer.ReadContainerAsync(cancellationToken: cancellationToken);
            return true;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Cosmos DB health check failed.");
            return false;
        }
    }
}
