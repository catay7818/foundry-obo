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
