#!/bin/bash

LOG_FILE="/var/log/custom-core-resolver.log"

log() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

log "Starting custom core image resolver..."

# Wait for Docker
while ! docker info >/dev/null 2>&1; do
    log "Waiting for Docker..."
    sleep 2
done

# Define image mappings
CUSTOM_IMAGE="doc-reg.three60.app/homeassistant/core:2025.5.0-custom"
EXPECTED_IMAGES=(
    "ghcr.io/home-assistant/generic-x86-64-homeassistant:2025.6.1"
    "ghcr.io/home-assistant/generic-x86-64-homeassistant:landingpage"
    "ghcr.io/home-assistant/generic-x86-64-homeassistant:latest"
)

# Load custom image from preload if available
PRELOAD_DIR="/usr/share/hassio/docker/preload"
if [ -f "$PRELOAD_DIR/core_2025.5.0-custom.tar" ]; then
    log "Loading custom core from preload..."
    if docker load < "$PRELOAD_DIR/core_2025.5.0-custom.tar"; then
        log "Custom core loaded from preload"
    fi
fi

# Check if custom image is available
if docker inspect "$CUSTOM_IMAGE" >/dev/null 2>&1; then
    log "Custom core image found: $CUSTOM_IMAGE"
    
    # Tag it with all expected names
    for expected in "${EXPECTED_IMAGES[@]}"; do
        log "Tagging custom core as: $expected"
        docker tag "$CUSTOM_IMAGE" "$expected"
    done
    
    log "Custom core resolver completed successfully"
else
    log "ERROR: Custom core image not found: $CUSTOM_IMAGE"
    
    # Try to pull it
    if docker pull "$CUSTOM_IMAGE" 2>/dev/null; then
        log "Successfully pulled custom core"
        # Tag again
        for expected in "${EXPECTED_IMAGES[@]}"; do
            docker tag "$CUSTOM_IMAGE" "$expected"
        done
    else
        log "ERROR: Could not pull custom core either"
    fi
fi

log "Image resolver service completed"
