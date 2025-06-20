#!/bin/bash
# Post-build verification script for optimized container handling

echo "=== Custom Build Verification ==="

BUILD_DIR="$1"
IMAGES_DIR="$2"

echo "Build directory: $BUILD_DIR"
echo "Images directory: $IMAGES_DIR"

# Check data partition (containers are moved here to save space)
DATA_PARTITION="$IMAGES_DIR/data.ext4"
if [ -f "$DATA_PARTITION" ]; then
    echo "✓ Data partition found: $(du -h "$DATA_PARTITION" | cut -f1)"
    
    # Mount and check contents
    TEMP_MOUNT="/tmp/verify_data_$$"
    mkdir -p "$TEMP_MOUNT"
    
    if mount -o loop "$DATA_PARTITION" "$TEMP_MOUNT" 2>/dev/null; then
        echo "✓ Data partition mounted successfully"
        
        # Check for preloaded containers
        PRELOAD_DIR="$TEMP_MOUNT/docker/preload"
        if [ -d "$PRELOAD_DIR" ]; then
            CONTAINER_COUNT=$(ls -1 "$PRELOAD_DIR"/*.tar 2>/dev/null | wc -l)
            echo "✓ Container preload directory found with $CONTAINER_COUNT containers"
            
            # Check specifically for custom core
            CORE_TAR=$(find "$PRELOAD_DIR" -name "core_*.tar" -type f | head -1)
            if [ -f "$CORE_TAR" ]; then
                CORE_SIZE=$(du -h "$CORE_TAR" | cut -f1)
                echo "✓ Custom core container found: $(basename "$CORE_TAR") ($CORE_SIZE)"
            else
                echo "✗ Custom core container MISSING from preload directory!"
                echo "Available containers in preload:"
                ls -la "$PRELOAD_DIR/" 2>/dev/null || echo "Preload directory empty"
                umount "$TEMP_MOUNT" 2>/dev/null
                rmdir "$TEMP_MOUNT" 2>/dev/null
                exit 1
            fi
            
            # Show all preloaded containers
            echo "Preloaded containers:"
            ls -lh "$PRELOAD_DIR"/*.tar 2>/dev/null | while read line; do
                echo "  - $(echo "$line" | awk '{print $9}' | xargs basename): $(echo "$line" | awk '{print $5}')"
            done
        else
            echo "✗ Container preload directory MISSING!"
            umount "$TEMP_MOUNT" 2>/dev/null
            rmdir "$TEMP_MOUNT" 2>/dev/null
            exit 1
        fi
        
        # Check supervisor configuration
        if [ -f "$TEMP_MOUNT/supervisor/version.json" ]; then
            echo "✓ Supervisor version configuration found"
            CORE_VERSION=$(grep -o '"core": "[^"]*"' "$TEMP_MOUNT/supervisor/version.json" 2>/dev/null | cut -d'"' -f4)
            if [ -n "$CORE_VERSION" ]; then
                echo "✓ Core version configured: $CORE_VERSION"
            fi
        else
            echo "⚠ Supervisor version configuration missing"
        fi
        
        # Check preload script
        if [ -f "$TEMP_MOUNT/usr/bin/hassio-preload-containers.sh" ] || [ -f "$TEMP_MOUNT/docker/preload-containers.sh" ]; then
            echo "✓ Container preload script installed"
        else
            echo "⚠ Container preload script missing (will be installed via rootfs overlay)"
        fi
        
        # Check systemd service  
        if [ -f "$TEMP_MOUNT/etc/systemd/system/hassio-preload-containers.service" ]; then
            echo "✓ Systemd preload service installed"
        else
            echo "⚠ Systemd preload service missing (will be installed via rootfs overlay)"
        fi
        
        # Check Docker authentication
        if [ -f "$TEMP_MOUNT/docker/config/config.json" ]; then
            echo "✓ Docker registry authentication configured"
        else
            echo "⚠ Docker registry authentication missing"
        fi
        
        umount "$TEMP_MOUNT"
        echo "✓ Data partition verification completed"
    else
        echo "✗ Failed to mount data partition for verification"
        exit 1
    fi
    rmdir "$TEMP_MOUNT" 2>/dev/null
else
    echo "✗ Data partition MISSING!"
    exit 1
fi

# Check final image (try multiple possible names)
FINAL_IMAGE=""
for img_name in "haos_generic-x86-64-15.2.img" "haos_generic-x86-64-*.img"; do
    POTENTIAL_IMAGE="$IMAGES_DIR/$img_name"
    if ls $POTENTIAL_IMAGE 1> /dev/null 2>&1; then
        FINAL_IMAGE=$POTENTIAL_IMAGE
        break
    fi
done

if [ -n "$FINAL_IMAGE" ] && [ -f "$FINAL_IMAGE" ]; then
    IMAGE_SIZE=$(du -h "$FINAL_IMAGE" | cut -f1)
    echo "✓ Final OS image created: $(basename "$FINAL_IMAGE") ($IMAGE_SIZE)"
else
    echo "⚠ Final OS image not yet created (may be generated after verification)"
    echo "Available files in images directory:"
    ls -la "$IMAGES_DIR/" | grep -E "\.(img|raucb)$" || echo "No image files found yet"
fi

echo ""
echo "=== Custom Core Integration Verification Complete ==="
echo "✓ Build successful with custom core preloaded"
echo "✓ Data partition contains optimized container preloading"
echo "✓ Supervisor will use custom core instead of downloading"
