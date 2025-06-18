#!/bin/bash
# Comprehensive diagnostic script for Home Assistant OS custom core integration

set -e

echo "=== Home Assistant OS Custom Core Integration Diagnostic ==="
echo "Date: $(date)"
echo "Location: $(pwd)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "=== 1. Verify Build Environment and Files ==="

# Check if we're in the OS directory
if [ ! -f "Makefile" ] || [ ! -d "buildroot-external" ]; then
    log_error "Not in Home Assistant OS root directory"
    exit 1
fi

log_info "Checking custom configuration files..."

# Check hassio package configuration
if [ -f "buildroot-external/package/hassio/version-custom.json" ]; then
    log_success "Custom version configuration found"
    echo "Contents:"
    cat buildroot-external/package/hassio/version-custom.json
    echo ""
else
    log_error "Custom version configuration missing"
fi

# Check hassio makefile
if [ -f "buildroot-external/package/hassio/hassio.mk" ]; then
    log_success "Hassio makefile found"
    echo "Checking for custom modifications..."
    if grep -q "version-custom.json" buildroot-external/package/hassio/hassio.mk; then
        log_success "Makefile references custom version"
    else
        log_warning "Makefile may not reference custom version"
    fi
else
    log_error "Hassio makefile missing"
fi

# Check fetch script
if [ -f "buildroot-external/package/hassio/fetch-container-image.sh" ]; then
    log_success "Container fetch script found"
    if grep -q "doc-reg.three60.app" buildroot-external/package/hassio/fetch-container-image.sh; then
        log_success "Fetch script references custom registry"
    else
        log_warning "Fetch script may not reference custom registry"
    fi
else
    log_error "Container fetch script missing"
fi

echo ""
echo "=== 2. Check Build Output ==="

# Check if build completed
if [ -d "output/images" ]; then
    log_success "Build output directory exists"
    
    # Check for OS image
    OS_IMAGE=$(find output/images -name "haos_generic-x86-64*.img" | head -1)
    if [ -n "$OS_IMAGE" ]; then
        log_success "OS image found: $(basename "$OS_IMAGE")"
        IMAGE_SIZE=$(du -h "$OS_IMAGE" | cut -f1)
        log_info "Image size: $IMAGE_SIZE"
    else
        log_error "OS image not found"
    fi
else
    log_error "Build output directory missing"
fi

# Check hassio build directory
if [ -d "output/build/hassio-1.0.0" ]; then
    log_success "Hassio build directory exists"
    
    # Check for custom core container
    if [ -f "output/build/hassio-1.0.0/images/core_2025.5.0-custom.tar" ]; then
        CORE_SIZE=$(du -h "output/build/hassio-1.0.0/images/core_2025.5.0-custom.tar" | cut -f1)
        log_success "Custom core container found (Size: $CORE_SIZE)"
    else
        log_error "Custom core container not found"
        log_info "Available containers:"
        ls -la "output/build/hassio-1.0.0/images/" 2>/dev/null || log_error "No containers found"
    fi
    
    # Check version configuration used in build
    if [ -f "output/build/hassio-1.0.0/version.json" ]; then
        log_info "Build used this version configuration:"
        cat "output/build/hassio-1.0.0/version.json"
        echo ""
    fi
else
    log_error "Hassio build directory missing"
fi

echo ""
echo "=== 3. Test Docker Registry Access ==="

log_info "Testing access to custom registry..."

# Test if Docker is running
if docker info >/dev/null 2>&1; then
    log_success "Docker is running"
    
    # Test registry access without authentication
    log_info "Testing registry access without authentication..."
    if docker pull doc-reg.three60.app/homeassistant/core:2025.5.0-custom >/dev/null 2>&1; then
        log_success "Registry accessible without authentication"
    else
        log_warning "Registry requires authentication or image not found"
        
        # Test with authentication
        log_info "Testing with authentication..."
        if docker login doc-reg.three60.app >/dev/null 2>&1; then
            log_success "Registry login successful"
            
            if docker pull doc-reg.three60.app/homeassistant/core:2025.5.0-custom >/dev/null 2>&1; then
                log_success "Custom core image accessible with authentication"
            else
                log_error "Custom core image not found even with authentication"
            fi
        else
            log_error "Registry authentication failed"
        fi
    fi
else
    log_error "Docker is not running"
fi

echo ""
echo "=== 4. Analyze Data Partition ==="

if [ -f "output/images/data.ext4" ]; then
    log_success "Data partition image found"
    
    # Create temporary mount point
    MOUNT_POINT="/tmp/haos_data_check_$$"
    sudo mkdir -p "$MOUNT_POINT"
    
    # Mount data partition
    if sudo mount -o loop "output/images/data.ext4" "$MOUNT_POINT" 2>/dev/null; then
        log_success "Data partition mounted"
        
        # Check supervisor configuration
        if [ -f "$MOUNT_POINT/supervisor/version.json" ]; then
            log_success "Supervisor configuration found in data partition"
            echo "Configuration:"
            sudo cat "$MOUNT_POINT/supervisor/version.json"
            echo ""
            
            if sudo grep -q "doc-reg.three60.app" "$MOUNT_POINT/supervisor/version.json"; then
                log_success "Custom core reference found in data partition"
            else
                log_error "Custom core reference missing from data partition"
            fi
        else
            log_error "Supervisor configuration missing from data partition"
        fi
        
        # Check Docker configuration
        if [ -f "$MOUNT_POINT/docker/config/config.json" ]; then
            log_success "Docker configuration found in data partition"
            
            if sudo grep -q "doc-reg.three60.app" "$MOUNT_POINT/docker/config/config.json"; then
                log_success "Custom registry authentication found in data partition"
            else
                log_warning "Custom registry authentication missing from data partition"
            fi
        else
            log_warning "Docker configuration missing from data partition"
        fi
        
        # Show data partition contents
        log_info "Data partition structure:"
        sudo find "$MOUNT_POINT" -type f 2>/dev/null | head -20
        
        sudo umount "$MOUNT_POINT"
        sudo rmdir "$MOUNT_POINT"
    else
        log_error "Failed to mount data partition"
    fi
else
    log_error "Data partition image not found"
fi

echo ""
echo "=== 5. Check OS Root Filesystem ==="

# Check if rootfs was created
if [ -f "output/images/rootfs.squashfs" ]; then
    log_success "Root filesystem found"
    
    # Try to examine rootfs
    log_info "Checking rootfs for Docker configuration..."
    
    # Create temporary directory for rootfs
    ROOTFS_MOUNT="/tmp/haos_rootfs_check_$$"
    sudo mkdir -p "$ROOTFS_MOUNT"
    
    if sudo mount -o loop "output/images/rootfs.squashfs" "$ROOTFS_MOUNT" 2>/dev/null; then
        log_success "Root filesystem mounted"
        
        # Check for Docker daemon configuration
        if [ -f "$ROOTFS_MOUNT/etc/docker/daemon.json" ]; then
            log_success "Docker daemon configuration found in rootfs"
            echo "Configuration:"
            sudo cat "$ROOTFS_MOUNT/etc/docker/daemon.json"
            echo ""
        else
            log_warning "Docker daemon configuration missing from rootfs"
        fi
        
        # Check for systemd services
        if [ -d "$ROOTFS_MOUNT/etc/systemd/system" ]; then
            log_info "Checking for custom systemd services..."
            sudo find "$ROOTFS_MOUNT/etc/systemd/system" -name "*docker*" -o -name "*hassio*" 2>/dev/null | head -10
        fi
        
        sudo umount "$ROOTFS_MOUNT"
        sudo rmdir "$ROOTFS_MOUNT"
    else
        log_warning "Could not mount root filesystem for inspection"
    fi
else
    log_error "Root filesystem not found"
fi

echo ""
echo "=== 6. Generate Recommendations ==="

echo "Based on the diagnostic results:"
echo ""

# Check what issues were found and provide recommendations
if [ ! -f "output/build/hassio-1.0.0/images/core_2025.5.0-custom.tar" ]; then
    log_error "CRITICAL: Custom core container was not downloaded during build"
    echo "  Recommendation: Check registry authentication and network access during build"
    echo "  Action: Verify buildroot-external/package/hassio/fetch-container-image.sh is being executed"
fi

if [ -f "output/images/data.ext4" ]; then
    echo "✓ Data partition exists and should contain custom configuration"
else
    log_error "CRITICAL: Data partition missing"
    echo "  Recommendation: Check buildroot-external/package/hassio/create-data-partition.sh execution"
fi

echo ""
echo "=== Next Steps ==="
echo "1. If custom core container is missing: Fix registry access during build"
echo "2. If data partition config is wrong: Fix create-data-partition.sh script"
echo "3. If rootfs config is missing: Check rootfs-overlay directory"
echo "4. Test with temporary public registry to eliminate auth issues"
echo ""

echo "=== Diagnostic Complete ==="
