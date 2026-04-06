#!/bin/bash
set -e

# Deploy the UI to Azure Static Web Apps
# Builds the Vite app and pushes content via the SWA deployment token

STATIC_WEB_APP_NAME="${1:-obo-swa-auwz6k237u2d6}"
RESOURCE_GROUP="${2:-foundry-obo-rg}"

# Auto-detect resource group if not provided
if [ -z "$RESOURCE_GROUP" ]; then
  echo "🔍 Detecting resource group..."
  RESOURCE_GROUP=$(az staticwebapp list --query "[?name=='$STATIC_WEB_APP_NAME'].resourceGroup" -o tsv)
  if [ -z "$RESOURCE_GROUP" ]; then
    echo "❌ Error: Could not find static web app '$STATIC_WEB_APP_NAME'"
    echo "Please provide the resource group name: $0 $STATIC_WEB_APP_NAME <resource-group>"
    exit 1
  fi
  echo "Found resource group: $RESOURCE_GROUP"
fi

# Resolve the agent URL from Azure (the SWA app setting set by Bicep)
echo "🔍 Resolving agent URL..."
AGENT_SERVER_URL=$(az staticwebapp appsettings list \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.VITE_AGENT_SERVER_URL" -o tsv)

if [ -z "$AGENT_SERVER_URL" ]; then
  echo "⚠️  Warning: AGENT_SERVER_URL app setting not found. Using fallback localhost."
  AGENT_SERVER_URL="http://localhost:8088"
fi

echo "Agent URL: $AGENT_SERVER_URL"

# Retrieve deployment token
echo "🔑 Retrieving deployment token..."
DEPLOYMENT_TOKEN=$(az staticwebapp secrets list \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.apiKey" -o tsv)

# Build the UI
UI_DIR="$(dirname "$0")/../../ui"
echo "🔨 Building UI..."
cd "$UI_DIR"
npm install --silent
VITE_AGENT_SERVER_URL="$AGENT_SERVER_URL" npm run build

# Deploy via SWA CLI
echo "🚀 Deploying to Static Web App: $STATIC_WEB_APP_NAME"
npx --yes @azure/static-web-apps-cli deploy ./dist \
  --deployment-token "$DEPLOYMENT_TOKEN" \
  --env production

echo "✅ UI deployment complete!"
echo ""
echo "🌐 Static Web App URL:"
az staticwebapp show \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "defaultHostname" -o tsv | xargs -I{} echo "   https://{}"
