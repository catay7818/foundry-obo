using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using System.Net;
using System.Text.Json;
using CosmosDataFunction.Services;

namespace CosmosDataFunction.Functions;

public class SeedMediaData
{
    private readonly ILogger<SeedMediaData> _logger;
    private readonly ICosmosDbService _cosmosDbService;

    // Mapping of file paths (relative to SampleData) to container names
    private readonly Dictionary<string, string> _fileToContainerMapping = new()
    {
        { Path.Combine("media", "sh-show.json"), "sh-show" },
        { Path.Combine("media", "sh-production.json"), "sh-production" },
        { Path.Combine("media", "sh-costume.json"), "sh-costume" },
        { Path.Combine("media", "cc-show.json"), "cc-show" },
        { Path.Combine("media", "cc-production.json"), "cc-production" },
        { Path.Combine("media", "cc-costume.json"), "cc-costume" }
    };

    // All 6 media containers use /type as the partition key
    private const string PartitionKeyProperty = "type";

    public SeedMediaData(
        ILogger<SeedMediaData> logger,
        ICosmosDbService cosmosDbService)
    {
        _logger = logger;
        _cosmosDbService = cosmosDbService;
    }

    [Function("SeedMediaData")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "seed/media")] HttpRequestData req)
    {
        _logger.LogInformation("SeedMediaData function processing request");

        var seedResults = new Dictionary<string, SeedResult>();

        try
        {
            var executionPath = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
            var dataPath = Path.Combine(executionPath!, "SampleData");

            _logger.LogInformation("Looking for media sample data in: {DataPath}", dataPath);

            if (!Directory.Exists(dataPath))
            {
                _logger.LogError("Sample data directory not found: {DataPath}", dataPath);
                var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
                await errorResponse.WriteAsJsonAsync(new
                {
                    Success = false,
                    ErrorMessage = $"Sample data directory not found: {dataPath}",
                    Results = seedResults
                });
                return errorResponse;
            }

            foreach (var (relativePath, containerName) in _fileToContainerMapping)
            {
                var filePath = Path.Combine(dataPath, relativePath);
                var result = new SeedResult { ContainerName = containerName };

                try
                {
                    if (!File.Exists(filePath))
                    {
                        _logger.LogWarning("File not found: {FilePath}", filePath);
                        result.ErrorMessage = $"File not found: {relativePath}";
                        seedResults[containerName] = result;
                        continue;
                    }

                    _logger.LogInformation("Processing file: {FilePath} for container: {ContainerName}", relativePath, containerName);

                    var jsonContent = await File.ReadAllTextAsync(filePath);
                    var records = JsonSerializer.Deserialize<List<JsonElement>>(jsonContent);

                    if (records == null || records.Count == 0)
                    {
                        _logger.LogWarning("No records found in {FilePath}", relativePath);
                        result.ErrorMessage = "No records found in file";
                        seedResults[containerName] = result;
                        continue;
                    }

                    _logger.LogInformation("Found {Count} records in {FilePath}", records.Count, relativePath);

                    foreach (var record in records)
                    {
                        try
                        {
                            if (!record.TryGetProperty("id", out var idElement))
                            {
                                _logger.LogWarning("Record missing 'id' property, skipping");
                                result.SkippedCount++;
                                continue;
                            }

                            var id = idElement.GetString();
                            if (string.IsNullOrEmpty(id))
                            {
                                _logger.LogWarning("Record has empty 'id' property, skipping");
                                result.SkippedCount++;
                                continue;
                            }

                            if (!record.TryGetProperty(PartitionKeyProperty, out var partitionKeyElement))
                            {
                                _logger.LogWarning("Record missing '{PartitionKey}' property (partition key), skipping", PartitionKeyProperty);
                                result.SkippedCount++;
                                continue;
                            }

                            var partitionKey = partitionKeyElement.GetString();
                            if (string.IsNullOrEmpty(partitionKey))
                            {
                                _logger.LogWarning("Record has empty '{PartitionKey}' property (partition key), skipping", PartitionKeyProperty);
                                result.SkippedCount++;
                                continue;
                            }

                            var exists = await _cosmosDbService.ItemExistsAsync(containerName, id, partitionKey);

                            if (exists)
                            {
                                _logger.LogInformation("Item with id '{Id}' already exists in {ContainerName}, skipping", id, containerName);
                                result.ExistingCount++;
                            }
                            else
                            {
                                await _cosmosDbService.UpsertItemAsync(containerName, record, partitionKey);
                                _logger.LogInformation("Successfully added item with id '{Id}' to {ContainerName}", id, containerName);
                                result.AddedCount++;
                            }
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(ex, "Error processing record in {FilePath}: {Message}", relativePath, ex.Message);
                            result.SkippedCount++;
                        }
                    }

                    result.TotalRecords = records.Count;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error processing file {FilePath}", relativePath);
                    result.ErrorMessage = ex.Message;
                }

                seedResults[containerName] = result;
            }

            var response = req.CreateResponse(HttpStatusCode.OK);
            await response.WriteAsJsonAsync(new
            {
                Success = true,
                Message = "Media seed operation completed",
                Results = seedResults
            });

            return response;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in SeedMediaData function");

            var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
            await errorResponse.WriteAsJsonAsync(new
            {
                Success = false,
                ErrorMessage = ex.Message,
                Results = seedResults
            });

            return errorResponse;
        }
    }

    private class SeedResult
    {
        public string ContainerName { get; set; } = string.Empty;
        public int TotalRecords { get; set; }
        public int AddedCount { get; set; }
        public int ExistingCount { get; set; }
        public int SkippedCount { get; set; }
        public string? ErrorMessage { get; set; }
    }
}
