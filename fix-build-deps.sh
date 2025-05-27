#!/bin/bash
set -e

echo "=== Home Assistant OS Build Dependencies Fix ==="
echo "This script will install missing dependencies and fix the build issue"
echo ""

# Install jq if missing
if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq..."
    sudo apt update
    sudo apt install -y jq
fi

# Verify jq installation
echo "JQ version: $(jq --version)"

# Check if version-custom.json exists
VERSION_FILE="buildroot-external/package/hassio/version-custom.json"
echo "Checking version file: $VERSION_FILE"

if [ ! -f "$VERSION_FILE" ]; then
    echo "Creating missing version-custom.json..."
    mkdir -p "$(dirname "$VERSION_FILE")"
    cat > "$VERSION_FILE" << 'JSONEOF'
{
  "supervisor": "2025.05.0",
  "dns": "2024.10.0",
  "audio": "2024.11.1",
  "cli": "2024.09.0",
  "multicast": "2024.02.0",
  "observer": "2024.02.0",
  "core": "doc-reg.three60.app/homeassistant/core:2025.5.0-custom"
}
JSONEOF
fi

# Verify version file is valid JSON
echo "Validating version-custom.json..."
if jq empty "$VERSION_FILE"; then
    echo "✓ Version file is valid JSON"
    echo "Contents:"
    cat "$VERSION_FILE"
else
    echo "✗ Version file is invalid JSON"
    exit 1
fi

echo "✓ Dependencies fixed successfully!"
