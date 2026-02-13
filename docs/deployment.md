# Deployment Guide

Quick reference for deploying the Foundry OBO Cosmos DB demo.

## Prerequisites Checklist

- [ ] Azure subscription
- [ ] Azure CLI installed and logged in
- [ ] .NET 8.0 SDK installed
- [ ] Azure Functions Core Tools installed
- [ ] Git repository cloned

## Quick Deploy

### 1. Set Environment Variables

```bash
export PROJECT_NAME="foundry"
export ENVIRONMENT="dev"
export LOCATION="eastus"
export RESOURCE_GROUP="${PROJECT_NAME}-${ENVIRONMENT}-rg"
```

### 2. Create App Registrations

```bash
# Foundry app
az ad app create --display-name "Foundry Agent Demo"
export FOUNDRY_CLIENT_ID=$(az ad app list --display-name "Foundry Agent Demo" --query '[0].appId' -o tsv)

# Function app
az ad app create --display-name "Cosmos Data Function Demo"
export FUNCTION_CLIENT_ID=$(az ad app list --display-name "Cosmos Data Function Demo" --query '[0].appId' -o tsv)

echo "Foundry Client ID: $FOUNDRY_CLIENT_ID"
echo "Function Client ID: $FUNCTION_CLIENT_ID"
```

### 3. Deploy Infrastructure

```bash
# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Update parameters file with your client IDs
# Edit infra/main.bicepparam and replace placeholders

# Deploy
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam
```

### 4. Get Deployment Outputs

```bash
export COSMOS_ACCOUNT=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name main \
  --query properties.outputs.cosmosAccountName.value -o tsv)

export FUNCTION_APP=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name main \
  --query properties.outputs.functionAppName.value -o tsv)
```

### 5. Assign User Roles

```bash
chmod +x infra/scripts/assign-user-roles.sh
./infra/scripts/assign-user-roles.sh $RESOURCE_GROUP $COSMOS_ACCOUNT
```

### 6. Deploy Function

```bash
cd src/CosmosDataFunction
dotnet build --configuration Release
func azure functionapp publish $FUNCTION_APP
cd ../..
```

### 7. Seed Data

Upload sample data via Azure Portal Data Explorer:

- `data/sample-data/sales.json` → Sales container
- `data/sample-data/hr.json` → HR container
- `data/sample-data/finance.json` → Finance container

## Verification

```bash
# Check Function is running
az functionapp show \
  --resource-group $RESOURCE_GROUP \
  --name $FUNCTION_APP \
  --query state

# Check Cosmos DB
az cosmosdb show \
  --resource-group $RESOURCE_GROUP \
  --name $COSMOS_ACCOUNT \
  --query provisioningState
```

## Cleanup

```bash
az group delete --name $RESOURCE_GROUP --yes --no-wait
az ad app delete --id $FOUNDRY_CLIENT_ID
az ad app delete --id $FUNCTION_CLIENT_ID
```

## Troubleshooting

**Function deployment fails**: Ensure .NET 8.0 SDK is installed
**RBAC assignment fails**: Verify user Object IDs are correct
**Data upload fails**: Use Azure Portal Data Explorer instead of CLI

See [Setup Guide](setup-guide.md) for detailed instructions.
