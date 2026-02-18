"""
On-Behalf-Of (OBO) token validation and acquisition for Azure services.

This module provides functionality to:
1. Validate bearer tokens from Azure AD
2. Acquire OBO tokens for downstream Azure resources using MSAL
"""

import os
import logging
from typing import Optional

import jwt
import requests
from msal import ConfidentialClientApplication

logger = logging.getLogger(__name__)

TENANT_ID = os.getenv("TENANT_ID")
CLIENT_ID = os.getenv("CLIENT_ID")
CLIENT_SECRET = os.getenv("CLIENT_SECRET")


class TokenValidationError(Exception):
    """Raised when token validation fails."""


class OboTokenError(Exception):
    """Raised when OBO token acquisition fails."""


def _get_openid_config(tenant_id: str) -> dict:
    """
    Retrieve OpenID Connect configuration from Azure AD.

    Args:
        tenant_id: Azure AD tenant ID.

    Returns:
        OpenID Connect configuration dictionary containing signing keys.

    Raises:
        TokenValidationError: If configuration cannot be retrieved.
    """
    metadata_url = f"https://login.microsoftonline.com/{tenant_id}/v2.0/.well-known/openid-configuration"
    print(f"[OBO] Fetching OpenID configuration from: {metadata_url}")
    try:
        response = requests.get(metadata_url, timeout=10)
        response.raise_for_status()
        config = response.json()

        # Fetch signing keys
        jwks_uri = config.get("jwks_uri")
        if not jwks_uri:
            raise TokenValidationError("JWKS URI not found in OpenID configuration")

        print(f"[OBO] Fetching signing keys from: {jwks_uri}")
        jwks_response = requests.get(jwks_uri, timeout=10)
        jwks_response.raise_for_status()
        config["signing_keys"] = jwks_response.json()

        print(f"[OBO] Successfully retrieved OpenID configuration and signing keys")
        return config
    except requests.RequestException as e:
        raise TokenValidationError(
            f"Failed to retrieve OpenID configuration: {e}"
        ) from e


def validate_token(bearer_token: str) -> Optional[str]:
    """
    Validate an Azure AD bearer token and extract the user's object ID.

    Args:
        bearer_token: The bearer token to validate (with or without "Bearer " prefix).

    Returns:
        The user's object ID (OID claim) if validation succeeds, None otherwise.

    Raises:
        TokenValidationError: If token validation encounters an error.

    Example:
        >>> oid = validate_token("Bearer eyJ0eXAiOiJKV1QiLCJhbGc...")
        >>> if oid:
        >>>     print(f"Token valid for user: {oid}")
    """
    try:
        print("[OBO] Starting token validation")
        logger.debug("Starting token validation")

        # Remove "Bearer " prefix if present
        token = (
            bearer_token.replace("Bearer ", "", 1).strip()
            if bearer_token.startswith("Bearer ")
            else bearer_token
        )

        if not token:
            print("[OBO] Empty token provided")
            logger.warning("Empty token provided")
            return None

        # Get OpenID configuration and signing keys
        print(f"[OBO] Retrieving OpenID configuration for tenant: {TENANT_ID}")
        openid_config = _get_openid_config(TENANT_ID)
        signing_keys = openid_config.get("signing_keys", {}).get("keys", [])
        print(f"[OBO] Found {len(signing_keys)} signing keys")

        # Decode token header to get the key ID (kid)
        unverified_header = jwt.get_unverified_header(token)
        kid = unverified_header.get("kid")
        print(f"[OBO] Token key ID (kid): {kid}")

        # Find the matching signing key
        signing_key = None
        for key in signing_keys:
            if key.get("kid") == kid:
                signing_key = jwt.algorithms.RSAAlgorithm.from_jwk(key)
                break

        if not signing_key:
            print(f"[OBO] Signing key not found for kid: {kid}")
            logger.warning("Signing key not found for token")
            return None

        print("[OBO] Signing key matched, validating token")
        # Define expected audience and issuers
        expected_audience = f"api://{CLIENT_ID}"
        valid_issuers = [
            f"https://login.microsoftonline.com/{TENANT_ID}/v2.0",
            f"https://sts.windows.net/{TENANT_ID}/",
        ]
        print(f"[OBO] Expected audience: {expected_audience}")

        # Validate the token
        decoded_token = jwt.decode(
            token,
            key=signing_key,
            algorithms=["RS256"],
            audience=expected_audience,
            issuer=valid_issuers,
            options={
                "verify_signature": True,
                "verify_exp": True,
                "verify_iat": True,
                "verify_aud": True,
                "verify_iss": True,
            },
        )

        # Extract user ID (OID claim)
        oid = decoded_token.get("oid")

        if not oid:
            print("[OBO] OID claim not found in token")
            logger.warning("OID claim not found in token")
            return None

        print(f"[OBO] Token validated successfully for user: {oid}")
        logger.info("Token validated successfully for user %s", oid)
        return oid

    except jwt.ExpiredSignatureError:
        print("[OBO] Token has expired")
        logger.warning("Token has expired")
        return None
    except jwt.InvalidTokenError as e:
        print(f"[OBO] Token validation failed: {str(e)}")
        logger.warning("Token validation failed: %s", str(e))
        return None
    except Exception as e:
        logger.error("Error validating token: %s", str(e))
        raise TokenValidationError(f"Token validation error: {e}") from e


def get_obo_token(user_token: str, scopes: list[str]) -> str:
    """
    Acquire an On-Behalf-Of token for a downstream Azure resource using the user's token.

    Args:
        user_token: The user's access token (with or without "Bearer " prefix).
        scopes: List of permission scopes for the downstream resource.

    Returns:
        Access token for the requested resource scope.

    Raises:
        OboTokenError: If OBO token acquisition fails.

    Example:
        >>> scopes = ["https://cosmos.azure.com/user_impersonation"]
        >>> resource_token = get_obo_token("Bearer eyJ0eXAiOiJKV1QiLCJhbGc...", scopes)
        >>> # Use resource_token to access the Azure resource
    """
    try:
        print(f"[OBO] Acquiring OBO token for scopes: {scopes}")

        # Remove "Bearer " prefix if present
        token = (
            user_token.replace("Bearer ", "", 1).strip()
            if user_token.startswith("Bearer ")
            else user_token
        )

        if not token:
            print("[OBO] Invalid user token: empty or whitespace")
            raise OboTokenError("Invalid user token: empty or whitespace")

        if not scopes:
            print("[OBO] No scopes provided")
            raise OboTokenError("Scopes are required")

        # Create confidential client application
        authority = f"https://login.microsoftonline.com/{TENANT_ID}"
        print(f"[OBO] Creating MSAL app with authority: {authority}")
        app = ConfidentialClientApplication(
            client_id=CLIENT_ID,
            client_credential=CLIENT_SECRET,
            authority=authority,
        )

        # Acquire token using On-Behalf-Of flow
        print("[OBO] Executing OBO token acquisition flow")
        result = app.acquire_token_on_behalf_of(user_assertion=token, scopes=scopes)

        if "access_token" not in result:
            error_description = result.get("error_description", "Unknown error")
            print(f"[OBO] Failed to acquire OBO token: {error_description}")
            raise OboTokenError(f"Failed to acquire OBO token: {error_description}")

        print("[OBO] Successfully acquired OBO token for requested scopes")
        logger.info("Successfully acquired OBO token for requested scopes")
        return result["access_token"]

    except Exception as e:
        if isinstance(e, OboTokenError):
            raise
        raise OboTokenError(f"Failed to acquire OBO token: {e}") from e


def validate_and_get_obo_token(
    authorization_header: str,
    scopes: list[str],
) -> tuple[Optional[str], Optional[str]]:
    """
    Validate bearer token and acquire OBO token for a downstream Azure resource.

    Args:
        authorization_header: The Authorization header value (e.g., "Bearer eyJ...").
        scopes: List of permission scopes for the downstream resource.

    Returns:
        Tuple of (user_oid, resource_token). Returns (None, None) if validation fails.

    Raises:
        TokenValidationError: If token validation encounters an error.
        OboTokenError: If OBO token acquisition fails.

    Example:
        >>> scopes = ["https://cosmos.azure.com/user_impersonation"]
        >>> user_oid, resource_token = validate_and_get_obo_token(
        ...     request.headers.get("Authorization"),
        ...     scopes
        ... )
        >>> if user_oid and resource_token:
        >>>     # Use resource_token to access Azure resource on behalf of user
        >>>     pass
    """
    print(f"[OBO] Starting validate_and_get_obo_token flow for scopes: {scopes}")
    # Validate the incoming token
    user_oid = validate_token(authorization_header)

    if not user_oid:
        print("[OBO] Token validation failed in validate_and_get_obo_token")
        logger.warning("Token validation failed")
        return None, None

    # Get OBO token for the requested resource
    try:
        resource_token = get_obo_token(authorization_header, scopes)
        print(
            f"[OBO] Successfully completed validate_and_get_obo_token for user: {user_oid}"
        )
        return user_oid, resource_token
    except OboTokenError as e:
        print(f"[OBO] Failed to get OBO token: {str(e)}")
        logger.error("Failed to get OBO token: %s", str(e))
        raise
