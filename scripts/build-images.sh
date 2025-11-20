#!/bin/bash

# Build script for all Docker images
# Usage: ./scripts/build-images.sh [tag]

set -e

TAG=${1:-latest}
REGISTRY=${REGISTRY:-""}
IMAGE_PREFIX=${IMAGE_PREFIX:-""}

SERVICES=("vote" "result" "worker" "seed-data")

echo "Building images with tag: $TAG"

for service in "${SERVICES[@]}"; do
    echo "Building $service..."
    
    IMAGE_NAME="$service"
    if [ -n "$REGISTRY" ] && [ -n "$IMAGE_PREFIX" ]; then
        IMAGE_NAME="$REGISTRY/$IMAGE_PREFIX/$service"
    fi
    
    docker build -t "$IMAGE_NAME:$TAG" "./$service"
    
    if [ -n "$REGISTRY" ] && [ -n "$IMAGE_PREFIX" ]; then
        echo "Pushing $IMAGE_NAME:$TAG..."
        docker push "$IMAGE_NAME:$TAG"
    fi
    
    echo "✓ Built $IMAGE_NAME:$TAG"
done

echo ""
echo "All images built successfully!"

