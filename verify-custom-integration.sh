#!/bin/bash
# Verification script for Home Assistant OS Custom Core Integration

echo "=== Home Assistant OS Custom Core Integration Verification ==="
echo ""

# Check current directory
if [ ! -f "buildroot-external/package/hassio/version-custom.json" ]; then
    echo "❌ ERROR: Not in Home Assistant OS source directory"
    echo "Please run this script from the root of your HomeAssistant/os directory"
    exit 1
fi

echo "✅ Found Home Assistant OS source directory"

# Check version configuration
echo ""
echo "=== Checking Version Configuration ==="
if [ -f "buildroot-external/package/hassio/version-custom.json" ]; then
    echo "✅ version-custom.json exists"
    echo "Content:"
    cat buildroot-external/package/hassio/version-custom.json | jq . 2>/dev/null || cat buildroot-external/package/hassio/version-custom.json
    
    # Check if core version is set correctly
    CORE_VERSION=$(jq -r '.core' buildroot-external/package/hassio/version-custom.json 2>/dev/null)
    if [ "$CORE_VERSION" = "2025.6.1" ]; then
        echo "✅ Core version set correctly: $CORE_VERSION"
    else
        echo "⚠️  Core version: $CORE_VERSION (should be 2025.6.1)"
    fi
else
    echo "❌ version-custom.json missing"
fi

# Check fetch script
echo ""
echo "=== Checking Fetch Script ==="
if [ -f "buildroot-external/package/hassio/fetch-container-image.sh" ]; then
    echo "✅ fetch-container-image.sh exists"
    if grep -q "CUSTOM BUILD" buildroot-external/package/hassio/fetch-container-image.sh; then
        echo "✅ Custom build logic found"
    else
        echo "⚠️  Custom build logic may be missing"
    fi
    
    if grep -q "doc-reg.three60.app" buildroot-external/package/hassio/fetch-container-image.sh; then
        echo "✅ Custom registry reference found"
    else
        echo "❌ Custom registry reference missing"
    fi
else
    echo "❌ fetch-container-image.sh missing"
fi

# Check data partition script
echo ""
echo "=== Checking Data Partition Script ==="
if [ -f "buildroot-external/package/hassio/create-data-partition.sh" ]; then
    echo "✅ create-data-partition.sh exists"
    if grep -q "preload" buildroot-external/package/hassio/create-data-partition.sh; then
        echo "✅ Container preload logic found"
    else
        echo "⚠️  Container preload logic may be missing"
    fi
else
    echo "❌ create-data-partition.sh missing"
fi

# Check systemd service
echo ""
echo "=== Checking Systemd Integration ==="
if [ -f "buildroot-external/rootfs-overlay/etc/systemd/system/hassio-preload-containers.service" ]; then
    echo "✅ Preload service file exists"
    
    if [ -f "buildroot-external/rootfs-overlay/etc/systemd/system/multi-user.target.wants/hassio-preload-containers.service" ]; then
        echo "✅ Service is enabled"
        # Check if it's a proper symlink
        LINK_TARGET=$(cat "buildroot-external/rootfs-overlay/etc/systemd/system/multi-user.target.wants/hassio-preload-containers.service" 2>/dev/null)
        if [ "$LINK_TARGET" = "../hassio-preload-containers.service" ]; then
            echo "✅ Service symlink is correct"
        else
            echo "⚠️  Service symlink may be incorrect: $LINK_TARGET"
        fi
    else
        echo "⚠️  Service may not be enabled"
    fi
else
    echo "❌ Preload service file missing"
fi

# Check preload script
if [ -f "buildroot-external/rootfs-overlay/usr/bin/hassio-preload-containers.sh" ]; then
    echo "✅ Preload script exists"
else
    echo "❌ Preload script missing"
fi

# Check Docker authentication
echo ""
echo "=== Checking Docker Authentication ==="
if [ -f "buildroot-external/rootfs-overlay/root/.docker/config.json" ]; then
    echo "✅ Docker config exists"
    if grep -q "doc-reg.three60.app" buildroot-external/rootfs-overlay/root/.docker/config.json; then
        echo "✅ Custom registry auth configured"
    else
        echo "❌ Custom registry auth missing"
    fi
else
    echo "❌ Docker config missing"
fi

# Check if Docker is available for testing
echo ""
echo "=== Checking Docker Availability ==="
if command -v docker >/dev/null 2>&1; then
    echo "✅ Docker command available"
    if docker info >/dev/null 2>&1; then
        echo "✅ Docker daemon accessible"
        
        # Check if custom image exists
        if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "doc-reg.three60.app/homeassistant/core:2025.5.0-custom"; then
            echo "✅ Custom core image found locally"
        else
            echo "⚠️  Custom core image not found locally"
            echo "   You may need to pull: docker pull doc-reg.three60.app/homeassistant/core:2025.5.0-custom"
        fi
    else
        echo "⚠️  Docker daemon not accessible"
    fi
else
    echo "⚠️  Docker not available (normal on build server)"
fi

# Check buildroot configuration
echo ""
echo "=== Checking Buildroot Configuration ==="
if [ -f "buildroot-external/configs/generic_x86_64_defconfig" ]; then
    echo "✅ Generic x86_64 config exists"
    if grep -q "BR2_PACKAGE_HASSIO=y" buildroot-external/configs/generic_x86_64_defconfig; then
        echo "✅ Hassio package enabled"
    else
        echo "❌ Hassio package not enabled in defconfig"
    fi
else
    echo "❌ Generic x86_64 config missing"
fi

# Summary
echo ""
echo "=== Verification Summary ==="
echo ""
echo "If all items above show ✅, your custom integration should work."
echo "If you see ❌ or ⚠️ items, please review the corresponding files."
echo ""
echo "Next steps:"
echo "1. Run: make clean"
echo "2. Run: make"
echo "3. Deploy the built image"
echo "4. Check logs: journalctl -u hassio-preload-containers.service"
echo ""
echo "=== End Verification ==="
