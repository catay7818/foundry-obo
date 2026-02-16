namespace CosmosDataFunction.Models;

public class ContainerQueryRequest
{
    public string ContainerName { get; set; } = string.Empty;
    public string Query { get; set; } = "SELECT * FROM c";
}

public class ContainerQueryResponse
{
    public bool Success { get; set; }
    public string? ErrorMessage { get; set; }
    public List<object>? Data { get; set; }
    public int ItemCount { get; set; }
}

public class UserAccessInfo
{
    public string UserId { get; set; } = string.Empty;
    public List<string> AllowedContainers { get; set; } = new();
}

/// <summary>
/// Represents financial data including budget and expense information.
/// </summary>
public class FinanceData
{
    public string Id { get; set; } = string.Empty;
    public string FiscalYear { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string Quarter { get; set; } = string.Empty;
    public bool Approved { get; set; }
}

/// <summary>
/// Represents human resources employee data.
/// </summary>
public class HrData
{
    public string Id { get; set; } = string.Empty;
    public string Department { get; set; } = string.Empty;
    public string EmployeeName { get; set; } = string.Empty;
    public string Position { get; set; } = string.Empty;
    public string StartDate { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
}

/// <summary>
/// Represents sales data including regional product sales information.
/// </summary>
public class SalesData
{
    public string Id { get; set; } = string.Empty;
    public string Region { get; set; } = string.Empty;
    public string Product { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public decimal Revenue { get; set; }
    public string Quarter { get; set; } = string.Empty;
}
