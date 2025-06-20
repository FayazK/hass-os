#!/bin/bash
# Clean up duplicate systemd services from previous attempts

echo "=== Cleaning up duplicate systemd services ==="

# Remove duplicate services from wants directory (keep only our preload service)
WANTS_DIR="buildroot-external/rootfs-overlay/etc/systemd/system/multi-user.target.wants"

echo "Current services in wants directory:"
ls -la "$WANTS_DIR/" 2>/dev/null || echo "Directory not found"

# Remove old duplicate services
for service in ha-registry-redirect.service custom-core-resolver.service container-preload.service ha-custom-loader.service; do
    if [ -f "$WANTS_DIR/$service" ]; then
        echo "Removing duplicate: $WANTS_DIR/$service"
        rm "$WANTS_DIR/$service"
    fi
done

# Remove duplicate service definitions
SERVICE_DIR="buildroot-external/rootfs-overlay/etc/systemd/system"

for service in ha-registry-redirect.service custom-core-resolver.service container-preload.service ha-custom-loader.service; do
    if [ -f "$SERVICE_DIR/$service" ]; then
        echo "Removing duplicate service definition: $SERVICE_DIR/$service"
        rm "$SERVICE_DIR/$service"
    fi
done

# Also remove the oddly named service with spaces
if [ -f "$SERVICE_DIR/docker-registry-auth.service  " ]; then
    echo "Removing oddly named service: docker-registry-auth.service  "
    rm "$SERVICE_DIR/docker-registry-auth.service  "
fi

echo ""
echo "Remaining services in wants directory:"
ls -la "$WANTS_DIR/" 2>/dev/null || echo "Directory not found"

echo ""
echo "Remaining service definitions:"
ls -la "$SERVICE_DIR/"*.service 2>/dev/null || echo "No service files found"

echo ""
echo "Cleanup completed!"
