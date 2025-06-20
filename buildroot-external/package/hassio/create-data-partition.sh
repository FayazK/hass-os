#!/bin/bash
set -e

build_dir=$1
dst_dir=$2  
channel=$3
data_img="${dst_dir}/data.ext4"

echo "=== CUSTOM BUILD: Creating data partition with optimized container preloading ==="

# Create larger data partition (12GB to accommodate 3.9GB custom core)
rm -f "${data_img}"
truncate --size="12288M" "${data_img}"
mkfs.ext4 -L "hassos-data" -E lazy_itable_init=0,lazy_journal_init=0 "${data_img}"

echo "Created data partition: ${data_img} (12GB)"

# Mount the partition
mount_point="${build_dir}/data_mount"
mkdir -p "${mount_point}"

if loop_device=$(losetup --find --show "${data_img}"); then
    echo "Created loop device: ${loop_device}"
    
    if mount "${loop_device}" "${mount_point}"; then
        echo "Mounted data partition for optimized container preloading"
        
        # Create Home Assistant directory structure
        mkdir -p "${mount_point}/supervisor"
        mkdir -p "${mount_point}/homeassistant"
        mkdir -p "${mount_point}/docker/preload"
        mkdir -p "${mount_point}/docker/config"
        
        # === OPTIMIZED: Move containers instead of copying to save space ===
        echo ""
        echo "=== Moving container images to preload directory ==="
        
        if [ -d "${build_dir}/images" ]; then
            echo "Source images directory: ${build_dir}/images"
            echo "Available space in data partition:"
            df -h "${mount_point}"
            
            # Move ALL container tar files (instead of copying to save space)
            for tar_file in "${build_dir}/images"/*.tar; do
                if [ -f "$tar_file" ]; then
                    container_name=$(basename "$tar_file")
                    echo "Moving container: $container_name"
                    
                    # Show file size
                    echo "  Size: $(du -h "$tar_file" | cut -f1)"
                    
                    # Move instead of copy to save space
                    mv "$tar_file" "${mount_point}/docker/preload/"
                    
                    # Special note for custom core
                    if [[ "$container_name" == core_* ]]; then
                        echo "  ✓ Custom core container moved: $container_name"
                    fi
                fi
            done
            
            echo ""
            echo "Container preload completed:"
            ls -lh "${mount_point}/docker/preload/"
            
            echo ""
            echo "Space usage after move:"
            df -h "${mount_point}"
            
        else
            echo "ERROR: Container images directory not found: ${build_dir}/images"
            exit 1
        fi
        
        # Create supervisor version configuration
        cat > "${mount_point}/supervisor/version.json" << 'EOF'
{
  "supervisor": "2025.05.5",
  "dns": "2025.02.0",
  "audio": "2025.02.0",
  "cli": "2025.04.0", 
  "multicast": "2025.02.0",
  "observer": "2025.02.0",
  "core": "2025.6.1"
}
EOF
        
        echo "Installed supervisor version configuration"
        
        # Copy Docker registry authentication (small file)
        auth_file=""
        search_paths=(
            "$(pwd)/buildroot-external/rootfs-overlay/root/.docker/config.json"
            "${PWD}/buildroot-external/rootfs-overlay/root/.docker/config.json"
            "/build/buildroot-external/rootfs-overlay/root/.docker/config.json"
        )
        
        for auth_path in "${search_paths[@]}"; do
            if [ -f "$auth_path" ]; then
                auth_file="$auth_path"
                break
            fi
        done
        
        if [ -f "$auth_file" ]; then
            echo "Installing Docker registry authentication"
            cp "$auth_file" "${mount_point}/docker/config/"
        else
            echo "Warning: Docker registry authentication not found"
        fi
        
        # Create optimized preload script for data partition (backup)
        cat > "${mount_point}/docker/preload-containers.sh" << 'EOF'
#!/bin/bash
# Backup preload script (main script installed via rootfs overlay)
set -e

PRELOAD_DIR="/usr/share/hassio/docker/preload"
LOG_FILE="/var/log/hassio-preload.log"

echo "$(date): === Backup preload script running ===" | tee -a "$LOG_FILE"

if [ -d "$PRELOAD_DIR" ]; then
    echo "$(date): Loading containers from $PRELOAD_DIR" | tee -a "$LOG_FILE"
    
    for tar_file in "$PRELOAD_DIR"/*.tar; do
        if [ -f "$tar_file" ]; then
            container_name=$(basename "$tar_file" .tar)
            echo "$(date): Loading $container_name..." | tee -a "$LOG_FILE"
            if docker load < "$tar_file" 2>&1 | tee -a "$LOG_FILE"; then
                echo "$(date): ✓ $container_name loaded" | tee -a "$LOG_FILE"
                rm -f "$tar_file"  # Remove to save space
            fi
        fi
    done
    
    echo "$(date): Container preload completed" | tee -a "$LOG_FILE"
    docker images | tee -a "$LOG_FILE"
else
    echo "$(date): No preload directory found" | tee -a "$LOG_FILE"
fi
EOF
        
        chmod +x "${mount_point}/docker/preload-containers.sh"
        
        # Set proper permissions
        chown -R 0:0 "${mount_point}"
        find "${mount_point}" -type d -exec chmod 755 {} \;
        find "${mount_point}" -type f -exec chmod 644 {} \;
        chmod +x "${mount_point}/docker/preload-containers.sh"
        
        # Create verification info
        cat > "${mount_point}/custom-integration.info" << EOF
Custom Home Assistant Core Integration - OPTIMIZED
===================================================
Build Date: $(date)
Custom Core: 3.9GB moved to preload directory
Data Partition: 12GB (optimized for large custom core)

Container Location: /usr/share/hassio/docker/preload/
Preload Strategy: Move containers to save space during build

Final Space Usage:
$(df -h "${mount_point}")

Preloaded Containers:
$(ls -1 "${mount_point}/docker/preload/" | wc -l) containers ready for preload
$(du -sh "${mount_point}/docker/preload/" | cut -f1) total size
EOF
        
        echo ""
        echo "=== Final data partition summary ==="
        echo "Total containers preloaded: $(ls -1 "${mount_point}/docker/preload/" | wc -l)"
        echo "Space usage:"
        df -h "${mount_point}"
        echo ""
        echo "Custom core status:"
        if [ -f "${mount_point}/docker/preload/core_2025.6.1.tar" ]; then
            echo "✓ Custom core ready: $(du -h "${mount_point}/docker/preload/core_2025.6.1.tar" | cut -f1)"
        else
            echo "✗ Custom core not found"
        fi
        
        # Unmount and cleanup
        sync  # Ensure all data is written
        umount "${mount_point}"
        losetup -d "${loop_device}"
        
        echo ""
        echo "=== Data partition created successfully! ==="
        echo "Final size: $(du -h "$data_img" | cut -f1)"
        echo "Optimized container preloading configured for 3.9GB custom core"
        
    else
        echo "Failed to mount data partition"
        losetup -d "${loop_device}"
        exit 1
    fi
else
    echo "Failed to create loop device"
    exit 1
fi

# Cleanup
rmdir "${mount_point}" 2>/dev/null || true

echo "=== Optimized data partition creation completed! ==="
