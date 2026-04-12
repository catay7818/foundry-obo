using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using System.Net;
using CosmosDataFunction.Models;
using CosmosDataFunction.Services;
using Microsoft.Azure.Cosmos;

namespace CosmosDataFunction.Functions;

public class GetUserAccess
{
    private readonly ILogger<GetUserAccess> _logger;
    private readonly ITokenValidationService _tokenValidation;

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

    public GetUserAccess(
        ILogger<GetUserAccess> logger,
        ITokenValidationService tokenValidation)
    {
        _logger = logger;
        _tokenValidation = tokenValidation;
    }

    [Function("GetUserAccess")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "user/access")] HttpRequestData req)
    {
        _logger.LogInformation("GetUserAccess function processing request");

        try
        {
            // Validate user token
            var authHeader = req.Headers.GetValues("Authorization").FirstOrDefault();
            if (string.IsNullOrEmpty(authHeader))
            {
                return await CreateErrorResponse(req, HttpStatusCode.Unauthorized, "Missing authorization header");
            }

            var userId = await _tokenValidation.ValidateTokenAsync(authHeader);
            if (string.IsNullOrEmpty(userId))
            {
                return await CreateErrorResponse(req, HttpStatusCode.Unauthorized, "Invalid token");
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

            // var statusCode = cosmosEx.StatusCode switch
            // {
            //     System.Net.HttpStatusCode.NotFound => HttpStatusCode.NotFound,
            //     System.Net.HttpStatusCode.Forbidden => HttpStatusCode.Forbidden,
            //     System.Net.HttpStatusCode.Unauthorized => HttpStatusCode.Unauthorized,
            //     System.Net.HttpStatusCode.BadRequest => HttpStatusCode.BadRequest,
            //     System.Net.HttpStatusCode.TooManyRequests => HttpStatusCode.TooManyRequests,
            //     _ => HttpStatusCode.InternalServerError
            // };

            _logger.LogInformation("cosmosEx.StatusCode = {StatusCode}", cosmosEx.StatusCode);
            return await CreateErrorResponse(req, cosmosEx.StatusCode,
                $"Cosmos DB error: {cosmosEx.Message}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing request: {Message}", ex.Message);
            return await CreateErrorResponse(req, HttpStatusCode.InternalServerError,
                $"Error processing request: {ex.Message}");
        }
    }

    private static async Task<HttpResponseData> CreateErrorResponse(HttpRequestData req, HttpStatusCode statusCode, string message)
    {
        var response = req.CreateResponse(statusCode);
        await response.WriteAsJsonAsync(new ContainerQueryResponse
        {
            Success = false,
            ErrorMessage = message
        });
        response.StatusCode = statusCode;
        return response;
    }
}
