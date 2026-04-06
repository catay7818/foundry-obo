#!/bin/bash
set -e

# Build and push the Foundry OBO Agent container image to Azure Container Registry

ACR_LOGIN_SERVER="${1:-acroboauwz6k237u2d6.azurecr.io}"
IMAGE_TAG="${2:-latest}"
IMAGE_NAME="foundry-obo-agent"
FULL_IMAGE="${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

ACR_NAME="${ACR_LOGIN_SERVER%%.*}"
DOCKERFILE_DIR="$(dirname "$0")/../../src/agent-with-local-tools"

echo "🔨 Building and pushing image via ACR Tasks: $FULL_IMAGE"
az acr build \
  --registry "$ACR_NAME" \
  --image "${IMAGE_NAME}:${IMAGE_TAG}" \
  --file "$DOCKERFILE_DIR/Dockerfile" \
  "$DOCKERFILE_DIR"

echo "✅ Successfully pushed $FULL_IMAGE"
