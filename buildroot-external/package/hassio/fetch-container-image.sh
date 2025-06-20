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
    # === CUSTOM CORE SUBSTITUTION ===
    echo "[CUSTOM BUILD] Substituting custom core image..."
    
    # Get the expected version from version file
    VERSION=$(jq -r ".$CONTAINER" "$VERSION_FILE")
    echo "[CUSTOM BUILD] Expected core version: $VERSION"
    
    # Our custom image details
    CUSTOM_REPOSITORY="doc-reg.three60.app/homeassistant/core"
    CUSTOM_VERSION="2025.5.0-custom"
    CUSTOM_IMAGE="${CUSTOM_REPOSITORY}:${CUSTOM_VERSION}"
    
    # What supervisor expects (this is the key!)
    EXPECTED_REPOSITORY="ghcr.io/home-assistant/${MACHINE}-homeassistant"
    EXPECTED_IMAGE="${EXPECTED_REPOSITORY}:${VERSION}"
    
    echo "[CUSTOM BUILD] Our custom image: $CUSTOM_IMAGE"
    echo "[CUSTOM BUILD] Will be presented as: $EXPECTED_IMAGE"
    
    # Use the version the supervisor expects for filename
    CACHE_FILE="${CACHE_DIR}/core_${VERSION}.tar"
    
    if [ ! -f "$CACHE_FILE" ]; then
        echo "[CUSTOM BUILD] Creating supervisor-compatible custom core..."
        
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
        
        # THIS IS THE KEY: Tag it with the exact name supervisor expects
        echo "[CUSTOM BUILD] Tagging custom image as: $EXPECTED_IMAGE"
        docker tag "$CUSTOM_IMAGE" "$EXPECTED_IMAGE"
        
        # Also create landingpage version (supervisor uses this during first boot)
        LANDINGPAGE_IMAGE="${EXPECTED_REPOSITORY}:landingpage"
        docker tag "$CUSTOM_IMAGE" "$LANDINGPAGE_IMAGE"
        echo "[CUSTOM BUILD] Also tagged as landingpage: $LANDINGPAGE_IMAGE"
        
        # Save the image with supervisor-expected name
        echo "[CUSTOM BUILD] Saving as expected image..."
        docker save "$EXPECTED_IMAGE" -o "$CACHE_FILE"
        
        # Also save landingpage version
        docker save "$LANDINGPAGE_IMAGE" -o "${CACHE_DIR}/core_landingpage.tar"
        
        echo "[CUSTOM BUILD] Custom core successfully prepared for supervisor!"
    else
        echo "[CUSTOM BUILD] Using cached custom core"
    fi
    
else
    # === STANDARD COMPONENTS ===
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
        echo "[CUSTOM BUILD] Saved: $CACHE_FILE"
    else
        echo "[CUSTOM BUILD] Using cached: $CACHE_FILE"
    fi
fi

# Ensure directories exist
mkdir -p "$CACHE_DIR" "$OUTPUT_DIR"

# Copy to output directory
cp "$CACHE_FILE" "$OUTPUT_DIR/"
echo "[CUSTOM BUILD] Container $CONTAINER ready: $(basename $CACHE_FILE)"
