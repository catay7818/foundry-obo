#!/bin/bash
set -e

# Build and push the Foundry OBO Agent container image to Azure Container Registry

ACR_LOGIN_SERVER="${1:-acroboauwz6k237u2d6.azurecr.io}"
IMAGE_NAME="foundry-obo-agent"

ACR_NAME="${ACR_LOGIN_SERVER%%.*}"
DOCKERFILE_DIR="$(dirname "$0")/../../src/agent-with-local-tools"

# Read version from version.txt
VERSION_FILE="$DOCKERFILE_DIR/version.txt"
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "❌ version.txt not found at $VERSION_FILE"
  exit 1
fi
IMAGE_TAG="$(tr -d '[:space:]' < "$VERSION_FILE")"

FULL_IMAGE="${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "🔨 Building and pushing image via ACR Tasks: $FULL_IMAGE"
az acr build \
  --registry "$ACR_NAME" \
  --image "${IMAGE_NAME}:${IMAGE_TAG}" \
  --image "${IMAGE_NAME}:latest" \
  --file "$DOCKERFILE_DIR/Dockerfile" \
  "$DOCKERFILE_DIR"

echo "✅ Successfully pushed $FULL_IMAGE and ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:latest"
