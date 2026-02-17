import os
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import (
    ImageBasedHostedAgentDefinition,
    ProtocolVersionRecord,
    AgentProtocol,
)
from azure.identity import DefaultAzureCredential
from dotenv import load_dotenv

load_dotenv(override=True)

# Configure these for your Foundry project
# Read the explicit variables present in the .env file
AGENT_NAME = os.getenv("AGENT_NAME", "foundry-obo-hosted-agent")
PROJECT_ENDPOINT = os.getenv("PROJECT_ENDPOINT")
MODEL_DEPLOYMENT_NAME = os.getenv("MODEL_DEPLOYMENT_NAME", "gpt-4.1-mini")
AGENT_IMAGE = os.getenv("AGENT_IMAGE")
FUNCTION_APP_URL = os.getenv("FUNCTION_APP_URL")

# Initialize the client
client = AIProjectClient(
    endpoint=PROJECT_ENDPOINT,
    credential=DefaultAzureCredential(),
)

# Create the agent from a container image
agent = client.agents.create_version(
    agent_name=AGENT_NAME,
    definition=ImageBasedHostedAgentDefinition(
        container_protocol_versions=[
            ProtocolVersionRecord(protocol=AgentProtocol.RESPONSES, version="v1")
        ],
        cpu="1",
        memory="2Gi",
        image=AGENT_IMAGE,
        environment_variables={
            "PROJECT_ENDPOINT": PROJECT_ENDPOINT,
            "MODEL_DEPLOYMENT_NAME": MODEL_DEPLOYMENT_NAME,
            "FUNCTION_APP_URL": FUNCTION_APP_URL,
        },
    ),
)

# Print confirmation
print(f"Agent created: {agent.name} (id: {agent.id}, version: {agent.version})")
