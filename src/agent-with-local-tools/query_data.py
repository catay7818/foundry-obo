"""
Tools for the Foundry OBO Agent.
"""

import os
import httpx

from obo import validate_and_get_obo_token

# Azure Function configuration
FUNCTION_APP_URL = os.getenv("FUNCTION_APP_URL")
OBO_SCOPE = os.getenv("OBO_SCOPE")
# Global auth header for default authorization
_global_auth_header: str | None = None


def set_auth_header(auth_header: str) -> None:
    """Set the global authorization header to use as default.

    Args:
        auth_header: The Authorization header value (e.g., 'Bearer <token>')
    """
    global _global_auth_header
    _global_auth_header = auth_header


async def query_data_on_behalf_of_user(
    container: str,
    query: str | None = None,
    bearer_token: str = None,
):
    """
    This tool queries data from a container (Finance, HR, or Sales) by invoking an Azure Function on behalf of the current user.

    Args:
        container: The name of the container to query (Finance, HR, or Sales)
        query: Optional SQL query to filter data. If not provided, returns all data.
        bearer_token: (Optional) The bearer token to use to retrieve an OBO token for the user.

    Returns:
        JSON data from the container or error message
    """
    print(f"[QUERY] Starting query_data_on_behalf_of_user for container: {container}")
    if query:
        print(f"[QUERY] Custom query provided: {query}")
    else:
        print("[QUERY] No custom query, will use: SELECT * FROM c")

    # Validate container name
    valid_containers = ["Finance", "HR", "Sales"]
    if container not in valid_containers:
        print(f"[QUERY] Invalid container name: {container}")
        return f"Error: Invalid container '{container}'. Must be one of: {', '.join(valid_containers)}"

    print(f"[QUERY] Container '{container}' validated successfully")

    # Use global auth header if no bearer_token provided
    if bearer_token is None:
        bearer_token = _global_auth_header
        print("[QUERY] Using global auth header as bearer_token")

    if bearer_token is None:
        print("[QUERY] Error: No bearer token available")
        return {"success": False, "error": "No authentication token provided"}

    print(f"[QUERY] Acquiring OBO token with scope: {OBO_SCOPE}")
    oid, resource_token = validate_and_get_obo_token(bearer_token, scopes=[OBO_SCOPE])
    print(f"[QUERY] OBO token acquired for user: {oid}")

    # Build the API endpoint
    api_url = f"{FUNCTION_APP_URL}/api/containers/query"
    print(f"[QUERY] API endpoint: {api_url}")

    # Prepare request payload
    payload = {"containerName": container, "query": query or "SELECT * FROM c"}
    print(f"[QUERY] Request payload: {payload}")

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {resource_token}",
    }

    try:
        print(f"[QUERY] Sending POST request to Azure Function...")
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(api_url, json=payload, headers=headers)
            print(f"[QUERY] Response received with status code: {response.status_code}")

            # Check if request was successful
            if response.status_code == 200:
                result = response.json()
                if result.get("Success"):
                    item_count = result.get("ItemCount", 0)
                    print(
                        f"[QUERY] Success! Retrieved {item_count} items from {container}"
                    )
                    return {
                        "success": True,
                        "container": container,
                        "itemCount": item_count,
                        "data": result.get("Data", []),
                    }
                else:
                    error_msg = result.get("errorMessage", "Unknown error")
                    print(f"[QUERY] Query failed: {error_msg}")
                    return {
                        "success": False,
                        "error": error_msg,
                    }
            elif response.status_code == 401:
                print("[QUERY] Error 401: Unauthorized")
                return {
                    "success": False,
                    "error": "Unauthorized: Invalid or missing authentication token",
                }
            elif response.status_code == 403:
                print(f"[QUERY] Error 403: Forbidden access to {container}")
                return {
                    "success": False,
                    "error": f"Forbidden: You do not have access to the {container} container",
                }
            elif response.status_code == 404:
                print(f"[QUERY] Error 404: Container '{container}' not found")
                return {
                    "success": False,
                    "error": f"Not found: Container '{container}' does not exist",
                }
            else:
                print(f"[QUERY] HTTP Error {response.status_code}: {response.text}")
                return {
                    "success": False,
                    "error": f"HTTP {response.status_code}: {response.text}",
                }

    except httpx.TimeoutException:
        print("[QUERY] Request timeout: Azure Function did not respond in time")
        return {
            "success": False,
            "error": "Request timeout: Azure Function did not respond in time",
        }
    except httpx.ConnectError:
        print(f"[QUERY] Connection error: Could not connect to {api_url}")
        return {
            "success": False,
            "error": f"Connection error: Could not connect to Azure Function at {api_url}. Make sure the function app is running.",
        }
    except Exception as e:
        print(f"[QUERY] Unexpected error: {str(e)}")
        return {"success": False, "error": f"Unexpected error: {str(e)}"}
