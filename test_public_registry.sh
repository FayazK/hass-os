#!/bin/bash
# Test script to verify custom core access without authentication

echo "=== Testing Custom Core Access ==="

# Test 1: Direct Docker access
echo "1. Testing direct Docker pull..."
if docker pull doc-reg.three60.app/homeassistant/core:2025.5.0-custom; then
    echo "✓ Direct pull successful"
    IMAGE_SIZE=$(docker images doc-reg.three60.app/homeassistant/core:2025.5.0-custom --format "table {{.Size}}" | tail -n1)
    echo "  Image size: $IMAGE_SIZE"
else
    echo "✗ Direct pull failed"
    echo "  Trying with authentication..."
    
    if docker login doc-reg.three60.app; then
        if docker pull doc-reg.three60.app/homeassistant/core:2025.5.0-custom; then
            echo "✓ Pull successful with authentication"
        else
            echo "✗ Pull failed even with authentication"
            exit 1
        fi
    else
        echo "✗ Authentication failed"
        exit 1
    fi
fi

# Test 2: Inspect the image
echo ""
echo "2. Inspecting custom core image..."
docker inspect doc-reg.three60.app/homeassistant/core:2025.5.0-custom | jq -r '.[0].Config.Labels."org.opencontainers.image.title"' 2>/dev/null || echo "No title label found"

# Test 3: Quick run test
echo ""
echo "3. Testing custom core container startup..."
CONTAINER_ID=$(docker run -d --rm \
  -e "SUPERVISOR_TOKEN=test" \
  -e "HOMEASSISTANT_REPOSITORY=doc-reg.three60.app/homeassistant/core" \
  doc-reg.three60.app/homeassistant/core:2025.5.0-custom \
  python -c "print('Custom core container test successful'); import sys; sys.exit(0)")

if [ $? -eq 0 ]; then
    echo "✓ Container startup test passed"
    docker logs "$CONTAINER_ID" 2>/dev/null || true
    docker stop "$CONTAINER_ID" >/dev/null 2>&1 || true
else
    echo "✗ Container startup test failed"
fi

# Test 4: Check for custom frontend in the image
echo ""
echo "4. Checking for custom frontend in the image..."
docker run --rm doc-reg.three60.app/homeassistant/core:2025.5.0-custom \
  ls -la /usr/src/homeassistant/homeassistant/components/frontend/ | head -10

echo ""
echo "=== Test Summary ==="
echo "If all tests passed, the custom core image is working correctly."
echo "Proceed with the OS build using the fixed integration scripts."
