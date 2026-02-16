using Microsoft.Identity.Client;

namespace CosmosDataFunction.Services;

public interface IOboTokenProvider
{
    Task<string> GetOboTokenAsync(string userToken);
}

public class OboTokenProvider : IOboTokenProvider
{
    private readonly string _tenantId;
    private readonly string _functionClientId;
    private readonly string _functionClientSecret;
    private readonly IConfidentialClientApplication _confidentialClient;
    private const string CosmosScope = "https://cosmos.azure.com/user_impersonation";

    public OboTokenProvider()
    {
        _tenantId = Environment.GetEnvironmentVariable("TenantId")
            ?? throw new InvalidOperationException("TenantId not configured");
        _functionClientId = Environment.GetEnvironmentVariable("FunctionClientId")
            ?? throw new InvalidOperationException("FunctionClientId not configured");
        _functionClientSecret = Environment.GetEnvironmentVariable("FunctionClientSecret")
            ?? throw new InvalidOperationException("FunctionClientSecret not configured");

        var authority = $"https://login.microsoftonline.com/{_tenantId}";

        _confidentialClient = ConfidentialClientApplicationBuilder
            .Create(_functionClientId)
            .WithClientSecret(_functionClientSecret)
            .WithAuthority(authority)
            .Build();
    }

    public async Task<string> GetOboTokenAsync(string authorizationHeader)
    {
        // Extract the bearer token from the Authorization header
        var userToken = authorizationHeader.Replace("Bearer ", "", StringComparison.OrdinalIgnoreCase).Trim();

        if (string.IsNullOrEmpty(userToken))
        {
            throw new ArgumentException("Invalid authorization header", nameof(authorizationHeader));
        }

        try
        {
            // Use the On-Behalf-Of flow to get a token for Cosmos DB
            var userAssertion = new UserAssertion(userToken);
            var result = await _confidentialClient
                .AcquireTokenOnBehalfOf(new[] { CosmosScope }, userAssertion)
                .ExecuteAsync();

            return result.AccessToken;
        }
        catch (MsalException ex)
        {
            throw new InvalidOperationException($"Failed to acquire OBO token: {ex.Message}", ex);
        }
    }
}
