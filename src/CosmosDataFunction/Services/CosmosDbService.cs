using Microsoft.Azure.Cosmos;
using Azure.Identity;
using Azure.Core;
using System.Text.Json;

namespace CosmosDataFunction.Services;

public interface ICosmosDbService
{
    Task<List<dynamic>> QueryContainerAsync(string containerName, string query, string? oboToken = null);
    Task<bool> ItemExistsAsync(string containerName, string id, string partitionKey, string? oboToken = null);
    Task<dynamic> UpsertItemAsync(string containerName, dynamic item, string partitionKey, string? oboToken = null);
}

public class CosmosDbService : ICosmosDbService
{
    private readonly string _cosmosEndpoint;
    private readonly string _databaseName;
    private readonly CosmosClient _defaultCosmosClient;

    public CosmosDbService()
    {
        _cosmosEndpoint = Environment.GetEnvironmentVariable("CosmosDbEndpoint")
            ?? throw new InvalidOperationException("CosmosDbEndpoint not configured");
        _databaseName = Environment.GetEnvironmentVariable("CosmosDbDatabase")
            ?? throw new InvalidOperationException("CosmosDbDatabase not configured");
        var tenantId = Environment.GetEnvironmentVariable("TenantId")
            ?? throw new InvalidOperationException("TenantId not configured");

        // Use managed identity for Cosmos DB authentication (fallback)
        var credential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
        {
            TenantId = tenantId
        });
        _defaultCosmosClient = new CosmosClient(_cosmosEndpoint, credential);
    }

    /// <summary>
    /// Gets a CosmosClient instance using the provided OBO token or the default client.
    /// </summary>
    private CosmosClient GetCosmosClient(string? oboToken)
    {
        if (string.IsNullOrEmpty(oboToken))
        {
            return _defaultCosmosClient;
        }

        // Create a new client with the OBO token
        var tokenCredential = new OboTokenCredential(oboToken);
        return new CosmosClient(_cosmosEndpoint, tokenCredential);
    }

    public async Task<List<dynamic>> QueryContainerAsync(string containerName, string query, string? oboToken = null)
    {
        var cosmosClient = GetCosmosClient(oboToken);
        var container = cosmosClient.GetContainer(_databaseName, containerName);
        var results = new List<dynamic>();

        using var resultSet = container.GetItemQueryIterator<dynamic>(new QueryDefinition(query));

        while (resultSet.HasMoreResults)
        {
            var response = await resultSet.ReadNextAsync();
            results.AddRange(response);
        }

        return results;
    }

    public async Task<bool> ItemExistsAsync(string containerName, string id, string partitionKey, string? oboToken = null)
    {
        try
        {
            var cosmosClient = GetCosmosClient(oboToken);
            var container = cosmosClient.GetContainer(_databaseName, containerName);
            await container.ReadItemAsync<dynamic>(id, new PartitionKey(partitionKey));
            return true;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return false;
        }
    }

    public async Task<dynamic> UpsertItemAsync(string containerName, dynamic item, string partitionKey, string? oboToken = null)
    {
        var cosmosClient = GetCosmosClient(oboToken);
        var container = cosmosClient.GetContainer(_databaseName, containerName);

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

/// <summary>
/// Custom TokenCredential that wraps an OBO (On-Behalf-Of) access token.
/// </summary>
internal class OboTokenCredential : TokenCredential
{
    private readonly string _accessToken;

    public OboTokenCredential(string accessToken)
    {
        _accessToken = accessToken ?? throw new ArgumentNullException(nameof(accessToken));
    }

    public override AccessToken GetToken(TokenRequestContext requestContext, CancellationToken cancellationToken)
    {
        // Return the OBO token with a far future expiration
        // The token's actual expiration is managed by the identity provider
        return new AccessToken(_accessToken, DateTimeOffset.UtcNow.AddHours(1));
    }

    public override ValueTask<AccessToken> GetTokenAsync(TokenRequestContext requestContext, CancellationToken cancellationToken)
    {
        return new ValueTask<AccessToken>(GetToken(requestContext, cancellationToken));
    }
}
