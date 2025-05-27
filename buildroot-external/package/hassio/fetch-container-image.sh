#!/bin/bash
set -e

# Debug: Show all arguments received
echo "[DEBUG] fetch-container-image.sh called with $# arguments:"
for i in $(seq 1 $#); do
    echo "[DEBUG] Arg $i: ${!i}"
done

# Parse arguments with validation
ARCH="$1"
MACHINE="$2"
VERSION_FILE="$3"
CONTAINER="$4"
CACHE_DIR="$5"
OUTPUT_DIR="$6"

# Validate all required arguments are provided
if [ -z "$ARCH" ] || [ -z "$MACHINE" ] || [ -z "$VERSION_FILE" ] || [ -z "$CONTAINER" ] || [ -z "$CACHE_DIR" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Error: Missing required arguments"
    echo "Usage: $0 ARCH MACHINE VERSION_FILE CONTAINER CACHE_DIR OUTPUT_DIR"
    echo "Received: ARCH='$ARCH' MACHINE='$MACHINE' VERSION_FILE='$VERSION_FILE' CONTAINER='$CONTAINER' CACHE_DIR='$CACHE_DIR' OUTPUT_DIR='$OUTPUT_DIR'"
    exit 1
fi

# Validate version file exists
if [ ! -f "$VERSION_FILE" ]; then
    echo "Error: Version file does not exist: $VERSION_FILE"
    ls -la "$(dirname "$VERSION_FILE")" || echo "Directory does not exist"
    exit 1
fi

# Ubuntu-specific logging
echo "[Ubuntu Build] Fetching container: $CONTAINER"
echo "[Ubuntu Build] Architecture: $ARCH"
echo "[Ubuntu Build] Machine: $MACHINE"
echo "[Ubuntu Build] Version file: $VERSION_FILE"
echo "[Ubuntu Build] Cache directory: $CACHE_DIR"
echo "[Ubuntu Build] Output directory: $OUTPUT_DIR"

# Ensure Docker is accessible
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker is not accessible. Ensure Docker daemon is running and user has permissions."
    exit 1
fi

# Ensure jq is available
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is not installed. Please install jq: sudo apt install jq"
    exit 1
fi

# Debug: Show version file contents
echo "[DEBUG] Version file contents:"
cat "$VERSION_FILE"

if [ "$CONTAINER" = "core" ]; then
    # Use custom core image from our registry
    REPOSITORY="doc-reg.three60.app/homeassistant/core"
    VERSION="2025.5.0-custom"
    echo "[Ubuntu Build] Using custom core image: $REPOSITORY:$VERSION"
else
    # Use standard images for other components
    REPOSITORY="ghcr.io/home-assistant/${ARCH}-hassio-${CONTAINER}"
    
    # Extract version using jq with proper error handling
    VERSION=$(jq -r ".$CONTAINER" "$VERSION_FILE" 2>/dev/null)
    if [ $? -ne 0 ] || [ "$VERSION" = "null" ] || [ -z "$VERSION" ]; then
        echo "Error: Could not extract version for $CONTAINER from $VERSION_FILE"
        echo "Available keys in version file:"
        jq -r 'keys[]' "$VERSION_FILE" 2>/dev/null || echo "Failed to parse JSON"
        exit 1
    fi
    echo "[Ubuntu Build] Using standard image: $REPOSITORY:$VERSION"
fi

IMAGE="${REPOSITORY}:${VERSION}"
CACHE_FILE="${CACHE_DIR}/${CONTAINER}_${VERSION}.tar"

echo "[Ubuntu Build] Target image: $IMAGE"
echo "[Ubuntu Build] Cache file: $CACHE_FILE"

# Ensure cache directory exists with proper permissions
mkdir -p "$CACHE_DIR"
chmod 755 "$CACHE_DIR"

# Check if image exists in cache
if [ ! -f "$CACHE_FILE" ]; then
    echo "[Ubuntu Build] Cache miss - downloading $IMAGE..."
    
    # Login to custom registry for core image
    if [ "$CONTAINER" = "core" ]; then
        echo "[Ubuntu Build] Logging into custom registry..."
        if ! docker login doc-reg.three60.app; then
            echo "Error: Failed to login to custom registry"
            exit 1
        fi
    fi
    
    # Pull the image with timeout
    echo "[Ubuntu Build] Pulling image (this may take several minutes)..."
    if ! timeout 1800 docker pull "$IMAGE"; then
        echo "Error: Docker pull timed out or failed for image: $IMAGE"
        
        # For standard images, try alternative approach
        if [ "$CONTAINER" != "core" ]; then
            echo "Attempting to find alternative image..."
            # List available tags if possible
            echo "Trying to pull without specific version..."
            docker pull "${REPOSITORY}:latest" || true
        fi
        exit 1
    fi
    
    # Save to cache
    echo "[Ubuntu Build] Saving to cache..."
    docker save "$IMAGE" -o "$CACHE_FILE"
    
    # Set proper permissions
    chmod 644 "$CACHE_FILE"
    
    echo "[Ubuntu Build] Cached $IMAGE to $CACHE_FILE"
else
    echo "[Ubuntu Build] Cache hit - using cached image: $CACHE_FILE"
fi

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Copy to output directory
cp "$CACHE_FILE" "$OUTPUT_DIR/"

echo "[Ubuntu Build] Container $CONTAINER ready in output directory"
echo "[Ubuntu Build] Output file: $OUTPUT_DIR/$(basename "$CACHE_FILE")"
