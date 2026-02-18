"""
Foundry OBO Agent - A simple agent intended to demonstrate accessing data on-behalf-of the current user.
Invokes a tool that performs OBO token exchange to access an Azure Function.
"""

import asyncio
import os
from dotenv import load_dotenv

load_dotenv(override=True)

from agent_framework.azure import AzureAIAgentClient
from azure.ai.agentserver.agentframework import from_agent_framework
from azure.identity.aio import DefaultAzureCredential

from tools import query_data_on_behalf_of_user

# Configure these for your Foundry project
# Read the explicit variables present in the .env file
PROJECT_ENDPOINT = os.getenv(
    "PROJECT_ENDPOINT"
)  # e.g., "https://<project>.services.ai.azure.com"
MODEL_DEPLOYMENT_NAME = os.getenv(
    "MODEL_DEPLOYMENT_NAME"
)  # Your model deployment name e.g., "gpt-4.1-mini"


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
