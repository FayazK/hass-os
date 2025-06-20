#!/bin/bash
set -e

build_dir=$1
dst_dir=$2  
channel=$3
data_img="${dst_dir}/data.ext4"

echo "=== CUSTOM BUILD: Creating data partition with preloaded containers ==="

# Create larger data partition (6GB)
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
        echo "Mounted data partition for container preloading"
        
        # Create Home Assistant directory structure
        mkdir -p "${mount_point}/supervisor"
        mkdir -p "${mount_point}/homeassistant"
        mkdir -p "${mount_point}/docker/containers"
        mkdir -p "${mount_point}/docker/preload"
        mkdir -p "${mount_point}/docker/config"
        
        # === CRITICAL: Copy ALL container images for preloading ===
        echo ""
        echo "=== Preloading container images ==="
        
        if [ -d "${build_dir}/images" ]; then
            echo "Source images directory: ${build_dir}/images"
            ls -la "${build_dir}/images"
            
            # Copy ALL container tar files
            for tar_file in "${build_dir}/images"/*.tar; do
                if [ -f "$tar_file" ]; then
                    container_name=$(basename "$tar_file")
                    echo "Copying container: $container_name"
                    cp "$tar_file" "${mount_point}/docker/preload/"
                    
                    # Special handling for our custom core
                    if [[ "$container_name" == core_* ]]; then
                        echo "Custom core container identified: $container_name"
                        # Also copy to supervisor directory for direct access
                        cp "$tar_file" "${mount_point}/supervisor/"
                    fi
                fi
            done
            
            echo ""
            echo "Preloaded containers:"
            ls -lh "${mount_point}/docker/preload/"
        else
            echo "ERROR: Container images directory not found: ${build_dir}/images"
            echo "Available directories in build_dir:"
            ls -la "${build_dir}/" || true
            exit 1
        fi
        
        # Create supervisor version configuration pointing to custom core
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
        cat "${mount_point}/supervisor/version.json"
        
        # Copy Docker registry authentication
        auth_file=""
        search_paths=(
            "$(pwd)/buildroot-external/rootfs-overlay/root/.docker/config.json"
            "${PWD}/buildroot-external/rootfs-overlay/root/.docker/config.json"
            "/home/fayazk/HomeAssistant/os/buildroot-external/rootfs-overlay/root/.docker/config.json"
        )
        
        for auth_path in "${search_paths[@]}"; do
            if [ -f "$auth_path" ]; then
                auth_file="$auth_path"
                break
            fi
        done
        
        if [ -f "$auth_file" ]; then
            echo "Installing Docker registry authentication from: $auth_file"
            cp "$auth_file" "${mount_point}/docker/config/"
        else
            echo "Warning: Docker registry authentication not found"
            echo "Searched paths:"
            printf '  %s\n' "${search_paths[@]}"
        fi
        
        # Create systemd service for container preloading
        mkdir -p "${mount_point}/etc/systemd/system"
        cat > "${mount_point}/etc/systemd/system/hassio-preload-containers.service" << 'EOF'
[Unit]
Description=Preload Home Assistant Containers
After=docker.service
Requires=docker.service
Before=hassio-supervisor.service

[Service]
Type=oneshot
ExecStart=/usr/bin/hassio-preload-containers.sh
RemainAfterExit=yes
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF
        
        # Create the preload script
        mkdir -p "${mount_point}/usr/bin"
        cat > "${mount_point}/usr/bin/hassio-preload-containers.sh" << 'EOF'
#!/bin/bash
set -e

PRELOAD_DIR="/usr/share/hassio/docker/preload"
LOG_FILE="/var/log/hassio-preload.log"

echo "$(date): Starting Home Assistant container preload..." | tee -a "$LOG_FILE"

# Ensure Docker is running
for i in {1..30}; do
    if docker info >/dev/null 2>&1; then
        echo "$(date): Docker is ready" | tee -a "$LOG_FILE"
        break
    fi
    echo "$(date): Waiting for Docker... ($i/30)" | tee -a "$LOG_FILE"
    sleep 2
done

# Preload containers if directory exists
if [ -d "$PRELOAD_DIR" ]; then
    echo "$(date): Found preload directory: $PRELOAD_DIR" | tee -a "$LOG_FILE"
    
    for tar_file in "$PRELOAD_DIR"/*.tar; do
        if [ -f "$tar_file" ]; then
            container_name=$(basename "$tar_file" .tar)
            echo "$(date): Loading container: $container_name" | tee -a "$LOG_FILE"
            
            if docker load < "$tar_file" 2>&1 | tee -a "$LOG_FILE"; then
                echo "$(date): Successfully loaded: $container_name" | tee -a "$LOG_FILE"
                
                # Special handling for core container
                if [[ "$container_name" == core_* ]]; then
                    echo "$(date): Processing custom core container" | tee -a "$LOG_FILE"
                    
                    # List all loaded images to see what we have
                    echo "$(date): Available images after loading:" | tee -a "$LOG_FILE"
                    docker images | grep -E "(homeassistant|core)" | tee -a "$LOG_FILE" || true
                fi
            else
                echo "$(date): Failed to load: $container_name" | tee -a "$LOG_FILE"
            fi
            
            # Remove tar file after successful load to save space
            rm -f "$tar_file"
        fi
    done
    
    echo "$(date): Container preload completed" | tee -a "$LOG_FILE"
    echo "$(date): Final image list:" | tee -a "$LOG_FILE"
    docker images | tee -a "$LOG_FILE"
else
    echo "$(date): No preload directory found at $PRELOAD_DIR" | tee -a "$LOG_FILE"
fi

echo "$(date): Preload script completed" | tee -a "$LOG_FILE"
EOF
        
        chmod +x "${mount_point}/usr/bin/hassio-preload-containers.sh"
        
        # Set proper permissions
        chown -R 0:0 "${mount_point}"
        find "${mount_point}" -type d -exec chmod 755 {} \;
        find "${mount_point}" -type f -exec chmod 644 {} \;
        chmod +x "${mount_point}/usr/bin/hassio-preload-containers.sh"
        
        # Create verification marker
        cat > "${mount_point}/custom-integration.info" << EOF
Custom Home Assistant Core Integration
=====================================
Build Date: $(date)
Custom Core: doc-reg.three60.app/homeassistant/core:2025.5.0-custom
Expected by Supervisor: ghcr.io/home-assistant/generic-x86-64-homeassistant:2025.6.1

Preloaded Containers:
$(ls -1 "${mount_point}/docker/preload/" | grep '\.tar$' || echo "None found")

This data partition contains preloaded containers that will be
imported into Docker during the first boot sequence.
EOF
        
        echo ""
        echo "=== Data partition contents summary ==="
        echo "Supervisor config:"
        find "${mount_point}/supervisor" -type f -ls
        echo ""
        echo "Preloaded containers:"
        find "${mount_point}/docker/preload" -name "*.tar" -ls
        echo ""
        echo "System integration:"
        find "${mount_point}/etc" -type f -ls 2>/dev/null || true
        find "${mount_point}/usr" -type f -ls 2>/dev/null || true
        
        # Unmount and cleanup
        umount "${mount_point}"
        losetup -d "${loop_device}"
        
        echo ""
        echo "=== Data partition created successfully! ==="
        echo "Size: $(du -h "$data_img" | cut -f1)"
        echo "Custom core integration and container preloading configured."
        
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

echo "Data partition creation completed with container preloading!"
