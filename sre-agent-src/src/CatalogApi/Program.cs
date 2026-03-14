using CatalogApi.Models;
using CatalogApi.Services;

var builder = WebApplication.CreateBuilder(args);

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------
builder.Services.AddApplicationInsightsTelemetry();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddSingleton<CosmosDbService>();
builder.Services.AddSingleton<OrderValidationService>();

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "Catalog API v1");
    c.RoutePrefix = "swagger";
    c.DocumentTitle = "Catalog API - Swagger UI";
});

// ---------------------------------------------------------------------------
// Cosmos DB initialization (graceful — app starts even if DB is unreachable)
// ---------------------------------------------------------------------------
try
{
    var cosmosDb = app.Services.GetRequiredService<CosmosDbService>();
    await cosmosDb.InitializeAsync();
}
catch (Exception ex)
{
    app.Logger.LogWarning(ex,
        "Cosmos DB initialization failed. The app will start, but database requests will return errors. " +
        "Verify that COSMOS_ACCOUNT_ENDPOINT is set correctly.");
}

// ---------------------------------------------------------------------------
// Endpoints
// ---------------------------------------------------------------------------

// Home page - quick status and navigation links for key API endpoints
app.MapGet("/", () =>
{
        const string html = """
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Catalog API</title>
    <style>
        body { font-family: Segoe UI, Arial, sans-serif; margin: 2rem; line-height: 1.5; }
        h1 { margin-bottom: .25rem; }
        p { color: #333; }
        ul { padding-left: 1.25rem; }
        code { background: #f2f2f2; padding: .15rem .35rem; border-radius: 4px; }
        .card { max-width: 760px; border: 1px solid #ddd; border-radius: 10px; padding: 1rem 1.25rem; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Catalog API is running</h1>
        <p>Use the links below to test core endpoints.</p>
        <ul>
            <li><a href="/health">GET /health</a> - service and Cosmos connectivity check</li>
            <li><a href="/products">GET /products</a> - list products</li>
            <li><a href="/orders">GET /orders</a> - list orders</li>
            <li><a href="/swagger">Swagger UI</a> - interactive API explorer</li>
            <li><a href="/swagger/v1/swagger.json">OpenAPI JSON</a> - API schema</li>
        </ul>
        <p>Write endpoints:</p>
        <ul>
            <li><code>POST /products</code></li>
            <li><code>POST /orders</code></li>
        </ul>
    </div>
</body>
</html>
""";

        return Results.Content(html, "text/html");
});

// Health check — validates Cosmos DB connectivity
app.MapGet("/health", async (CosmosDbService db) =>
{
    var healthy = await db.CheckHealthAsync();
    return healthy
        ? Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow })
        : Results.Json(new { status = "unhealthy", timestamp = DateTime.UtcNow }, statusCode: 503);
});

// GET /products — list all products
app.MapGet("/products", async (CosmosDbService db) =>
{
    var products = await db.GetProductsAsync();
    return Results.Ok(products);
});

// GET /products/{id} — get a single product by id
app.MapGet("/products/{id}", async (string id, CosmosDbService db) =>
{
    var product = await db.GetProductByIdAsync(id);
    return product is not null ? Results.Ok(product) : Results.NotFound();
});

// POST /products — create a new product
app.MapPost("/products", async (Product product, CosmosDbService db) =>
{
    var created = await db.CreateProductAsync(product);
    return Results.Created($"/products/{created.Id}", created);
});

// GET /orders — list all orders
app.MapGet("/orders", async (CosmosDbService db) =>
{
    var orders = await db.GetOrdersAsync();
    return Results.Ok(orders);
});

// GET /orders/{id} — get a single order by id
app.MapGet("/orders/{id}", async (string id, CosmosDbService db) =>
{
    var order = await db.GetOrderByIdAsync(id);
    return order is not null ? Results.Ok(order) : Results.NotFound();
});

// POST /orders — create a new order (can trigger CPU spike in strict mode)
app.MapPost("/orders", async (Order order, CosmosDbService db, OrderValidationService validator) =>
{
    var validation = validator.ValidateOrder(order);
    if (!validation.IsValid)
        return Results.BadRequest(new { error = validation.Error });

    var created = await db.CreateOrderAsync(order);
    return Results.Created($"/orders/{created.Id}", created);
});

app.Run();
