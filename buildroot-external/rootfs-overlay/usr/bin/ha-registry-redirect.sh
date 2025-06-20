#!/bin/bash
set -e

echo "Setting up Home Assistant registry redirection..."

# Create Docker registry mirror configuration
mkdir -p /etc/docker

# Configure Docker daemon to use our registry as primary for HA images
cat > /etc/docker/daemon.json << 'DAEMON_EOF'
{
  "registry-mirrors": [],
  "insecure-registries": ["doc-reg.three60.app"],
  "data-root": "/var/lib/docker",
  "storage-driver": "overlay2",
  "log-driver": "journald",
  "live-restore": true,
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
DAEMON_EOF

# Restart Docker to apply configuration
systemctl restart docker

# Wait for Docker to be ready
sleep 5

# Login to custom registry
docker login doc-reg.three60.app

# Pre-pull and tag our custom core image with the expected names
echo "Pre-loading custom core image..."

# The supervisor expects these exact image names
EXPECTED_CORE_IMAGE="ghcr.io/home-assistant/generic-x86-64-homeassistant"
CUSTOM_CORE_IMAGE="doc-reg.three60.app/homeassistant/core:2025.5.0-custom"

# Pull our custom image
docker pull "$CUSTOM_CORE_IMAGE"

# Tag it with all possible names the supervisor might request
docker tag "$CUSTOM_CORE_IMAGE" "$EXPECTED_CORE_IMAGE:latest"
docker tag "$CUSTOM_CORE_IMAGE" "$EXPECTED_CORE_IMAGE:landingpage"
docker tag "$CUSTOM_CORE_IMAGE" "$EXPECTED_CORE_IMAGE:2025.6.1"
docker tag "$CUSTOM_CORE_IMAGE" "$EXPECTED_CORE_IMAGE:2025.5.0"

echo "Custom core image pre-loaded and tagged"
echo "Available Home Assistant images:"
docker images | grep homeassistant

echo "Registry redirection setup complete"
