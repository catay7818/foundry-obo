using Microsoft.Azure.Cosmos;
using Azure.Identity;
using System.Text.Json;

namespace CosmosDataFunction.Services;

public interface ICosmosDbService
{
    Task<List<dynamic>> QueryContainerAsync(string containerName, string query);
    Task<bool> ItemExistsAsync(string containerName, string id, string partitionKey);
    Task<dynamic> UpsertItemAsync(string containerName, dynamic item, string partitionKey);
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

    public async Task<dynamic> UpsertItemAsync(string containerName, dynamic item, string partitionKey)
    {
        var container = _cosmosClient.GetContainer(_databaseName, containerName);

        // Convert JsonElement to stream for proper Cosmos DB serialization
        if (item is JsonElement jsonElement)
        {
            using var stream = new MemoryStream(System.Text.Encoding.UTF8.GetBytes(jsonElement.GetRawText()));
            var response = await container.UpsertItemStreamAsync(stream, new PartitionKey(partitionKey));

            if (!response.IsSuccessStatusCode)
            {
                using var reader = new StreamReader(response.Content);
                var errorContent = await reader.ReadToEndAsync();
                throw new CosmosException($"Upsert failed: {errorContent}", response.StatusCode, 0, string.Empty, 0);
            }

            using var responseStream = response.Content;
            var result = await JsonSerializer.DeserializeAsync<object>(responseStream);
            return result ?? throw new InvalidOperationException("Deserialization returned null");
        }

        var regularResponse = await container.UpsertItemAsync(item, new PartitionKey(partitionKey));
        return regularResponse.Resource;
    }
}
