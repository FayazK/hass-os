#!/bin/bash
# Override Docker registry calls for Home Assistant Core

# Function to intercept docker pull commands
docker_pull_override() {
    local image="$1"
    
    # Check if this is a Home Assistant Core image request
    if [[ "$image" =~ ghcr\.io/home-assistant/.*-homeassistant ]]; then
        echo "Intercepting Home Assistant Core image request: $image"
        
        # Load our custom image instead
        if [ -f "/mnt/data/supervisor/custom_core.tar" ]; then
            echo "Loading custom core image..."
            /usr/bin/docker load -i /mnt/data/supervisor/custom_core.tar
            
            # Tag it as the requested image
            CUSTOM_IMAGE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "doc-reg.three60.app/homeassistant/core" | head -1)
            if [ -n "$CUSTOM_IMAGE" ]; then
                /usr/bin/docker tag "$CUSTOM_IMAGE" "$image"
                echo "Tagged custom image as: $image"
                return 0
            fi
        fi
    fi
    
    # Fall back to normal docker pull
    /usr/bin/docker.real "$@"
}

# Create wrapper for docker command
if [ ! -f "/usr/bin/docker.real" ]; then
    mv /usr/bin/docker /usr/bin/docker.real
    
    cat > /usr/bin/docker << 'DOCKER_EOF'
#!/bin/bash
if [ "$1" = "pull" ]; then
    docker_pull_override "$2"
else
    /usr/bin/docker.real "$@"
fi
DOCKER_EOF
    
    chmod +x /usr/bin/docker
fi
