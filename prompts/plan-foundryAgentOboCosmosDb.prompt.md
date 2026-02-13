# Plan: Foundry Agent with On-Behalf-Of Cosmos DB Access Demo

Build a demonstration repository showing how a Microsoft Foundry agent enforces container-level access control in Cosmos DB using On-Behalf-Of (OBO) authentication, where Azure Functions validate user identity before returning data.

## Steps

1. **Set up infrastructure with Bicep** — Create [infra/main.bicep](infra/main.bicep) deploying Cosmos DB (with multiple containers), Azure Function App with managed identity, and Entra ID app registrations configured for OBO token exchange
2. **Implement Azure Function with OBO flow** — Create [src/CosmosDataFunction/](src/CosmosDataFunction/) with token validation middleware, OBO token provider service, and `GetContainerData` function that exchanges user tokens and enforces Cosmos DB RBAC
3. **Configure Cosmos DB RBAC** — Define custom container-scoped roles in [infra/modules/rbac.bicep](infra/modules/rbac.bicep) and create setup scripts assigning test users to specific containers (e.g., User A → Sales only, User B → HR only)
4. **Seed sample data** — Create [data/sample-data/](data/sample-data/) with realistic JSON datasets for different containers and [data/scripts/seed-cosmos.sh](data/scripts/seed-cosmos.sh) to populate the database
5. **Register Function as Foundry tool** — Generate OpenAPI specification in [src/FoundryAgent/tools/cosmos-tool.openapi.json](src/FoundryAgent/tools/cosmos-tool.openapi.json) and create [src/FoundryAgent/agent-config.json](src/FoundryAgent/agent-config.json) with system prompt instructing the agent to query containers on user requests
6. **Create testing scenarios and documentation** — Build [tests/test-users.md](tests/test-users.md) with personas and expected outcomes, [docs/architecture.md](docs/architecture.md) with OBO flow diagrams, and [docs/setup-guide.md](docs/setup-guide.md) for end-to-end deployment

## Further Considerations

1. Sample data should contain simple unspecific data.
2. Do not include token caching for users. performance is not important here.
3. Include a manual testing guide, no need for automated tests
