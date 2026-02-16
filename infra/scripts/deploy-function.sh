#!/bin/bash
set -e

# Deploy Azure Function to Flex Consumption Plan
# This script handles deployment for Flex Consumption apps which don't support 'func azure functionapp publish'

FUNCTION_APP_NAME="${1:-}"
RESOURCE_GROUP="${2:-}"
BUILD_CONFIG="${3:-Release}"

if [ -z "$FUNCTION_APP_NAME" ]; then
  echo "Usage: $0 <function-app-name> <resource-group> [build-config]"
  echo "Example: $0 obo-func-65eelhoyd65xa my-resource-group Release"
  exit 1
fi

# Auto-detect resource group if not provided
if [ -z "$RESOURCE_GROUP" ]; then
  echo "🔍 Detecting resource group..."
  RESOURCE_GROUP=$(az functionapp list --query "[?name=='$FUNCTION_APP_NAME'].resourceGroup" -o tsv)
  if [ -z "$RESOURCE_GROUP" ]; then
    echo "❌ Error: Could not find function app '$FUNCTION_APP_NAME'"
    echo "Please provide the resource group name: $0 $FUNCTION_APP_NAME <resource-group>"
    exit 1
  fi
  echo "Found resource group: $RESOURCE_GROUP"
fi

echo "🔨 Building Function App..."
cd "$(dirname "$0")/../../src/CosmosDataFunction"

# Clean previous builds
rm -rf bin/publish
rm -f deploy.zip

# Build the function app
dotnet publish -c "$BUILD_CONFIG" -o bin/publish

# Create deployment package
echo "📦 Creating deployment package..."
cd bin/publish
zip -r ../../deploy.zip . -x "*.log" "local.settings.json"
cd ../..

# Deploy to Azure
echo "🚀 Deploying to Azure Function App: $FUNCTION_APP_NAME (Resource Group: $RESOURCE_GROUP)"
az functionapp deployment source config-zip \
  --resource-group "$RESOURCE_GROUP" \
  --name "$FUNCTION_APP_NAME" \
  --src deploy.zip

# Clean up
rm -f deploy.zip

echo "✅ Deployment complete!"
echo ""
echo "📝 To verify deployment:"
echo "   az functionapp list-functions --name $FUNCTION_APP_NAME"
echo ""
echo "📊 To view logs:"
echo "   az functionapp log tail --name $FUNCTION_APP_NAME"
