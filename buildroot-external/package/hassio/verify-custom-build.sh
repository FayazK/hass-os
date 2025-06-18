#!/bin/bash
# Post-build verification script

echo "=== Custom Build Verification ==="

BUILD_DIR="$1"
IMAGES_DIR="$2"

echo "Build directory: $BUILD_DIR"
echo "Images directory: $IMAGES_DIR"

# Check if custom core was downloaded
CORE_TAR="$BUILD_DIR/hassio-1.0.0/images/core_2025.5.0-custom.tar"
if [ -f "$CORE_TAR" ]; then
    CORE_SIZE=$(du -h "$CORE_TAR" | cut -f1)
    echo "✓ Custom core container found: $CORE_SIZE"
else
    echo "✗ Custom core container MISSING!"
    echo "Available containers:"
    ls -la "$BUILD_DIR/hassio-1.0.0/images/" 2>/dev/null || echo "No containers found"
    exit 1
fi

# Check data partition
DATA_PARTITION="$IMAGES_DIR/data.ext4"
if [ -f "$DATA_PARTITION" ]; then
    echo "✓ Data partition found"
    
    # Try to mount and check contents
    TEMP_MOUNT="/tmp/verify_data_$$"
    mkdir -p "$TEMP_MOUNT"
    
    if mount -o loop "$DATA_PARTITION" "$TEMP_MOUNT" 2>/dev/null; then
        if grep -q "doc-reg.three60.app" "$TEMP_MOUNT/supervisor/version.json" 2>/dev/null; then
            echo "✓ Custom core reference found in data partition"
        else
            echo "✗ Custom core reference MISSING from data partition"
        fi
        umount "$TEMP_MOUNT"
    fi
    rmdir "$TEMP_MOUNT"
else
    echo "✗ Data partition MISSING!"
fi

echo "=== Verification Complete ==="
