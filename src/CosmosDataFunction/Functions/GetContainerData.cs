using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using System.Net;
using System.Text.Json;
using CosmosDataFunction.Models;
using CosmosDataFunction.Services;
using Microsoft.Azure.Cosmos;

namespace CosmosDataFunction.Functions;

public class GetContainerData
{
    private readonly ILogger<GetContainerData> _logger;
    private readonly ITokenValidationService _tokenValidation;
    private readonly IOboTokenProvider _oboTokenProvider;
    private readonly ICosmosDbService _cosmosDbService;

    // Mock user-to-container access mapping
    // In production, this would come from a database or external service
    private readonly Dictionary<string, List<string>> _userContainerAccess = new()
    {
        // These will be configured during setup with actual user OIDs
        { "1538ecf9-aeba-4377-b9c1-b244e9767315", new List<string> { "Sales" } },
        { "525ea289-2e77-4e60-8310-19cfdb39bd63", new List<string> { "HR" } },
        { "cd1064a1-47c3-4dc0-9dd8-31022751f6a0", new List<string> { "Finance" } },
        { "49813187-bd6e-42ec-ba53-f4135aa551b7", new List<string> { "Sales", "HR", "Finance" } }
    };

    public GetContainerData(
        ILogger<GetContainerData> logger,
        ITokenValidationService tokenValidation,
        IOboTokenProvider oboTokenProvider,
        ICosmosDbService cosmosDbService)
    {
        _logger = logger;
        _tokenValidation = tokenValidation;
        _oboTokenProvider = oboTokenProvider;
        _cosmosDbService = cosmosDbService;
    }

    [Function("GetContainerData")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "containers/query")] HttpRequestData req)
    {
        _logger.LogInformation("GetContainerData function processing request");

        try
        {
            // 1. Validate user token
            var authHeader = req.Headers.GetValues("Authorization").FirstOrDefault();
            if (string.IsNullOrEmpty(authHeader))
            {
                return CreateErrorResponse(req, HttpStatusCode.Unauthorized, "Missing authorization header");
            }

            var userId = await _tokenValidation.ValidateTokenAsync(authHeader);
            if (string.IsNullOrEmpty(userId))
            {
                return CreateErrorResponse(req, HttpStatusCode.Unauthorized, "Invalid token");
            }

            _logger.LogInformation("Token validated for user: {UserId}", userId);

            // 2. Parse request
            var requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            var request = JsonSerializer.Deserialize<ContainerQueryRequest>(requestBody,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

            if (request == null || string.IsNullOrEmpty(request.ContainerName))
            {
                return CreateErrorResponse(req, HttpStatusCode.BadRequest, "Invalid request body");
            }

            // // 3. Check user access to requested container
            // if (!_userContainerAccess.TryGetValue(userId, out var allowedContainers) ||
            //     !allowedContainers.Contains(request.ContainerName))
            // {
            //     _logger.LogWarning("User {UserId} attempted to access unauthorized container {Container}",
            //         userId, request.ContainerName);
            //     return CreateErrorResponse(req, HttpStatusCode.Forbidden,
            //         $"Access denied to container '{request.ContainerName}'");
            // }
            // _logger.LogInformation("User {UserId} authorized for container {Container}",
            //     userId, request.ContainerName);

            // 4. Get OBO token for Cosmos DB access
            var oboToken = await _oboTokenProvider.GetOboTokenAsync(authHeader);

            // 5. Query Cosmos DB using the OBO token
            var data = await _cosmosDbService.QueryContainerAsync(request.ContainerName, request.Query, oboToken);

            // 6. Return response
            var response = req.CreateResponse(HttpStatusCode.OK);
            await response.WriteAsJsonAsync(new ContainerQueryResponse
            {
                Success = true,
                Data = data,
                ItemCount = data.Count
            });

            return response;
        }
        catch (CosmosException cosmosEx)
        {
            _logger.LogError(cosmosEx, "Cosmos DB error: {StatusCode} - {Message}",
                cosmosEx.StatusCode, cosmosEx.Message);

            var statusCode = cosmosEx.StatusCode switch
            {
                System.Net.HttpStatusCode.NotFound => HttpStatusCode.NotFound,
                System.Net.HttpStatusCode.Forbidden => HttpStatusCode.Forbidden,
                System.Net.HttpStatusCode.Unauthorized => HttpStatusCode.Unauthorized,
                System.Net.HttpStatusCode.BadRequest => HttpStatusCode.BadRequest,
                System.Net.HttpStatusCode.TooManyRequests => HttpStatusCode.TooManyRequests,
                _ => HttpStatusCode.InternalServerError
            };

            return CreateErrorResponse(req, statusCode,
                $"Cosmos DB error: {cosmosEx.Message}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing request: {Message}", ex.Message);
            return CreateErrorResponse(req, HttpStatusCode.InternalServerError,
                $"Error processing request: {ex.Message}");
        }
    }

    [Function("GetUserAccess")]
    public async Task<HttpResponseData> GetUserAccess(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "user/access")] HttpRequestData req)
    {
        _logger.LogInformation("GetUserAccess function processing request");

        try
        {
            // Validate user token
            var authHeader = req.Headers.GetValues("Authorization").FirstOrDefault();
            if (string.IsNullOrEmpty(authHeader))
            {
                return CreateErrorResponse(req, HttpStatusCode.Unauthorized, "Missing authorization header");
            }

            var userId = await _tokenValidation.ValidateTokenAsync(authHeader);
            if (string.IsNullOrEmpty(userId))
            {
                return CreateErrorResponse(req, HttpStatusCode.Unauthorized, "Invalid token");
            }

            // Get user's allowed containers
            var allowedContainers = _userContainerAccess.TryGetValue(userId, out var containers)
                ? containers
                : new List<string>();

            var response = req.CreateResponse(HttpStatusCode.OK);
            await response.WriteAsJsonAsync(new UserAccessInfo
            {
                UserId = userId,
                AllowedContainers = allowedContainers
            });

            return response;
        }
        catch (CosmosException cosmosEx)
        {
            _logger.LogError(cosmosEx, "Cosmos DB error: {StatusCode} - {Message}",
                cosmosEx.StatusCode, cosmosEx.Message);

            var statusCode = cosmosEx.StatusCode switch
            {
                System.Net.HttpStatusCode.NotFound => HttpStatusCode.NotFound,
                System.Net.HttpStatusCode.Forbidden => HttpStatusCode.Forbidden,
                System.Net.HttpStatusCode.Unauthorized => HttpStatusCode.Unauthorized,
                System.Net.HttpStatusCode.BadRequest => HttpStatusCode.BadRequest,
                System.Net.HttpStatusCode.TooManyRequests => HttpStatusCode.TooManyRequests,
                _ => HttpStatusCode.InternalServerError
            };

            return CreateErrorResponse(req, statusCode,
                $"Cosmos DB error: {cosmosEx.Message}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing request: {Message}", ex.Message);
            return CreateErrorResponse(req, HttpStatusCode.InternalServerError,
                $"Error processing request: {ex.Message}");
        }
    }

    private static HttpResponseData CreateErrorResponse(HttpRequestData req, HttpStatusCode statusCode, string message)
    {
        var response = req.CreateResponse(statusCode);
        response.WriteAsJsonAsync(new ContainerQueryResponse
        {
            Success = false,
            ErrorMessage = message
        });
        return response;
    }
}
