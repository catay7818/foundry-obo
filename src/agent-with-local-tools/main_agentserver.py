import os
import asyncio
import datetime

import logging
from azure.ai.agentserver.core import FoundryCBAgent
from azure.ai.agentserver.core.models import (
    CreateResponse,
    Response as OpenAIResponse,
)
from azure.ai.agentserver.core.models.projects import (
    ItemContentOutputText,
    ResponsesAssistantMessageItemResource,
)
from azure.ai.agentserver.core.server.base import AgentRunContextMiddleware
from azure.ai.agentserver.core.server.common.agent_run_context import AgentRunContext
from starlette.responses import JSONResponse
from azure.identity.aio import DefaultAzureCredential

from agent_framework.azure import AzureAIAgentClient
from query_data import query_data_on_behalf_of_user, set_auth_header
from dotenv import load_dotenv

load_dotenv(override=True)


logger = logging.getLogger(__name__)

# Configure these for your Foundry project
# Read the explicit variables present in the .env file
PROJECT_ENDPOINT = os.getenv(
    "PROJECT_ENDPOINT"
)  # e.g., "https://<project>.services.ai.azure.com"
MODEL_DEPLOYMENT_NAME = os.getenv(
    "MODEL_DEPLOYMENT_NAME"
)  # Your model deployment name e.g., "gpt-4.1-mini"


class HttpRequestAgentRunContextMiddleware(AgentRunContextMiddleware):
    async def dispatch(self, request, call_next):
        if request.url.path in ("/runs", "/responses"):
            try:
                self.set_request_id_to_context_var(request)
                payload = await request.json()
            except Exception as e:
                logger.error(f"Invalid JSON payload: {e}")
                return JSONResponse(
                    {"error": f"Invalid JSON payload: {e}"}, status_code=400
                )
            try:
                payload["http_request"] = request
                request.state.agent_run_context = AgentRunContext(payload)
                self.set_run_context_to_context_var(request.state.agent_run_context)
            except Exception as e:
                logger.error(f"Context build failed: {e}.", exc_info=True)
                return JSONResponse(
                    {"error": f"Context build failed: {e}"}, status_code=500
                )
        return await call_next(request)


class OBOCustomAgent(FoundryCBAgent):
    def __init__(self, credentials=None, project_endpoint=None):
        super().__init__(credentials, project_endpoint)

        # Remove the default middleware
        # The middleware is added via: self.app.add_middleware(AgentRunContextMiddleware, agent=self)
        # We need to recreate the app with our custom middleware

        # Clear existing middlewares and re-add with custom one
        self.app.user_middleware = []
        self.app.add_middleware(HttpRequestAgentRunContextMiddleware, agent=self)


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
This allows Cosmos itself to authorize user data access at the container level.""",
            tools=[query_data_on_behalf_of_user],
        )

        async def agent_run(request_body: CreateResponse):
            http_request = request_body.raw_payload["http_request"]
            auth_header = http_request.headers.get("Authorization", None)
            if auth_header is None:
                raise Exception("Unauthorized, could not find Authorization header")

            # Set the global auth header for use in tools
            set_auth_header(auth_header)

            response = await agent.run(request_body.request["input"])

            # Build assistant output content
            output_content = [
                ItemContentOutputText(
                    text=response.text,
                    annotations=[],
                )
            ]

            response = OpenAIResponse(
                metadata={},
                temperature=0.0,
                top_p=0.0,
                user="me",
                id="id",
                created_at=datetime.datetime.now(),
                output=[
                    ResponsesAssistantMessageItemResource(
                        status="completed",
                        content=output_content,
                    )
                ],
            )
            return response

        agent_adapter = OBOCustomAgent()
        agent_adapter.agent_run = agent_run
        await agent_adapter.run_async()


if __name__ == "__main__":
    asyncio.run(main())
