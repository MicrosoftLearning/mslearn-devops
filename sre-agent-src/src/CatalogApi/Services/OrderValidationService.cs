using System.Text.RegularExpressions;
using CatalogApi.Models;

namespace CatalogApi.Services;

public class OrderValidationService(IConfiguration configuration, ILogger<OrderValidationService> logger)
{
    public ValidationResult ValidateOrder(Order order)
    {
        if (string.IsNullOrWhiteSpace(order.CustomerId))
            return ValidationResult.Fail("CustomerId is required.");

        if (string.IsNullOrWhiteSpace(order.Description))
            return ValidationResult.Fail("Description is required.");

        if (order.Quantity <= 0)
            return ValidationResult.Fail("Quantity must be greater than zero.");

        if (order.Total <= 0)
            return ValidationResult.Fail("Total must be greater than zero.");

        var validationMode = configuration["VALIDATION_MODE"] ?? "standard";

        if (validationMode.Equals("strict", StringComparison.OrdinalIgnoreCase))
        {
            const string pattern = @"^([a-zA-Z0-9]+\s?)+$";

            try
            {
                var isMatch = Regex.IsMatch(
                    order.Description,
                    pattern,
                    RegexOptions.None,
                    TimeSpan.FromSeconds(10));

                if (!isMatch)
                    return ValidationResult.Fail("Description contains invalid characters (strict validation).");
            }
            catch (RegexMatchTimeoutException ex)
            {
                logger.LogError(ex,
                    "Regex validation timed out after {Timeout}s for description of length {Length}.",
                    10, order.Description.Length);
                throw;
            }
        }
        else
        {
            if (!Regex.IsMatch(order.Description, @"^[\w\s.,!?'-]+$"))
                return ValidationResult.Fail("Description contains invalid characters.");
        }

        return ValidationResult.Success();
    }
}

public record ValidationResult(bool IsValid, string? Error = null)
{
    public static ValidationResult Success() => new(true);
    public static ValidationResult Fail(string error) => new(false, error);
}
