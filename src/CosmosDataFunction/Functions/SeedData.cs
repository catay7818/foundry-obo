using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using System.Net;
using System.Text.Json;
using CosmosDataFunction.Services;

namespace CosmosDataFunction.Functions;

public class SeedData
{
    private readonly ILogger<SeedData> _logger;
    private readonly ICosmosDbService _cosmosDbService;

    // Mapping of file names to container names
    private readonly Dictionary<string, string> _fileToContainerMapping = new()
    {
        { "finance.json", "Finance" },
        { "hr.json", "HR" },
        { "sales.json", "Sales" }
    };

    // Mapping of container names to partition key property names
    private readonly Dictionary<string, string> _containerPartitionKeyMapping = new()
    {
        { "Finance", "fiscalYear" },
        { "HR", "department" },
        { "Sales", "region" }
    };

    public SeedData(
        ILogger<SeedData> logger,
        ICosmosDbService cosmosDbService)
    {
        _logger = logger;
        _cosmosDbService = cosmosDbService;
    }

    [Function("SeedData")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "seed")] HttpRequestData req)
    {
        _logger.LogInformation("SeedData function processing request");

        var seedResults = new Dictionary<string, SeedResult>();

        try
        {
            // Get the directory where the sample data files are located
            var executionPath = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
            var dataPath = Path.Combine(executionPath!, "SampleData");

            _logger.LogInformation($"Looking for sample data in: {dataPath}");

            if (!Directory.Exists(dataPath))
            {
                _logger.LogError($"Sample data directory not found: {dataPath}");
                var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
                await errorResponse.WriteAsJsonAsync(new
                {
                    Success = false,
                    ErrorMessage = $"Sample data directory not found: {dataPath}",
                    Results = seedResults
                });
                return errorResponse;
            }

            // Process each data file
            foreach (var (fileName, containerName) in _fileToContainerMapping)
            {
                var filePath = Path.Combine(dataPath, fileName);
                var result = new SeedResult { ContainerName = containerName };

                try
                {
                    if (!File.Exists(filePath))
                    {
                        _logger.LogWarning($"File not found: {filePath}");
                        result.ErrorMessage = $"File not found: {fileName}";
                        seedResults[containerName] = result;
                        continue;
                    }

                    _logger.LogInformation($"Processing file: {fileName} for container: {containerName}");

                    // Read and parse the JSON file
                    var jsonContent = await File.ReadAllTextAsync(filePath);
                    var records = JsonSerializer.Deserialize<List<JsonElement>>(jsonContent);

                    if (records == null || records.Count == 0)
                    {
                        _logger.LogWarning($"No records found in {fileName}");
                        result.ErrorMessage = "No records found in file";
                        seedResults[containerName] = result;
                        continue;
                    }

                    _logger.LogInformation($"Found {records.Count} records in {fileName}");

                    // Process each record
                    foreach (var record in records)
                    {
                        try
                        {
                            // Get the id from the record
                            if (!record.TryGetProperty("id", out var idElement))
                            {
                                _logger.LogWarning($"Record missing 'id' property, skipping");
                                result.SkippedCount++;
                                continue;
                            }

                            var id = idElement.GetString();
                            if (string.IsNullOrEmpty(id))
                            {
                                _logger.LogWarning($"Record has empty 'id' property, skipping");
                                result.SkippedCount++;
                                continue;
                            }

                            // Get the partition key property name for this container
                            if (!_containerPartitionKeyMapping.TryGetValue(containerName, out var partitionKeyProperty))
                            {
                                _logger.LogError($"No partition key mapping found for container: {containerName}");
                                result.SkippedCount++;
                                continue;
                            }

                            // Extract the partition key value from the record
                            if (!record.TryGetProperty(partitionKeyProperty, out var partitionKeyElement))
                            {
                                _logger.LogWarning($"Record missing '{partitionKeyProperty}' property (partition key), skipping");
                                result.SkippedCount++;
                                continue;
                            }

                            var partitionKey = partitionKeyElement.GetString();
                            if (string.IsNullOrEmpty(partitionKey))
                            {
                                _logger.LogWarning($"Record has empty '{partitionKeyProperty}' property (partition key), skipping");
                                result.SkippedCount++;
                                continue;
                            }

                            // Check if the item already exists
                            var exists = await _cosmosDbService.ItemExistsAsync(containerName, id, partitionKey);

                            if (exists)
                            {
                                _logger.LogInformation($"Item with id '{id}' already exists in {containerName}, skipping");
                                result.ExistingCount++;
                            }
                            else
                            {
                                // Upsert the item
                                await _cosmosDbService.UpsertItemAsync(containerName, record, partitionKey);
                                _logger.LogInformation($"Successfully added item with id '{id}' to {containerName}");
                                result.AddedCount++;
                            }
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(ex, $"Error processing record in {fileName}: {ex.Message}");
                            result.SkippedCount++;
                        }
                    }

                    result.TotalRecords = records.Count;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Error processing file {fileName}");
                    result.ErrorMessage = ex.Message;
                }

                seedResults[containerName] = result;
            }

            var response = req.CreateResponse(HttpStatusCode.OK);
            await response.WriteAsJsonAsync(new
            {
                Success = true,
                Message = "Seed operation completed",
                Results = seedResults
            });

            return response;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in SeedData function");

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
