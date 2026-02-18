"""
Tools for the Foundry OBO Agent.
"""

import os
import httpx

# Azure Function configuration
FUNCTION_APP_URL = os.getenv("FUNCTION_APP_URL")


async def query_data_on_behalf_of_user(
    container: str,
    query: str | None = None,
):
    """
    This tool queries data from a container (Finance, HR, or Sales) by invoking an Azure Function on behalf of the current user.

    Args:
        container: The name of the container to query (Finance, HR, or Sales)
        query: Optional SQL query to filter data. If not provided, returns all data.

    Returns:
        JSON data from the container or error message
    """
    # Validate container name
    valid_containers = ["Finance", "HR", "Sales"]
    if container not in valid_containers:
        return f"Error: Invalid container '{container}'. Must be one of: {', '.join(valid_containers)}"

    # Build the API endpoint
    api_url = f"{FUNCTION_APP_URL}/api/containers/query"

    # Prepare request payload
    payload = {"containerName": container, "query": query or "SELECT * FROM c"}

    headers = {"Content-Type": "application/json"}

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(api_url, json=payload, headers=headers)

            # Check if request was successful
            if response.status_code == 200:
                result = response.json()
                if result.get("success"):
                    return {
                        "success": True,
                        "container": container,
                        "itemCount": result.get("itemCount", 0),
                        "data": result.get("data", []),
                    }
                else:
                    return {
                        "success": False,
                        "error": result.get("errorMessage", "Unknown error"),
                    }
            elif response.status_code == 401:
                return {
                    "success": False,
                    "error": "Unauthorized: Invalid or missing authentication token",
                }
            elif response.status_code == 403:
                return {
                    "success": False,
                    "error": f"Forbidden: You do not have access to the {container} container",
                }
            elif response.status_code == 404:
                return {
                    "success": False,
                    "error": f"Not found: Container '{container}' does not exist",
                }
            else:
                return {
                    "success": False,
                    "error": f"HTTP {response.status_code}: {response.text}",
                }

    except httpx.TimeoutException:
        return {
            "success": False,
            "error": "Request timeout: Azure Function did not respond in time",
        }
    except httpx.ConnectError:
        return {
            "success": False,
            "error": f"Connection error: Could not connect to Azure Function at {api_url}. Make sure the function app is running.",
        }
    except Exception as e:
        return {"success": False, "error": f"Unexpected error: {str(e)}"}
