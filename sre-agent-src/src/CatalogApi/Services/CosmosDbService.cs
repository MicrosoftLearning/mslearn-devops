using Azure.Identity;
using Microsoft.Azure.Cosmos;
using CatalogApi.Models;

namespace CatalogApi.Services;

public class CosmosDbService
{
    private readonly CosmosClient _client;
    private readonly string _databaseName;
    private readonly string _productsContainerName;
    private readonly string _ordersContainerName;
    private Container? _productsContainer;
    private Container? _ordersContainer;
    private bool _initialized;
    private readonly ILogger<CosmosDbService> _logger;

    public CosmosDbService(IConfiguration configuration, ILogger<CosmosDbService> logger)
    {
        _logger = logger;

        var endpoint = configuration["COSMOS_ACCOUNT_ENDPOINT"]
            ?? throw new InvalidOperationException(
                "COSMOS_ACCOUNT_ENDPOINT is not configured. Set it as an app setting or environment variable.");

        _databaseName = configuration["COSMOS_DATABASE_NAME"] ?? "catalogdb";
        _productsContainerName = configuration["COSMOS_PRODUCTS_CONTAINER_NAME"]
            ?? configuration["COSMOS_CONTAINER_NAME"]
            ?? "products";
        _ordersContainerName = configuration["COSMOS_ORDERS_CONTAINER_NAME"] ?? "orders";

        // Keyless authentication via managed identity (App Service) or
        // developer credential (local: az login / VS / VSCode).
        _client = new CosmosClient(endpoint, new DefaultAzureCredential(), new CosmosClientOptions
        {
            SerializerOptions = new CosmosSerializationOptions
            {
                PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase
            }
        });
    }

    /// <summary>
    /// Creates the database, product/order containers, and seeds sample data if containers are empty.
    /// Call once at startup. Failures are non-fatal — the app starts but DB requests will fail.
    /// </summary>
    public async Task InitializeAsync()
    {
        var database = await _client.CreateDatabaseIfNotExistsAsync(_databaseName);
        var productsResponse = await database.Database.CreateContainerIfNotExistsAsync(
            _productsContainerName, "/category");
        _productsContainer = productsResponse.Container;

        var ordersResponse = await database.Database.CreateContainerIfNotExistsAsync(
            _ordersContainerName, "/customerId");
        _ordersContainer = ordersResponse.Container;

        var productsCountQuery = _productsContainer.GetItemQueryIterator<int>("SELECT VALUE COUNT(1) FROM c");
        var productsCountResponse = await productsCountQuery.ReadNextAsync();
        if (productsCountResponse.Resource.First() == 0)
        {
            _logger.LogInformation("Seeding sample product data...");
            await SeedProductsAsync();
        }

        var ordersCountQuery = _ordersContainer.GetItemQueryIterator<int>("SELECT VALUE COUNT(1) FROM c");
        var ordersCountResponse = await ordersCountQuery.ReadNextAsync();
        if (ordersCountResponse.Resource.First() == 0)
        {
            _logger.LogInformation("Seeding sample order data...");
            await SeedOrdersAsync();
        }

        _initialized = true;
        _logger.LogInformation(
            "Cosmos DB initialized: database={Database}, productsContainer={ProductsContainer}, ordersContainer={OrdersContainer}",
            _databaseName, _productsContainerName, _ordersContainerName);
    }

    private async Task SeedProductsAsync()
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

        foreach (var product in products)
        {
            await _productsContainer!.CreateItemAsync(product, new PartitionKey(product.Category));
        }

        _logger.LogInformation("Seeded {Count} products.", products.Count);
    }

    private async Task SeedOrdersAsync()
    {
        var orders = new List<Order>
        {
            new() { CustomerId = "cust-001", Description = "Bulk keyboard order",            ProductName = "Wireless Keyboard", Quantity = 50, Total = 3999.50m, Status = "completed" },
            new() { CustomerId = "cust-002", Description = "Monitor refresh for office",      ProductName = "USB-C Monitor",     Quantity = 10, Total = 4499.90m, Status = "completed" },
            new() { CustomerId = "cust-003", Description = "Standing desks for new floor",    ProductName = "Standing Desk",     Quantity = 20, Total = 11999.80m, Status = "shipped" },
            new() { CustomerId = "cust-004", Description = "Webcams for remote team",         ProductName = "Webcam HD",         Quantity = 30, Total = 2699.70m, Status = "pending" }
        };

        foreach (var order in orders)
        {
            await _ordersContainer!.CreateItemAsync(order, new PartitionKey(order.CustomerId));
        }

        _logger.LogInformation("Seeded {Count} orders.", orders.Count);
    }

    /// <summary>Returns all products in the container.</summary>
    public async Task<IEnumerable<Product>> GetProductsAsync()
    {
        EnsureContainers();
        var query = _productsContainer!.GetItemQueryIterator<Product>("SELECT * FROM c");
        var results = new List<Product>();
        while (query.HasMoreResults)
        {
            var response = await query.ReadNextAsync();
            results.AddRange(response);
        }
        return results;
    }

    /// <summary>Returns a single product by id (cross-partition query).</summary>
    public async Task<Product?> GetProductByIdAsync(string id)
    {
        EnsureContainers();
        var queryDef = new QueryDefinition("SELECT * FROM c WHERE c.id = @id")
            .WithParameter("@id", id);
        var iterator = _productsContainer!.GetItemQueryIterator<Product>(queryDef);
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            var match = response.FirstOrDefault();
            if (match is not null) return match;
        }
        return null;
    }

    /// <summary>Creates a new product.</summary>
    public async Task<Product> CreateProductAsync(Product product)
    {
        EnsureContainers();
        product.Id = Guid.NewGuid().ToString();
        var response = await _productsContainer!.CreateItemAsync(product, new PartitionKey(product.Category));
        return response.Resource;
    }

    public async Task<IEnumerable<Order>> GetOrdersAsync()
    {
        EnsureContainers();
        var query = _ordersContainer!.GetItemQueryIterator<Order>("SELECT * FROM c");
        var results = new List<Order>();
        while (query.HasMoreResults)
        {
            var response = await query.ReadNextAsync();
            results.AddRange(response);
        }
        return results;
    }

    public async Task<Order?> GetOrderByIdAsync(string id)
    {
        EnsureContainers();
        var queryDef = new QueryDefinition("SELECT * FROM c WHERE c.id = @id")
            .WithParameter("@id", id);
        var iterator = _ordersContainer!.GetItemQueryIterator<Order>(queryDef);
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            var match = response.FirstOrDefault();
            if (match is not null) return match;
        }
        return null;
    }

    public async Task<Order> CreateOrderAsync(Order order)
    {
        EnsureContainers();
        order.Id = Guid.NewGuid().ToString();
        order.CreatedAt = DateTime.UtcNow;
        order.Status = "pending";
        var response = await _ordersContainer!.CreateItemAsync(order, new PartitionKey(order.CustomerId));
        return response.Resource;
    }

    /// <summary>Validates connectivity to the Cosmos DB account.</summary>
    public async Task<bool> CheckHealthAsync()
    {
        try
        {
            await _client.ReadAccountAsync();
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Cosmos DB health check failed.");
            return false;
        }
    }

    private void EnsureContainers()
    {
        if (!_initialized || _productsContainer is null || _ordersContainer is null)
        {
            _productsContainer ??= _client.GetContainer(_databaseName, _productsContainerName);
            _ordersContainer ??= _client.GetContainer(_databaseName, _ordersContainerName);
        }
    }
}
