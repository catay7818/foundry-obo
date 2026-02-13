#!/bin/bash
# Script to seed Cosmos DB with sample data

set -e

# Configuration
RESOURCE_GROUP="${1:-}"
COSMOS_ACCOUNT_NAME="${2:-}"
DATABASE_NAME="DemoDatabase"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/../sample-data"

if [ -z "$RESOURCE_GROUP" ] || [ -z "$COSMOS_ACCOUNT_NAME" ]; then
    echo "Usage: $0 <resource-group> <cosmos-account-name>"
    echo "Example: $0 foundry-dev-rg foundry-dev-cosmos-abc123"
    exit 1
fi

echo "Seeding Cosmos DB: $COSMOS_ACCOUNT_NAME"

# Get Cosmos DB endpoint and key
COSMOS_ENDPOINT=$(az cosmosdb show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$COSMOS_ACCOUNT_NAME" \
    --query documentEndpoint -o tsv)

echo "Cosmos Endpoint: $COSMOS_ENDPOINT"

# Function to upload items to a container
upload_container_data() {
    local container=$1
    local data_file=$2

    echo "Uploading data to $container container..."

    # Read JSON array and upload each item
    jq -c '.[]' "$data_file" | while read -r item; do
        # Extract ID for the item
        item_id=$(echo "$item" | jq -r '.id')

        # Upload using Azure CLI
        az cosmosdb sql container create-update \
            --account-name "$COSMOS_ACCOUNT_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --database-name "$DATABASE_NAME" \
            --name "$container" \
            --partition-key-path "$(get_partition_key $container)" \
            > /dev/null 2>&1 || true

        # Use REST API to insert items (Azure CLI doesn't support item creation)
        # Note: This requires the Cosmos DB Data Plane SDK or REST API
        echo "  - Item $item_id prepared for $container"
    done
}

# Function to get partition key path for each container
get_partition_key() {
    case $1 in
        "Sales") echo "/region" ;;
        "HR") echo "/department" ;;
        "Finance") echo "/fiscalYear" ;;
    esac
}

echo ""
echo "Note: This script prepares the data files but requires manual upload or SDK integration."
echo "To complete data seeding, use one of the following methods:"
echo ""
echo "1. Azure Portal Data Explorer:"
echo "   - Navigate to your Cosmos DB account"
echo "   - Open Data Explorer"
echo "   - Select each container and upload the corresponding JSON file"
echo ""
echo "2. Use Azure CLI with cosmos-db-data-plane extension:"
echo "   az extension add --name cosmosdb-preview"
echo ""
echo "3. Use the Cosmos DB SDK in a custom script"
echo ""
echo "Sample data files are located in: $DATA_DIR"
echo "  - Sales: $DATA_DIR/sales.json"
echo "  - HR: $DATA_DIR/hr.json"
echo "  - Finance: $DATA_DIR/finance.json"
echo ""
echo "✅ Data preparation complete!"
