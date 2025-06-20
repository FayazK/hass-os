#!/bin/bash
# Quick fix for systemd service setup

cd /Users/safwanyusufzai/HomeAssistant/os

echo "=== Fixing systemd service setup ==="

# Remove duplicate services from wants directory
WANTS_DIR="buildroot-external/rootfs-overlay/etc/systemd/system/multi-user.target.wants"

echo "Cleaning up wants directory..."
rm -f "$WANTS_DIR/ha-registry-redirect.service"
rm -f "$WANTS_DIR/custom-core-resolver.service"
rm -f "$WANTS_DIR/container-preload.service"
rm -f "$WANTS_DIR/ha-custom-loader.service"

# Keep only our preload service and recreate it as a proper symlink
if [ -f "$WANTS_DIR/hassio-preload-containers.service" ]; then
    # Check if it's the correct symlink content
    CONTENT=$(cat "$WANTS_DIR/hassio-preload-containers.service" 2>/dev/null)
    if [ "$CONTENT" = "../hassio-preload-containers.service" ]; then
        echo "✅ Preload service symlink is correct"
    else
        echo "Fixing preload service symlink..."
        echo "../hassio-preload-containers.service" > "$WANTS_DIR/hassio-preload-containers.service"
    fi
fi

# Ensure preload script is executable
chmod +x buildroot-external/rootfs-overlay/usr/bin/hassio-preload-containers.sh 2>/dev/null || true

echo "✅ Systemd service setup fixed"
echo ""
echo "Run verification again:"
echo "./verify-custom-integration.sh"
