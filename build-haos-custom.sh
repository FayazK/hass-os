#!/bin/bash
set -e

BOARD="${1:-generic-x86-64}"
BUILD_TYPE="${2:-release}"

echo "Building Home Assistant OS for $BOARD (Build type: $BUILD_TYPE)"

# Ensure we're in the OS directory
cd "$(dirname "$0")"

# Create build directory if it doesn't exist
mkdir -p output

# Use Docker for consistent build environment
docker run --rm --privileged \
  -v "$(pwd):/build" \
  -v "/var/run/docker.sock:/var/run/docker.sock" \
  -v "$HOME/.docker:/root/.docker:ro" \
  homeassistant/amd64-builder:2024.03.0 \
  bash -c "
    cd /build
    echo 'Configuring build for $BOARD...'
    make ${BOARD}_defconfig

    echo 'Starting build process...'
    make -j\$(nproc) V=1

    echo 'Build completed successfully!'
    ls -la output/images/
  "

echo "Build completed for $BOARD"
echo "Images available in: $(pwd)/output/images/"