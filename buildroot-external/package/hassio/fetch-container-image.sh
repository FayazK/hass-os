#!/bin/bash
set -e

ARCH="$1"
MACHINE="$2"
VERSION_FILE="$3"
CONTAINER="$4"
CACHE_DIR="$5"
OUTPUT_DIR="$6"

echo "[CUSTOM BUILD] Fetching container: $CONTAINER for machine: $MACHINE"

# Ensure Docker is accessible
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker is not accessible"
    exit 1
fi

if [ "$CONTAINER" = "core" ]; then
    # === CUSTOM CORE HANDLING ===
    echo "[CUSTOM BUILD] Processing custom core image..."
    
    # Our custom image details
    CUSTOM_REPOSITORY="doc-reg.three60.app/homeassistant/core"
    CUSTOM_VERSION="2025.5.0-custom"
    CUSTOM_IMAGE="${CUSTOM_REPOSITORY}:${CUSTOM_VERSION}"
    
    # What supervisor expects (based on machine type)
    EXPECTED_REPOSITORY="ghcr.io/home-assistant/${MACHINE}-homeassistant"
    EXPECTED_VERSION="2025.6.1"  # Current stable version
    EXPECTED_IMAGE="${EXPECTED_REPOSITORY}:${EXPECTED_VERSION}"
    
    echo "[CUSTOM BUILD] Custom image: $CUSTOM_IMAGE"
    echo "[CUSTOM BUILD] Supervisor expects: $EXPECTED_IMAGE"
    
    CACHE_FILE="${CACHE_DIR}/core_${EXPECTED_VERSION}.tar"
    
    if [ ! -f "$CACHE_FILE" ]; then
        echo "[CUSTOM BUILD] Preparing custom core for supervisor..."
        
        # Login to custom registry
        echo "[CUSTOM BUILD] Logging into custom registry..."
        if ! docker login doc-reg.three60.app; then
            echo "Error: Failed to login to custom registry"
            exit 1
        fi
        
        # Pull our custom image
        echo "[CUSTOM BUILD] Pulling custom core: $CUSTOM_IMAGE"
        if ! docker pull "$CUSTOM_IMAGE"; then
            echo "Error: Failed to pull custom core"
            exit 1
        fi
        
        # Tag it with what supervisor expects
        echo "[CUSTOM BUILD] Tagging as supervisor-expected image: $EXPECTED_IMAGE"
        docker tag "$CUSTOM_IMAGE" "$EXPECTED_IMAGE"
        
        # Also tag with the standard pattern for landingpage
        LANDINGPAGE_IMAGE="${EXPECTED_REPOSITORY}:landingpage"
        docker tag "$CUSTOM_IMAGE" "$LANDINGPAGE_IMAGE"
        echo "[CUSTOM BUILD] Also tagged as: $LANDINGPAGE_IMAGE"
        
        # Save the supervisor-expected image
        echo "[CUSTOM BUILD] Saving supervisor-expected image to cache..."
        docker save "$EXPECTED_IMAGE" -o "$CACHE_FILE"
        
        # Create additional cache files for different scenarios
        docker save "$LANDINGPAGE_IMAGE" -o "${CACHE_DIR}/core_landingpage.tar"
        
        echo "[CUSTOM BUILD] Custom core prepared successfully!"
    else
        echo "[CUSTOM BUILD] Using cached supervisor-expected core image"
    fi
    
else
    # === STANDARD COMPONENT HANDLING ===
    REPOSITORY="ghcr.io/home-assistant/${ARCH}-hassio-${CONTAINER}"
    VERSION=$(jq -r ".$CONTAINER" "$VERSION_FILE")
    IMAGE="${REPOSITORY}:${VERSION}"
    CACHE_FILE="${CACHE_DIR}/${CONTAINER}_${VERSION}.tar"
    
    echo "[CUSTOM BUILD] Standard component: $IMAGE"
    
    if [ ! -f "$CACHE_FILE" ]; then
        echo "[CUSTOM BUILD] Downloading: $IMAGE"
        if ! docker pull "$IMAGE"; then
            echo "Error: Failed to pull $IMAGE"
            exit 1
        fi
        docker save "$IMAGE" -o "$CACHE_FILE"
    fi
fi

# Ensure directories exist
mkdir -p "$CACHE_DIR" "$OUTPUT_DIR"

# Copy to output directory
cp "$CACHE_FILE" "$OUTPUT_DIR/"

echo "[CUSTOM BUILD] Container $CONTAINER ready in output directory"
