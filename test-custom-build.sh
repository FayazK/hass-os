#!/bin/bash
# Test script for custom build

set -e

echo "=== Testing Custom Home Assistant OS Build ==="

# Clean previous build to ensure fresh start
echo "Cleaning previous build..."
make clean

# Configure for generic x86-64
echo "Configuring build..."
make generic_x86_64_defconfig

# Start build with custom logging
echo "Starting build with enhanced logging..."
echo "This will take 1-3 hours..."

# Build and capture output
if make -j$(nproc) 2>&1 | tee custom_build.log; then
    echo "✓ Build completed successfully"
    
    # Show verification results
    echo ""
    echo "=== Build Results ==="
    
    # Check output directory
    if [ -d "output/images" ]; then
        echo "Output images:"
        ls -lh output/images/
        
        # Check for custom core container
        if [ -f "output/build/hassio-1.0.0/images/core_2025.5.0-custom.tar" ]; then
            CORE_SIZE=$(du -h "output/build/hassio-1.0.0/images/core_2025.5.0-custom.tar" | cut -f1)
            echo "✓ Custom core downloaded: $CORE_SIZE"
        else
            echo "✗ Custom core NOT downloaded"
        fi
    else
        echo "✗ No output images found"
    fi
    
    # Extract build log insights
    echo ""
    echo "=== Build Log Analysis ==="
    echo "Custom build messages:"
    grep "\[CUSTOM BUILD\]" custom_build.log | tail -20
    
    echo ""
    echo "Error messages:"
    grep -i "error\|failed" custom_build.log | tail -10
    
else
    echo "✗ Build failed"
    echo "Check custom_build.log for details"
    echo "Last 20 lines of log:"
    tail -20 custom_build.log
    exit 1
fi

echo ""
echo "=== Test Complete ==="
echo "Check output/images/ for final OS image"
