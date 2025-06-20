#!/bin/bash
# Custom image loader for Home Assistant Core

CUSTOM_CORE_TAR="/mnt/data/supervisor/custom_core.tar"
EXPECTED_IMAGE="ghcr.io/home-assistant/generic-x86-64-homeassistant"

# Check if custom core tar exists
if [ -f "$CUSTOM_CORE_TAR" ]; then
    echo "Loading custom Home Assistant Core image..."
    
    # Load the custom image
    docker load -i "$CUSTOM_CORE_TAR"
    
    # Get the actual image name from the loaded image
    LOADED_IMAGE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "doc-reg.three60.app/homeassistant/core" | head -1)
    
    if [ -n "$LOADED_IMAGE" ]; then
        echo "Tagging custom image as expected image: $EXPECTED_IMAGE"
        
        # Tag with all possible versions the supervisor might request
        docker tag "$LOADED_IMAGE" "$EXPECTED_IMAGE:latest"
        docker tag "$LOADED_IMAGE" "$EXPECTED_IMAGE:landingpage"
        docker tag "$LOADED_IMAGE" "$EXPECTED_IMAGE:2025.6.1"
        docker tag "$LOADED_IMAGE" "$EXPECTED_IMAGE:2025.5.0"
        
        echo "Custom core image tagged successfully"
    fi
fi
