#!/bin/bash
set -e

PRELOAD_DIR="/usr/share/hassio/docker/preload"
DATA_PRELOAD_DIR="/mnt/data/supervisor/docker/preload"
LOG_FILE="/var/log/hassio-preload.log"

echo "$(date): === Starting Home Assistant Container Preload ===" | tee -a "$LOG_FILE"

# Wait for Docker to be ready
echo "$(date): Waiting for Docker daemon..." | tee -a "$LOG_FILE"
for i in {1..60}; do
    if docker info >/dev/null 2>&1; then
        echo "$(date): Docker is ready" | tee -a "$LOG_FILE"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "$(date): ERROR: Docker daemon not ready after 2 minutes" | tee -a "$LOG_FILE"
        exit 1
    fi
    sleep 2
done

# Check for preload directories
FOUND_PRELOAD=false

for preload_dir in "$DATA_PRELOAD_DIR" "$PRELOAD_DIR"; do
    if [ -d "$preload_dir" ]; then
        echo "$(date): Found preload directory: $preload_dir" | tee -a "$LOG_FILE"
        
        # Process all tar files
        for tar_file in "$preload_dir"/*.tar; do
            if [ -f "$tar_file" ]; then
                FOUND_PRELOAD=true
                container_name=$(basename "$tar_file" .tar)
                echo "$(date): Loading container: $container_name" | tee -a "$LOG_FILE"
                
                if docker load < "$tar_file" 2>&1 | tee -a "$LOG_FILE"; then
                    echo "$(date): ✓ Successfully loaded: $container_name" | tee -a "$LOG_FILE"
                    
                    # Special handling for core container
                    if [[ "$container_name" == core_* ]]; then
                        echo "$(date): Processing custom core container..." | tee -a "$LOG_FILE"
                        
                        # Get the loaded image ID
                        LOADED_IMAGE=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep -E "(homeassistant|core)" | head -1 | tr -d ' ')
                        if [ -n "$LOADED_IMAGE" ]; then
                            echo "$(date): Loaded core image: $LOADED_IMAGE" | tee -a "$LOG_FILE"
                            
                            # Tag it with supervisor-expected names
                            SUPERVISOR_IMAGE="ghcr.io/home-assistant/generic-x86-64-homeassistant:2025.6.1"
                            LANDINGPAGE_IMAGE="ghcr.io/home-assistant/generic-x86-64-homeassistant:landingpage"
                            
                            echo "$(date): Tagging as supervisor-expected image: $SUPERVISOR_IMAGE" | tee -a "$LOG_FILE"
                            docker tag "$LOADED_IMAGE" "$SUPERVISOR_IMAGE" || true
                            
                            echo "$(date): Tagging as landingpage: $LANDINGPAGE_IMAGE" | tee -a "$LOG_FILE"
                            docker tag "$LOADED_IMAGE" "$LANDINGPAGE_IMAGE" || true
                            
                            # Verify tags
                            echo "$(date): Verification - supervisor images:" | tee -a "$LOG_FILE"
                            docker images | grep "generic-x86-64-homeassistant" | tee -a "$LOG_FILE" || echo "No supervisor images found" | tee -a "$LOG_FILE"
                        fi
                    fi
                else
                    echo "$(date): ✗ Failed to load: $container_name" | tee -a "$LOG_FILE"
                fi
                
                # Clean up tar file after loading
                echo "$(date): Removing tar file: $tar_file" | tee -a "$LOG_FILE"
                rm -f "$tar_file"
            fi
        done
    fi
done

if [ "$FOUND_PRELOAD" = false ]; then
    echo "$(date): No preload containers found" | tee -a "$LOG_FILE"
    echo "$(date): Checked directories:" | tee -a "$LOG_FILE"
    echo "  - $DATA_PRELOAD_DIR" | tee -a "$LOG_FILE"
    echo "  - $PRELOAD_DIR" | tee -a "$LOG_FILE"
fi

# Final verification
echo "$(date): Final Docker images:" | tee -a "$LOG_FILE"
docker images | tee -a "$LOG_FILE"

echo "$(date): === Container Preload Completed ===" | tee -a "$LOG_FILE"
