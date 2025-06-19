#!/bin/bash
# Minimal fix to preload containers into data partition
# This replaces the create-data-partition.sh script

set -e

build_dir=$1
dst_dir=$2  
channel=$3
data_img="${dst_dir}/data.ext4"

echo "=== Creating data partition with container preloading ==="

# Create 3GB data partition
rm -f "${data_img}"
truncate --size="6144M" "${data_img}"
mkfs.ext4 -L "hassos-data" -E lazy_itable_init=0,lazy_journal_init=0 "${data_img}"

echo "Created data partition: ${data_img} (6GB)"

# Mount the partition
mount_point="${build_dir}/data_mount"
mkdir -p "${mount_point}"

if loop_device=$(losetup --find --show "${data_img}"); then
    echo "Created loop device: ${loop_device}"
    
    if mount "${loop_device}" "${mount_point}"; then
        echo "Mounted data partition"
        
        # Create directory structure
        mkdir -p "${mount_point}/supervisor"
        mkdir -p "${mount_point}/homeassistant"
        mkdir -p "${mount_point}/docker/containers"
        mkdir -p "${mount_point}/docker/preload"
        mkdir -p "${mount_point}/docker/config"
        
        echo "Created directory structure"
        
        # === KEY FIX: Copy container images for preloading ===
        if [ -d "${build_dir}/images" ]; then
            echo "Found container images directory: ${build_dir}/images"
            
            # Copy ALL container tar files to preload directory
            for tar_file in "${build_dir}/images"/*.tar; do
                if [ -f "$tar_file" ]; then
                    container_name=$(basename "$tar_file")
                    echo "Copying container: $container_name"
                    cp "$tar_file" "${mount_point}/docker/preload/"
                fi
            done
            
            echo "Container images copied to preload directory:"
            ls -lh "${mount_point}/docker/preload/"
        else
            echo "ERROR: Container images directory not found: ${build_dir}/images"
        fi
        
        # Install supervisor version configuration with custom core
        cat > "${mount_point}/supervisor/version.json" << 'EOF'
{
  "supervisor": "2025.05.3",
  "dns": "2023.06.2", 
  "audio": "2023.10.0",
  "cli": "2023.10.0",
  "multicast": "2023.06.2",
  "observer": "2023.06.0",
  "core": "doc-reg.three60.app/homeassistant/core:2025.5.0-custom"
}
EOF
        
        echo "Installed supervisor version configuration"
        
        # Copy Docker registry authentication
        auth_source_file=""
        possible_paths=(
            "$(pwd)/buildroot-external/rootfs-overlay/root/.docker/config.json"
            "../buildroot-external/rootfs-overlay/root/.docker/config.json"
            "/home/fayazk/HomeAssistant/os/buildroot-external/rootfs-overlay/root/.docker/config.json"
        )
        
        for auth_path in "${possible_paths[@]}"; do
            if [ -f "$auth_path" ]; then
                auth_source_file="$auth_path"
                break
            fi
        done
        
        if [ -f "$auth_source_file" ]; then
            echo "Installing Docker registry authentication"
            cp "$auth_source_file" "${mount_point}/docker/config/"
        else
            echo "Warning: Docker registry authentication not found"
        fi
        
        # Create container preload script for first boot
        cat > "${mount_point}/docker/preload-containers.sh" << 'EOF'
#!/bin/bash
# Script to preload containers on first boot

PRELOAD_DIR="/usr/share/hassio/docker/preload"
LOG_FILE="/var/log/container-preload.log"

echo "$(date): Starting container preload..." >> "$LOG_FILE"

if [ -d "$PRELOAD_DIR" ]; then
    for tar_file in "$PRELOAD_DIR"/*.tar; do
        if [ -f "$tar_file" ]; then
            container_name=$(basename "$tar_file" .tar)
            echo "$(date): Loading $container_name..." >> "$LOG_FILE"
            if docker load < "$tar_file" >> "$LOG_FILE" 2>&1; then
                echo "$(date): Successfully loaded $container_name" >> "$LOG_FILE"
            else
                echo "$(date): Failed to load $container_name" >> "$LOG_FILE"
            fi
        fi
    done
    echo "$(date): Container preload completed" >> "$LOG_FILE"
else
    echo "$(date): No preload directory found" >> "$LOG_FILE"
fi
EOF
        
        chmod +x "${mount_point}/docker/preload-containers.sh"
        
        # Set proper permissions
        chown -R 0:0 "${mount_point}"
        chmod -R 755 "${mount_point}"
        
        # Create a verification file
        echo "Custom core integration with container preloading" > "${mount_point}/custom-integration-marker.txt"
        echo "Build date: $(date)" >> "${mount_point}/custom-integration-marker.txt"
        echo "Custom core: doc-reg.three60.app/homeassistant/core:2025.5.0-custom" >> "${mount_point}/custom-integration-marker.txt"
        
        # Show final contents
        echo ""
        echo "=== Data partition contents ==="
        find "${mount_point}" -type f -exec ls -lh {} \;
        
        # Unmount
        umount "${mount_point}"
        losetup -d "${loop_device}"
        
        echo "Data partition created successfully with container preloading!"
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

echo "=== Container preload setup completed ==="
