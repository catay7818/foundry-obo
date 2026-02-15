namespace CosmosDataFunction.Services;

public interface IOboTokenProvider
{
    Task<string> GetOboTokenAsync(string userToken);
}

public class OboTokenProvider : IOboTokenProvider
{
    private readonly string _tenantId;
    private readonly string _functionClientId;
    private const string CosmosScope = "https://cosmos.azure.com/.default";

    public OboTokenProvider()
    {
        _tenantId = Environment.GetEnvironmentVariable("TenantId")
            ?? throw new InvalidOperationException("TenantId not configured");
        _functionClientId = Environment.GetEnvironmentVariable("FunctionClientId")
            ?? throw new InvalidOperationException("FunctionClientId not configured");
    }

    public async Task<string> GetOboTokenAsync(string userToken)
    {
        // For demo purposes using managed identity flow instead of OBO
        // In production, configure proper OBO with client secret/certificate

        var credential = new Azure.Identity.DefaultAzureCredential();
        var tokenRequestContext = new Azure.Core.TokenRequestContext(
            new[] { CosmosScope }
        );

        var accessToken = await credential.GetTokenAsync(tokenRequestContext);
        return accessToken.Token;
    }
}
