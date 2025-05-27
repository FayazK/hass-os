#!/bin/bash
set -e

arch=$1
machine=$2
version_json=$3
image_json_name=$4
dl_dir=$5
dst_dir=$6

echo "Fetching container: $CONTAINER"

if [ "$CONTAINER" = "core" ]; then
    # Use custom core image from our registry
    REPOSITORY="doc-reg.three60.app/homeassistant/core"
    VERSION="2025.5.0-custom"
    echo "Using custom core image: $REPOSITORY:$VERSION"
else
    # Use standard images for other components
    REPOSITORY="ghcr.io/home-assistant/${ARCH}-hassio-${CONTAINER}"
    VERSION=$(jq -r ".$CONTAINER" "$VERSION_FILE")
    echo "Using standard image: $REPOSITORY:$VERSION"
fi

IMAGE="${REPOSITORY}:${VERSION}"
CACHE_FILE="${CACHE_DIR}/${CONTAINER}_${VERSION}.tar"

echo "Target image: $IMAGE"
echo "Cache file: $CACHE_FILE"

# Check if image exists in cache
if [ ! -f "$CACHE_FILE" ]; then
    echo "Cache miss - downloading $IMAGE..."
    
    # Login to custom registry for core image
    if [ "$CONTAINER" = "core" ]; then
        echo "Logging into custom registry..."
        docker login doc-reg.three60.app
    fi
    
    # Pull the image
    docker pull "$IMAGE"
    
    # Save to cache
    docker save "$IMAGE" -o "$CACHE_FILE"
    
    echo "Cached $IMAGE to $CACHE_FILE"
else
    echo "Cache hit - using cached image: $CACHE_FILE"
fi

# Copy to output directory
cp "$CACHE_FILE" "$OUTPUT_DIR/"

echo "Container $CONTAINER ready in output directory"
