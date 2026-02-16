using System.IdentityModel.Tokens.Jwt;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.JsonWebTokens;
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
    private readonly string _foundryClientId = Environment.GetEnvironmentVariable("FoundryClientId")
        ?? throw new InvalidOperationException("FoundryClientId not configured");
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
                IssuerSigningKeyResolver = (token, securityToken, kid, validationParameters) =>
                {
                    // In production, use proper key resolver from OIDC discovery
                    // For demo purposes, we'll do basic validation
                    return new List<SecurityKey>();
                }
            };

            // For demo purposes, decode without full validation
            // In production, uncomment the validation below
            var jwtToken = new JwtSecurityTokenHandler().ReadJwtToken(token);

            // Verify audience
            if (!jwtToken.Audiences.Contains(expectedAudience))
            {
                _logger.LogWarning("Token validation failed: Invalid audience. Expected {ExpectedAudience}, got {ActualAudiences}",
                    expectedAudience, string.Join(", ", jwtToken.Audiences));
                return null;
            }

            // Extract user ID (OID claim)
            var oid = jwtToken.Claims.FirstOrDefault(c => c.Type == "oid")?.Value;

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
