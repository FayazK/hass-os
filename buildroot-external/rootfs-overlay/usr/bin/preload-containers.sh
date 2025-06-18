#!/bin/bash

PRELOAD_DIR="/usr/share/hassio/docker/preload"
LOG_FILE="/var/log/container-preload.log"

log() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

log "Starting container preload service..."

# Wait for Docker to be ready
attempts=0
while ! docker info >/dev/null 2>&1 && [ $attempts -lt 30 ]; do
    log "Waiting for Docker to be ready... (attempt $((attempts+1)))"
    sleep 2
    attempts=$((attempts+1))
done

if ! docker info >/dev/null 2>&1; then
    log "ERROR: Docker failed to start within timeout"
    exit 1
fi

log "Docker is ready"

# Check if preload directory exists
if [ ! -d "$PRELOAD_DIR" ]; then
    log "ERROR: Preload directory not found: $PRELOAD_DIR"
    exit 1
fi

log "Found preload directory: $PRELOAD_DIR"

# Load each container
loaded_count=0
failed_count=0

for tar_file in "$PRELOAD_DIR"/*.tar; do
    if [ -f "$tar_file" ]; then
        container_name=$(basename "$tar_file" .tar)
        log "Loading container: $container_name"
        
        if docker load < "$tar_file" >/dev/null 2>&1; then
            log "✅ Successfully loaded: $container_name"
            loaded_count=$((loaded_count+1))
        else
            log "❌ Failed to load: $container_name"
            failed_count=$((failed_count+1))
        fi
    fi
done

log "Container preload completed: $loaded_count loaded, $failed_count failed"

# Verify custom core is available
CUSTOM_CORE="doc-reg.three60.app/homeassistant/core:2025.5.0-custom"
if docker inspect "$CUSTOM_CORE" >/dev/null 2>&1; then
    log "✅ Custom core verified: $CUSTOM_CORE"
else
    log "❌ Custom core NOT found: $CUSTOM_CORE"
    log "Available images:"
    docker images | grep -E "(core|homeassistant)" >> "$LOG_FILE"
fi

log "Preload service completed"
