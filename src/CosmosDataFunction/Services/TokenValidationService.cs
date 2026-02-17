using System.IdentityModel.Tokens.Jwt;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;

namespace CosmosDataFunction.Services;

public interface ITokenValidationService
{
    Task<string?> ValidateTokenAsync(string bearerToken);
}

public class TokenValidationService(ILogger<TokenValidationService> logger) : ITokenValidationService
{
    private readonly ILogger<TokenValidationService> _logger = logger;
    private readonly string _tenantId = Environment.GetEnvironmentVariable("TenantId")
        ?? throw new InvalidOperationException("TenantId not configured");
    private readonly string _functionClientId = Environment.GetEnvironmentVariable("FunctionClientId")
        ?? throw new InvalidOperationException("FunctionClientId not configured");

    public async Task<string?> ValidateTokenAsync(string bearerToken)
    {
        try
        {
            _logger.LogDebug("Starting token validation");

            // Remove "Bearer " prefix if present
            var token = bearerToken.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)
                ? bearerToken.Substring(7)
                : bearerToken;

            var handler = new JsonWebTokenHandler();
            var expectedAudience = "api://" + _functionClientId;

            // Configure metadata endpoint for signing key retrieval
            var metadataEndpoint = $"https://login.microsoftonline.com/{_tenantId}/v2.0/.well-known/openid-configuration";
            var configManager = new ConfigurationManager<OpenIdConnectConfiguration>(
                metadataEndpoint,
                new OpenIdConnectConfigurationRetriever(),
                new HttpDocumentRetriever());

            var openIdConfig = await configManager.GetConfigurationAsync();

            var validationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuers = new[]
                {
                    $"https://login.microsoftonline.com/{_tenantId}/v2.0",
                    $"https://sts.windows.net/{_tenantId}/"
                },
                ValidateAudience = true,
                ValidAudience = expectedAudience,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                IssuerSigningKeys = openIdConfig.SigningKeys
            };

            // Perform actual token validation
            var result = await handler.ValidateTokenAsync(token, validationParameters);

            if (!result.IsValid)
            {
                _logger.LogWarning("Token validation failed: {Exception}", result.Exception?.Message);
                return null;
            }

            // Extract user ID (OID claim)
            var oid = result.ClaimsIdentity.FindFirst("oid")?.Value;

            if (string.IsNullOrEmpty(oid))
            {
                _logger.LogWarning("Token validation failed: OID claim not found in token");
                return null;
            }

            _logger.LogInformation("Token validated successfully for user {UserId}", oid);
            return oid;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error validating token: {ErrorMessage}", ex.Message);
            return null;
        }
    }
}
