using System.IdentityModel.Tokens.Jwt;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace CosmosDataFunction.Services;

public interface ITokenValidationService
{
    Task<string?> ValidateTokenAsync(string bearerToken);
}

public class TokenValidationService : ITokenValidationService
{
    private readonly string _tenantId;
    private readonly string _foundryClientId;

    public TokenValidationService()
    {
        _tenantId = Environment.GetEnvironmentVariable("TenantId")
            ?? throw new InvalidOperationException("TenantId not configured");
        _foundryClientId = Environment.GetEnvironmentVariable("FoundryClientId")
            ?? throw new InvalidOperationException("FoundryClientId not configured");
    }

    public async Task<string?> ValidateTokenAsync(string bearerToken)
    {
        try
        {
            // Remove "Bearer " prefix if present
            var token = bearerToken.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)
                ? bearerToken.Substring(7)
                : bearerToken;

            var handler = new JsonWebTokenHandler();
            var validationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuers = new[]
                {
                    $"https://login.microsoftonline.com/{_tenantId}/v2.0",
                    $"https://sts.windows.net/{_tenantId}/"
                },
                ValidateAudience = true,
                ValidAudience = _foundryClientId,
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
            if (!jwtToken.Audiences.Contains(_foundryClientId))
            {
                return null;
            }

            // Extract user ID (OID claim)
            var oid = jwtToken.Claims.FirstOrDefault(c => c.Type == "oid")?.Value;

            return oid;
        }
        catch
        {
            return null;
        }
    }
}
