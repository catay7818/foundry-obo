# Plan

Create a plan for a repo that demonstrates a Microsoft Foundry agent that accesses data on behalf of the end-user. Use the new microsoft foundry experience.

Data is stored in Cosmos DB (include sample data). And users are granted access on different containers.

An Azure Function acts as the custom API that is exposed as a tool to the foundry agent.

When a user asks for data from a container they DO have access to, the agent SHOULD return data.
When a user asks for data from a container they DO NOT have access to, the agent SHOULD NOT return data.
