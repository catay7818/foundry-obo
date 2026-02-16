using Microsoft.Azure.Cosmos;
using Azure.Identity;
using Azure.Core;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using CosmosDataFunction.Models;

namespace CosmosDataFunction.Services;

internal class CosmosQueryResponse<T>
{
    public List<T>? Documents { get; set; }
}

public interface ICosmosDbService
{
    Task<List<object>> QueryContainerAsync(string containerName, string query, string? oboToken = null);
    Task<bool> ItemExistsAsync(string containerName, string id, string partitionKey, string? oboToken = null);
    Task<dynamic> UpsertItemAsync(string containerName, dynamic item, string partitionKey, string? oboToken = null);
}

public class CosmosDbService : ICosmosDbService
{
    private readonly string _cosmosEndpoint;
    private readonly string _databaseName;
    private readonly CosmosClient _defaultCosmosClient;
    private readonly ILogger<CosmosDbService> _logger;

    public CosmosDbService(ILogger<CosmosDbService> logger)
    {
        _logger = logger;
        _logger.LogInformation("Initializing CosmosDbService");

        _cosmosEndpoint = Environment.GetEnvironmentVariable("CosmosDbEndpoint")
            ?? throw new InvalidOperationException("CosmosDbEndpoint not configured");
        _databaseName = Environment.GetEnvironmentVariable("CosmosDbDatabase")
            ?? throw new InvalidOperationException("CosmosDbDatabase not configured");
        var tenantId = Environment.GetEnvironmentVariable("TenantId")
            ?? throw new InvalidOperationException("TenantId not configured");

        _logger.LogInformation("Configuring Cosmos DB connection: Endpoint={Endpoint}, Database={Database}",
            _cosmosEndpoint, _databaseName);

        // Use managed identity for Cosmos DB authentication (fallback)
        var credential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
        {
            TenantId = tenantId
        });
        _defaultCosmosClient = new CosmosClient(_cosmosEndpoint, credential);

        _logger.LogInformation("CosmosDbService initialized successfully");
    }

    /// <summary>
    /// Gets a CosmosClient instance using the provided OBO token or the default client.
    /// </summary>
    private CosmosClient GetCosmosClient(string? oboToken)
    {
        if (string.IsNullOrEmpty(oboToken))
        {
            _logger.LogDebug("Using default CosmosClient with managed identity");
            return _defaultCosmosClient;
        }

        _logger.LogDebug("Creating CosmosClient with OBO token");
        // Create a new client with the OBO token
        var tokenCredential = new OboTokenCredential(oboToken);
        return new CosmosClient(_cosmosEndpoint, tokenCredential);
    }

    /// <summary>
    /// Maps container name to the appropriate data type for deserialization.
    /// </summary>
    private Type GetContainerDataType(string containerName)
    {
        return containerName.ToLowerInvariant() switch
        {
            "finance" => typeof(FinanceData),
            "hr" => typeof(HrData),
            "sales" => typeof(SalesData),
            _ => typeof(object)
        };
    }

    /// <summary>
    /// Deserializes the query response content to the appropriate type based on container name.
    /// </summary>
    private List<object> DeserializeQueryResponse(string content, string containerName)
    {
        var dataType = GetContainerDataType(containerName);
        var responseType = typeof(CosmosQueryResponse<>).MakeGenericType(dataType);
        var options = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        };

        var queryResponse = JsonSerializer.Deserialize(content, responseType, options);
        if (queryResponse == null)
        {
            return new List<object>();
        }

        var documentsProperty = responseType.GetProperty("Documents");
        var documents = documentsProperty?.GetValue(queryResponse) as IEnumerable<object>;

        return documents?.ToList() ?? new List<object>();
    }

    public async Task<List<object>> QueryContainerAsync(string containerName, string query, string? oboToken = null)
    {
        _logger.LogInformation("Querying container {Container} with query: {Query}", containerName, query);
        var startTime = DateTime.UtcNow;

        try
        {
            var cosmosClient = GetCosmosClient(oboToken);
            var container = cosmosClient.GetContainer(_databaseName, containerName);
            var results = new List<object>();
            var pageCount = 0;

            using var resultSet = container.GetItemQueryStreamIterator(new QueryDefinition(query));

            while (resultSet.HasMoreResults)
            {
                using var response = await resultSet.ReadNextAsync();
                pageCount++;

                if (response.IsSuccessStatusCode)
                {
                    using var streamReader = new StreamReader(response.Content);
                    var content = await streamReader.ReadToEndAsync();
                    var documents = DeserializeQueryResponse(content, containerName);

                    results.AddRange(documents);
                    _logger.LogDebug("Retrieved {Count} documents from page {Page}",
                        documents.Count, pageCount);
                }
                else
                {
                    _logger.LogError("Query page {Page} failed with status code {StatusCode}",
                        pageCount, response.StatusCode);

                    throw new CosmosException(
                        $"Query failed (status: {response.StatusCode})",
                        response.StatusCode,
                        0,
                        string.Empty,
                        response.Headers.RequestCharge);
                }
            }

            var duration = DateTime.UtcNow - startTime;
            _logger.LogInformation("Query completed successfully. Container={Container}, DocumentCount={Count}, Pages={Pages}, Duration={Duration}ms",
                containerName, results.Count, pageCount, duration.TotalMilliseconds);

            return results;
        }
        catch (Exception ex)
        {
            var duration = DateTime.UtcNow - startTime;
            _logger.LogError(ex, "Query failed for container {Container} after {Duration}ms. Query: {Query}",
                containerName, duration.TotalMilliseconds, query);
            throw;
        }
    }

    public async Task<bool> ItemExistsAsync(string containerName, string id, string partitionKey, string? oboToken = null)
    {
        _logger.LogDebug("Checking if item exists: Container={Container}, Id={Id}, PartitionKey={PartitionKey}",
            containerName, id, partitionKey);

        try
        {
            var cosmosClient = GetCosmosClient(oboToken);
            var container = cosmosClient.GetContainer(_databaseName, containerName);
            await container.ReadItemAsync<dynamic>(id, new PartitionKey(partitionKey));

            _logger.LogDebug("Item exists: Container={Container}, Id={Id}", containerName, id);
            return true;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            _logger.LogDebug("Item not found: Container={Container}, Id={Id}", containerName, id);
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error checking item existence: Container={Container}, Id={Id}",
                containerName, id);
            throw;
        }
    }

    public async Task<dynamic> UpsertItemAsync(string containerName, dynamic item, string partitionKey, string? oboToken = null)
    {
        _logger.LogInformation("Upserting item to container {Container} with partition key {PartitionKey}",
            containerName, partitionKey);
        var startTime = DateTime.UtcNow;

        try
        {
            var cosmosClient = GetCosmosClient(oboToken);
            var container = cosmosClient.GetContainer(_databaseName, containerName);

            // Convert JsonElement to stream for proper Cosmos DB serialization
            if (item is JsonElement jsonElement)
            {
                _logger.LogDebug("Upserting JsonElement item to container {Container}", containerName);
                using var stream = new MemoryStream(System.Text.Encoding.UTF8.GetBytes(jsonElement.GetRawText()));
                var response = await container.UpsertItemStreamAsync(stream, new PartitionKey(partitionKey));

                if (!response.IsSuccessStatusCode)
                {
                    using var reader = new StreamReader(response.Content);
                    var errorContent = await reader.ReadToEndAsync();
                    _logger.LogError("Upsert failed with status {StatusCode}: {Error}",
                        response.StatusCode, errorContent);
                    throw new CosmosException($"Upsert failed: {errorContent}", response.StatusCode, 0, string.Empty, 0);
                }

                using var responseStream = response.Content;
                var result = await JsonSerializer.DeserializeAsync<object>(responseStream);

                var duration = DateTime.UtcNow - startTime;
                _logger.LogInformation("JsonElement item upserted successfully to container {Container}, Duration={Duration}ms, RU={RU}",
                    containerName, duration.TotalMilliseconds, response.Headers.RequestCharge);

                return result ?? throw new InvalidOperationException("Deserialization returned null");
            }

            _logger.LogDebug("Upserting regular item to container {Container}", containerName);
            var regularResponse = await container.UpsertItemAsync(item, new PartitionKey(partitionKey));

            var regularDuration = DateTime.UtcNow - startTime;
            _logger.LogInformation("Item upserted successfully to container");

            return regularResponse.Resource;
        }
        catch (Exception ex)
        {
            var duration = DateTime.UtcNow - startTime;
            _logger.LogError(ex, "Upsert failed for container {Container} after {Duration}ms",
                containerName, duration.TotalMilliseconds);
            throw;
        }
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
