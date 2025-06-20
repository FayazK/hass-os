#!/bin/bash
# Fix systemd service symlink for build environment

cd /home/fayazk/HomeAssistant/os

echo "=== Fixing systemd service symlink ==="

# Remove existing file and create proper symlink
WANTS_DIR="buildroot-external/rootfs-overlay/etc/systemd/system/multi-user.target.wants"
SERVICE_LINK="$WANTS_DIR/hassio-preload-containers.service"

# Remove the file that contains "../hassio-preload-containers.service"
rm -f "$SERVICE_LINK"

# Create proper symlink
cd "$WANTS_DIR"
ln -sf ../hassio-preload-containers.service hassio-preload-containers.service
cd - >/dev/null

echo "✓ Symlink created properly"
ls -la "$SERVICE_LINK"

echo "=== Systemd symlink fixed ==="
