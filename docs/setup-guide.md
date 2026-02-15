# Setup Guide

This guide walks through the complete deployment process for the Foundry Agent with OBO Cosmos DB Access demo.

## Prerequisites

- **Azure Subscription**: Active subscription with permissions to create resources
- **Azure CLI**: Version 2.50.0 or later ([Install](https://docs.microsoft.com/cli/azure/install-azure-cli))
- **.NET SDK**: Version 8.0 or later ([Install](https://dotnet.microsoft.com/download))
- **Git**: For cloning the repository
- **PowerShell** or **Bash**: For running deployment scripts

## Step 1: Entra ID App Registrations

### 1.1 Create Foundry Agent App Registration

```bash
# Login to Azure
az login

# Create app registration for Foundry Agent
az ad app create \
  --display-name "Foundry Agent Demo" \
  --sign-in-audience AzureADMyOrg

# Save the Application (client) ID
FOUNDRY_CLIENT_ID=$(az ad app list --display-name "Foundry Agent Demo" --query '[0].appId' -o tsv)
echo "Foundry Client ID: $FOUNDRY_CLIENT_ID"
```

### 1.2 Create Azure Function App Registration

```bash
# Create app registration for Function App
az ad app create \
  --display-name "Cosmos Data Function Demo" \
  --sign-in-audience AzureADMyOrg

# Save the Application (client) ID
FUNCTION_CLIENT_ID=$(az ad app list --display-name "Cosmos Data Function Demo" --query '[0].appId' -o tsv)
echo "Function Client ID: $FUNCTION_CLIENT_ID"

# Expose API scope for OBO flow
az ad app update \
  --id $FUNCTION_CLIENT_ID \
  --identifier-uris "api://$FUNCTION_CLIENT_ID"
```

> TODO: also expose the 'user_impersonation' API on this app reg, do not require admin consent.
> This may need admin consent if OBO requires it?

### 1.3 Configure API Permissions

```bash
# Grant Foundry app permission to access Function app
# This enables OBO token exchange

# Get Function app's service principal object ID
FUNCTION_SP_OBJECT_ID=$(az ad sp list --filter "appId eq '$FUNCTION_CLIENT_ID'" --query '[0].id' -o tsv)

# Add API permission (requires manual admin consent in portal)
echo "Manual step required:"
echo "1. Go to Azure Portal > Entra ID > App registrations"
echo "2. Select 'Foundry Agent Demo'"
echo "3. Go to API permissions > Add a permission > My APIs"
echo "4. Select 'Cosmos Data Function Demo'"
echo "5. Add 'user_impersonation' permission"
echo "6. Grant admin consent"
```

## Step 2: Deploy Infrastructure

### 2.1 Set Variables

```bash
# Configuration
export LOCATION="westus"
export RESOURCE_GROUP="foundry-obo-rg"
```

### 2.2 Create Resource Group

```bash
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

### 2.3 Create Parameters File

Create `infra/main.bicepparam`:

```bicep
using 'main.bicep'

param projectName = 'obo'
param foundryClientId = '<FOUNDRY_CLIENT_ID>'
param functionClientId = '<FUNCTION_CLIENT_ID>'
```

Replace `<FOUNDRY_CLIENT_ID>` and `<FUNCTION_CLIENT_ID>` with values from Step 1.

### 2.4 Deploy Bicep Template

```bash
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam
```

### 2.5 Save Deployment Outputs

```bash
# Get deployment outputs
export COSMOS_ACCOUNT=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name main \
  --query properties.outputs.cosmosAccountName.value -o tsv)

export FUNCTION_APP=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name main \
  --query properties.outputs.functionAppName.value -o tsv)

echo "Cosmos DB Account: $COSMOS_ACCOUNT"
echo "Function App: $FUNCTION_APP"
```

## Step 3: Configure User Access

### 3.1 Identify Test Users

Get the Object ID for the user(s) you want to grant access:

1. Go to **Entra ID** > **Users**
2. Select a user
3. Copy their **Object ID**

### 3.2 Assign Cosmos DB Roles

Run the assignment script to grant a user access to a specific Cosmos DB container:

```bash
# Assign a specific role
./infra/scripts/assign-user-roles.sh \
  --resource-group $RESOURCE_GROUP \
  --cosmos-account $COSMOS_ACCOUNT \
  --user-oid <USER_OBJECT_ID> \
  --role sales   # sales, hr, finance, or all

# Or omit the `--role` flag for interactive role selection:
./infra/scripts/assign-user-roles.sh \
  -g $RESOURCE_GROUP \
  -c $COSMOS_ACCOUNT \
  -u <USER_OBJECT_ID>
```

Replace `<USER_OBJECT_ID>` with the actual Object ID from Step 3.1.

Available roles:

- `sales` - Access to Sales container only
- `hr` - Access to HR container only
- `finance` - Access to Finance container only
- `all` - Access to all containers

Repeat the command for each user you want to grant access.

### 3.3 Update Function Code

> TODO: should the function code really know about this?

Edit `src/CosmosDataFunction/Functions/GetContainerData.cs`:

```csharp
private readonly Dictionary<string, List<string>> _userContainerAccess = new()
{
    { "<USER_A_OBJECT_ID>", new List<string> { "Sales" } },
    { "<USER_B_OBJECT_ID>", new List<string> { "HR" } },
    { "<USER_C_OBJECT_ID>", new List<string> { "Finance" } },
    { "<ADMIN_OBJECT_ID>", new List<string> { "Sales", "HR", "Finance" } }
};
```

Replace placeholders with actual Object IDs from Step 3.1.

## Step 4: Deploy Azure Function

### 4.1 Build Function App

```bash
cd src/CosmosDataFunction

# Restore dependencies
dotnet restore

# Build project
dotnet build --configuration Release
```

### 4.2 Publish to Azure

```bash
# Publish function app
func azure functionapp publish $FUNCTION_APP
```

### 4.3 Verify Deployment

```bash
# Test health endpoint
FUNCTION_URL=$(az functionapp show \
  --resource-group $RESOURCE_GROUP \
  --name $FUNCTION_APP \
  --query defaultHostName -o tsv)

echo "Function URL: https://$FUNCTION_URL"
```

## Step 5: Seed Cosmos DB Data

### Option A: Azure Portal (Recommended for Demo)

1. Navigate to **Azure Portal** > **Cosmos DB Account**
2. Open **Data Explorer**
3. For each container:
   - Select container (Sales, HR, Finance)
   - Click **New Item**
   - Paste content from corresponding file in `data/sample-data/`
   - Repeat for each item in the JSON array

### Option B: Using Script (Preparation)

```bash
# Make script executable
chmod +x data/scripts/seed-cosmos.sh

# Run seed script (provides instructions)
./data/scripts/seed-cosmos.sh $RESOURCE_GROUP $COSMOS_ACCOUNT
```

## Step 6: Configure Foundry Agent

### 6.1 Update OpenAPI Specification

Edit `src/FoundryAgent/tools/cosmos-tool.openapi.json`:

Update the server URL with your Function App name:

```json
"servers": [
  {
    "url": "https://{functionAppName}.azurewebsites.net/api",
    "variables": {
      "functionAppName": {
        "default": "<YOUR_FUNCTION_APP_NAME>"
      }
    }
  }
]
```

### 6.2 Import Tool to Foundry

1. Navigate to **Microsoft Foundry** portal
2. Go to **Tools** > **Import Tool**
3. Upload `src/FoundryAgent/tools/cosmos-tool.openapi.json`
4. Configure authentication:
   - Type: OAuth 2.0
   - Client ID: `<FOUNDRY_CLIENT_ID>`
   - Scopes: `api://<FUNCTION_CLIENT_ID>/user_impersonation`

### 6.3 Create Agent

1. In Foundry, go to **Agents** > **Create Agent**
2. Upload `src/FoundryAgent/agent-config.json`
3. Link the imported Cosmos DB tool
4. Save and publish the agent

## Step 7: Test the Setup

### 7.1 Test as User A (Sales Access)

1. Sign in to Foundry as User A
2. Open the Cosmos Data Agent
3. Ask: "What data can I access?"
   - Expected: Shows "Sales" in allowed containers
4. Ask: "Show me sales data"
   - Expected: Returns sales records
5. Ask: "Show me HR data"
   - Expected: Access denied message

### 7.2 Test as User B (HR Access)

1. Sign in to Foundry as User B
2. Open the Cosmos Data Agent
3. Ask: "Show me HR records"
   - Expected: Returns HR records
4. Ask: "Show me sales data"
   - Expected: Access denied message

### 7.3 Test as Admin (All Access)

1. Sign in as Admin user
2. Test access to all containers:
   - "Show sales data" ✓
   - "Show HR data" ✓
   - "Show finance data" ✓

## Step 8: Verify Security

### 8.1 Check Application Insights Logs

```bash
# Query Application Insights for authorization events
az monitor app-insights query \
  --app $(az monitor app-insights component show \
    --resource-group $RESOURCE_GROUP \
    --query '[0].name' -o tsv) \
  --analytics-query "traces | where message contains 'authorized' | take 20"
```

### 8.2 Test Invalid Token

```bash
# Attempt request with invalid token
curl -X POST "https://$FUNCTION_URL/api/containers/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer invalid_token" \
  -d '{"containerName":"Sales"}'

# Expected: 401 Unauthorized
```

## Troubleshooting

### Issue: Function returns 401 Unauthorized

**Cause**: Token validation failed

**Solutions**:

1. Verify token is valid and not expired
2. Check `FoundryClientId` in Function App settings
3. Ensure token audience matches Foundry app registration

### Issue: Function returns 403 Forbidden

**Cause**: User lacks access to requested container

**Solutions**:

1. Verify user OID in Function code matches test user
2. Check Cosmos DB role assignments with `az cosmosdb sql role assignment list`
3. Ensure container name is spelled correctly

### Issue: Cosmos DB query fails

**Cause**: Function managed identity lacks Cosmos DB permissions

**Solutions**:

1. Verify role assignment: `az cosmosdb sql role assignment list --account-name $COSMOS_ACCOUNT`
2. Ensure Function App has system-assigned managed identity enabled
3. Check Cosmos DB endpoint is correct in Function App settings

### Issue: Foundry agent can't call Function

**Cause**: API permissions not granted

**Solutions**:

1. Verify API permissions in Foundry app registration
2. Ensure admin consent was granted
3. Check OpenAPI spec URL matches deployed Function App

## Cleanup

To remove all resources:

```bash
# Delete resource group (removes all resources)
az resource group delete \
  --name $RESOURCE_GROUP \
  --yes --no-wait

# Delete app registrations
az ad app delete --id $FOUNDRY_CLIENT_ID
az ad app delete --id $FUNCTION_CLIENT_ID
```

## Next Steps

- Review [Architecture Documentation](architecture.md) for design details
- See [Testing Scenarios](../tests/test-users.md) for comprehensive test cases
- Explore advanced scenarios like query filtering and aggregation
- Implement production-ready features (token caching, rate limiting)

## Support

For issues or questions:

- Check [Architecture Documentation](architecture.md)
- Review Application Insights logs for detailed error messages
- Ensure all prerequisites are met and versions are compatible
