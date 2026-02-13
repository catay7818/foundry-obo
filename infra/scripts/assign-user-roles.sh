#!/bin/bash
# Script to assign Cosmos DB RBAC roles to specific users

set -e

# Configuration
RESOURCE_GROUP="${1:-}"
COSMOS_ACCOUNT_NAME="${2:-}"
DATABASE_NAME="DemoDatabase"

if [ -z "$RESOURCE_GROUP" ] || [ -z "$COSMOS_ACCOUNT_NAME" ]; then
    echo "Usage: $0 <resource-group> <cosmos-account-name>"
    echo "Example: $0 foundry-dev-rg foundry-dev-cosmos-abc123"
    exit 1
fi

echo "Configuring Cosmos DB RBAC for account: $COSMOS_ACCOUNT_NAME"

# Get Cosmos account resource ID
COSMOS_ACCOUNT_ID=$(az cosmosdb show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$COSMOS_ACCOUNT_NAME" \
    --query id -o tsv)

echo "Cosmos Account ID: $COSMOS_ACCOUNT_ID"

# Get custom role definition IDs
SALES_ROLE_ID=$(az cosmosdb sql role definition list \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?roleName=='Sales Container Reader'].id" -o tsv)

HR_ROLE_ID=$(az cosmosdb sql role definition list \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?roleName=='HR Container Reader'].id" -o tsv)

FINANCE_ROLE_ID=$(az cosmosdb sql role definition list \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?roleName=='Finance Container Reader'].id" -o tsv)

echo "Role IDs:"
echo "  Sales: $SALES_ROLE_ID"
echo "  HR: $HR_ROLE_ID"
echo "  Finance: $FINANCE_ROLE_ID"

# Prompt for user principal IDs
echo ""
echo "Enter user Object IDs (OIDs) from Entra ID:"
echo "You can find these in Azure Portal > Entra ID > Users > Select user > Object ID"
echo ""

read -p "User A OID (Sales access): " USER_A_OID
read -p "User B OID (HR access): " USER_B_OID
read -p "User C OID (Finance access): " USER_C_OID
read -p "Admin User OID (All access): " ADMIN_OID

# Assign roles
echo ""
echo "Assigning roles..."

# User A - Sales only
echo "Assigning Sales access to User A..."
az cosmosdb sql role assignment create \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --role-definition-id "$SALES_ROLE_ID" \
    --principal-id "$USER_A_OID" \
    --scope "${COSMOS_ACCOUNT_ID}/dbs/${DATABASE_NAME}/colls/Sales"

# User B - HR only
echo "Assigning HR access to User B..."
az cosmosdb sql role assignment create \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --role-definition-id "$HR_ROLE_ID" \
    --principal-id "$USER_B_OID" \
    --scope "${COSMOS_ACCOUNT_ID}/dbs/${DATABASE_NAME}/colls/HR"

# User C - Finance only
echo "Assigning Finance access to User C..."
az cosmosdb sql role assignment create \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --role-definition-id "$FINANCE_ROLE_ID" \
    --principal-id "$USER_C_OID" \
    --scope "${COSMOS_ACCOUNT_ID}/dbs/${DATABASE_NAME}/colls/Finance"

# Admin - All containers
echo "Assigning all access to Admin..."
az cosmosdb sql role assignment create \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --role-definition-id "$SALES_ROLE_ID" \
    --principal-id "$ADMIN_OID" \
    --scope "${COSMOS_ACCOUNT_ID}/dbs/${DATABASE_NAME}/colls/Sales"

az cosmosdb sql role assignment create \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --role-definition-id "$HR_ROLE_ID" \
    --principal-id "$ADMIN_OID" \
    --scope "${COSMOS_ACCOUNT_ID}/dbs/${DATABASE_NAME}/colls/HR"

az cosmosdb sql role assignment create \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --role-definition-id "$FINANCE_ROLE_ID" \
    --principal-id "$ADMIN_OID" \
    --scope "${COSMOS_ACCOUNT_ID}/dbs/${DATABASE_NAME}/colls/Finance"

echo ""
echo "✅ RBAC configuration complete!"
echo ""
echo "Update the Function App code with these user OIDs:"
echo "  User A (Sales): $USER_A_OID"
echo "  User B (HR): $USER_B_OID"
echo "  User C (Finance): $USER_C_OID"
echo "  Admin (All): $ADMIN_OID"
