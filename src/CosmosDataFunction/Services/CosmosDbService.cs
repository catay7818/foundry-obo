using Microsoft.Azure.Cosmos;
using Azure.Identity;

namespace CosmosDataFunction.Services;

public interface ICosmosDbService
{
    Task<List<dynamic>> QueryContainerAsync(string containerName, string query);
    Task<bool> ItemExistsAsync(string containerName, string id, string partitionKey);
    Task<dynamic> UpsertItemAsync(string containerName, dynamic item);
}

public class CosmosDbService : ICosmosDbService
{
    private readonly CosmosClient _cosmosClient;
    private readonly string _databaseName;

    public CosmosDbService()
    {
        var cosmosEndpoint = Environment.GetEnvironmentVariable("CosmosDbEndpoint")
            ?? throw new InvalidOperationException("CosmosDbEndpoint not configured");
        _databaseName = Environment.GetEnvironmentVariable("CosmosDbDatabase")
            ?? throw new InvalidOperationException("CosmosDbDatabase not configured");

        // Use managed identity for Cosmos DB authentication
        var credential = new DefaultAzureCredential();
        _cosmosClient = new CosmosClient(cosmosEndpoint, credential);
    }

    public async Task<List<dynamic>> QueryContainerAsync(string containerName, string query)
    {
        var container = _cosmosClient.GetContainer(_databaseName, containerName);
        var results = new List<dynamic>();

        using var resultSet = container.GetItemQueryIterator<dynamic>(new QueryDefinition(query));

        while (resultSet.HasMoreResults)
        {
            var response = await resultSet.ReadNextAsync();
            results.AddRange(response);
        }

        return results;
    }

    public async Task<bool> ItemExistsAsync(string containerName, string id, string partitionKey)
    {
        try
        {
            var container = _cosmosClient.GetContainer(_databaseName, containerName);
            await container.ReadItemAsync<dynamic>(id, new PartitionKey(partitionKey));
            return true;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return false;
        }
    }

    public async Task<dynamic> UpsertItemAsync(string containerName, dynamic item)
    {
        var container = _cosmosClient.GetContainer(_databaseName, containerName);
        var response = await container.UpsertItemAsync(item);
        return response.Resource;
    }
}
