namespace CatalogApi.Models;

public class Order
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string CustomerId { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string ProductName { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public decimal Total { get; set; }
    public string Status { get; set; } = "pending";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
