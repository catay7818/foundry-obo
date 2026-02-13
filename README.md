# Foundry Agent with On-Behalf-Of Cosmos DB Access Demo

This repository demonstrates how a Microsoft Foundry agent enforces container-level access control in Cosmos DB using On-Behalf-Of (OBO) authentication. Azure Functions validate user identity before returning data from specific containers.

## Architecture

The demo showcases:
- **OBO Authentication Flow**: User tokens exchanged for service tokens to access Cosmos DB
- **Container-Level RBAC**: Users access only authorized containers (e.g., User A → Sales, User B → HR)
- **Foundry Agent Integration**: Agent queries Azure Functions on behalf of users with proper authorization

## Project Structure

```
├── infra/                      # Bicep infrastructure files
│   ├── main.bicep             # Main deployment template
│   └── modules/               # Modular Bicep files
├── src/
│   ├── CosmosDataFunction/    # Azure Function with OBO flow
│   └── FoundryAgent/          # Foundry agent configuration
├── data/
│   ├── sample-data/           # JSON datasets for containers
│   └── scripts/               # Database seeding scripts
├── docs/                       # Architecture and setup documentation
└── tests/                      # Testing scenarios and personas
```

## Getting Started

See [docs/setup-guide.md](docs/setup-guide.md) for complete deployment instructions.

## Key Features

- **Zero Trust Security**: Every request validates user identity
- **Fine-Grained Access**: Container-scoped RBAC policies
- **Seamless Integration**: Foundry agent acts as intelligent query interface

## Documentation

- [Architecture Overview](docs/architecture.md)
- [Setup Guide](docs/setup-guide.md)
- [Testing Scenarios](tests/test-users.md)
