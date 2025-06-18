#!/bin/bash
set -e

ARCH="$1"
MACHINE="$2"
VERSION_FILE="$3"
CONTAINER="$4"
CACHE_DIR="$5"
OUTPUT_DIR="$6"

echo "[CUSTOM BUILD] Fetching container: $CONTAINER"
echo "[CUSTOM BUILD] Architecture: $ARCH"
echo "[CUSTOM BUILD] Cache directory: $CACHE_DIR"
echo "[CUSTOM BUILD] Output directory: $OUTPUT_DIR"

# Ensure Docker is accessible
if ! docker info >/dev/null 2>&1; then
    echo "[ERROR] Docker is not accessible. Ensure Docker daemon is running."
    exit 1
fi

if [ "$CONTAINER" = "core" ]; then
    # Use custom core image from our registry
    REPOSITORY="doc-reg.three60.app/homeassistant/core"
    VERSION="2025.5.0-custom"
    echo "[CUSTOM BUILD] Using custom core image: $REPOSITORY:$VERSION"
    
    # Log the exact command we're running
    echo "[CUSTOM BUILD] Command: docker pull $REPOSITORY:$VERSION"
else
    # Use standard images for other components
    REPOSITORY="ghcr.io/home-assistant/${ARCH}-hassio-${CONTAINER}"
    VERSION=$(jq -r ".$CONTAINER" "$VERSION_FILE")
    echo "[CUSTOM BUILD] Using standard image: $REPOSITORY:$VERSION"
fi

IMAGE="${REPOSITORY}:${VERSION}"
CACHE_FILE="${CACHE_DIR}/${CONTAINER}_${VERSION}.tar"

echo "[CUSTOM BUILD] Target image: $IMAGE"
echo "[CUSTOM BUILD] Cache file: $CACHE_FILE"

# Ensure cache and output directories exist with proper permissions
mkdir -p "$CACHE_DIR" "$OUTPUT_DIR"
chmod 755 "$CACHE_DIR" "$OUTPUT_DIR"

# Check if image exists in cache
if [ ! -f "$CACHE_FILE" ]; then
    echo "[CUSTOM BUILD] Cache miss - downloading $IMAGE..."
    
    # For custom core, try without authentication first (if registry is public)
    if [ "$CONTAINER" = "core" ]; then
        echo "[CUSTOM BUILD] Attempting to pull custom core without authentication..."
        
        # Try to pull without login first
        if docker pull "$IMAGE" 2>&1 | tee /tmp/docker_pull.log; then
            echo "[CUSTOM BUILD] Successfully pulled without authentication"
        else
            echo "[CUSTOM BUILD] Pull without auth failed, trying with authentication..."
            
            # Show the error for debugging
            echo "[CUSTOM BUILD] Docker pull error:"
            cat /tmp/docker_pull.log
            
            # Try with authentication
            if docker login doc-reg.three60.app 2>&1; then
                echo "[CUSTOM BUILD] Authentication successful, retrying pull..."
                if ! docker pull "$IMAGE" 2>&1 | tee /tmp/docker_pull_auth.log; then
                    echo "[ERROR] Failed to pull custom core even with authentication"
                    echo "Docker error:"
                    cat /tmp/docker_pull_auth.log
                    exit 1
                fi
            else
                echo "[ERROR] Authentication failed and no-auth pull also failed"
                exit 1
            fi
        fi
    else
        # For standard images, pull normally
        echo "[CUSTOM BUILD] Pulling standard image..."
        if ! timeout 1800 docker pull "$IMAGE"; then
            echo "[ERROR] Failed to pull standard image: $IMAGE"
            exit 1
        fi
    fi
    
    # Save to cache
    echo "[CUSTOM BUILD] Saving to cache: $CACHE_FILE"
    if ! docker save "$IMAGE" -o "$CACHE_FILE"; then
        echo "[ERROR] Failed to save image to cache"
        exit 1
    fi
    
    # Set proper permissions
    chmod 644 "$CACHE_FILE"
    
    # Verify cache file was created and has reasonable size
    if [ -f "$CACHE_FILE" ]; then
        CACHE_SIZE=$(du -h "$CACHE_FILE" | cut -f1)
        echo "[CUSTOM BUILD] Cached $IMAGE to $CACHE_FILE (Size: $CACHE_SIZE)"
        
        # For core image, expect it to be large (>1GB)
        if [ "$CONTAINER" = "core" ]; then
            SIZE_BYTES=$(stat -f%z "$CACHE_FILE" 2>/dev/null || stat -c%s "$CACHE_FILE" 2>/dev/null || echo "0")
            if [ "$SIZE_BYTES" -lt 1000000000 ]; then  # Less than 1GB
                log_warning "Core image seems smaller than expected ($CACHE_SIZE)"
            else
                log_success "Core image cached successfully ($CACHE_SIZE)"
            fi
        fi
    else
        echo "[ERROR] Cache file was not created"
        exit 1
    fi
else
    echo "[CUSTOM BUILD] Cache hit - using cached image: $CACHE_FILE"
    CACHE_SIZE=$(du -h "$CACHE_FILE" | cut -f1)
    echo "[CUSTOM BUILD] Cache size: $CACHE_SIZE"
fi

# Copy to output directory
echo "[CUSTOM BUILD] Copying to output directory..."
if ! cp "$CACHE_FILE" "$OUTPUT_DIR/"; then
    echo "[ERROR] Failed to copy to output directory"
    exit 1
fi

echo "[CUSTOM BUILD] Container $CONTAINER ready in output directory"

# Final verification
OUTPUT_FILE="$OUTPUT_DIR/$(basename "$CACHE_FILE")"
if [ -f "$OUTPUT_FILE" ]; then
    OUTPUT_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo "[CUSTOM BUILD] Final verification: $OUTPUT_FILE ($OUTPUT_SIZE)"
else
    echo "[ERROR] Output file not found: $OUTPUT_FILE"
    exit 1
fi
