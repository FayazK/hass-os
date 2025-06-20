#!/bin/bash
# Script to properly tag custom core for Home Assistant OS integration

set -e

echo "=== Tagging Custom Core for Supervisor Integration ==="

# Custom core details
CUSTOM_IMAGE="doc-reg.three60.app/homeassistant/core:2025.5.0-custom"
TARGET_VERSION="2025.6.1"

# What supervisor expects
SUPERVISOR_IMAGE="ghcr.io/home-assistant/generic-x86-64-homeassistant:${TARGET_VERSION}"
LANDINGPAGE_IMAGE="ghcr.io/home-assistant/generic-x86-64-homeassistant:landingpage"

echo "Custom image: $CUSTOM_IMAGE"
echo "Target supervisor image: $SUPERVISOR_IMAGE"
echo "Target landingpage: $LANDINGPAGE_IMAGE"

# Login and pull custom image
echo ""
echo "Logging into custom registry..."
docker login doc-reg.three60.app

echo ""
echo "Pulling custom core..."
docker pull "$CUSTOM_IMAGE"

echo ""
echo "Tagging for supervisor compatibility..."
docker tag "$CUSTOM_IMAGE" "$SUPERVISOR_IMAGE"
docker tag "$CUSTOM_IMAGE" "$LANDINGPAGE_IMAGE"

echo ""
echo "Verification - available Home Assistant images:"
docker images | grep -E "(homeassistant|core)" || echo "No Home Assistant images found"

echo ""
echo "Custom core successfully tagged for supervisor!"
echo ""
echo "The supervisor will now find your custom core at:"
echo "  - $SUPERVISOR_IMAGE"
echo "  - $LANDINGPAGE_IMAGE"
