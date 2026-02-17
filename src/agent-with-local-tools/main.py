"""
Foundry OBO Agent - A simple agent intended to demonstrate accessing data on-behalf-of the current user.
Invokes a tool that performs OBO token exchange to access an Azure Function.
"""

import asyncio
import os
import httpx
from dotenv import load_dotenv

load_dotenv(override=True)

from agent_framework.azure import AzureAIAgentClient
from azure.ai.agentserver.agentframework import from_agent_framework
from azure.identity.aio import DefaultAzureCredential

# Configure these for your Foundry project
# Read the explicit variables present in the .env file
PROJECT_ENDPOINT = os.getenv(
    "PROJECT_ENDPOINT"
)  # e.g., "https://<project>.services.ai.azure.com"
MODEL_DEPLOYMENT_NAME = os.getenv(
    "MODEL_DEPLOYMENT_NAME"
)  # Your model deployment name e.g., "gpt-4.1-mini"

# Azure Function configuration
FUNCTION_APP_URL = os.getenv("FUNCTION_APP_URL")


async def query_data_on_behalf_of_user(
    container: str,
    query: str | None = None,
    context=None,  # Framework auto-injected request context
):
    """
    This tool queries data from a container (Finance, HR, or Sales) by invoking an Azure Function on behalf of the current user.

    Args:
        container: The name of the container to query (Finance, HR, or Sales)
        query: Optional SQL query to filter data. If not provided, returns all data.

    Returns:
        JSON data from the container or error message

    Note:
        The context parameter is automatically injected by the agent framework and is not exposed to the LLM.
    """
    # Validate container name
    valid_containers = ["Finance", "HR", "Sales"]
    if container not in valid_containers:
        return f"Error: Invalid container '{container}'. Must be one of: {', '.join(valid_containers)}"

    # Build the API endpoint
    api_url = f"{FUNCTION_APP_URL}/api/containers/query"

    # Prepare request payload
    payload = {"containerName": container, "query": query or "SELECT * FROM c"}

    # Prepare headers with authorization token extracted from request context
    headers = {"Content-Type": "application/json"}

    # Extract Authorization header from the request context
    if context:
        # Try different ways to access headers depending on context structure
        auth_header = None

        # Try accessing headers as attribute
        if hasattr(context, "headers") and context.headers:
            auth_header = context.headers.get("Authorization") or context.headers.get(
                "authorization"
            )
        # Try accessing headers as dict
        elif hasattr(context, "get"):
            headers_dict = context.get("headers", {})
            if headers_dict:
                auth_header = headers_dict.get("Authorization") or headers_dict.get(
                    "authorization"
                )

        # TODO: do the OBO flow
        # if auth_header:
        #     headers["Authorization"] = auth_header

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


async def main():
    """Main function to run the agent as a web server."""
    async with (
        DefaultAzureCredential() as credential,
        AzureAIAgentClient(
            project_endpoint=PROJECT_ENDPOINT,
            model_deployment_name=MODEL_DEPLOYMENT_NAME,
            credential=credential,
        ) as client,
    ):
        agent = client.create_agent(
            name="FoundryOBOAgent",
            instructions="""You are an assistant that demonstrates accessing data on behalf of the current user.
The user will ask questions about Finance, HR, and Sales data, but may or may not have access to those data sets.

The CosmosDataAPI tool should be used to retrieve data from the Finance, HR, or Sales containers.
This tool calls an Azure Function that implements the OAuth On-Behalf-Of flow.
This allows Cosmos itself to authorize user data access at the container level.

Include API calls and responses in output for debugging purposes.""",
            tools=[query_data_on_behalf_of_user],
        )

        print("Foundry OBO Agent Server running on http://localhost:8088")
        server = from_agent_framework(agent)
        await server.run_async()


if __name__ == "__main__":
    asyncio.run(main())
