#!/bin/bash

echo "=== Verifying Custom Home Assistant OS Build Prerequisites ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# Function to check file exists
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} Found: $1"
        return 0
    else
        echo -e "${RED}✗${NC} Missing: $1"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# Function to check directory exists
check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} Directory exists: $1"
        return 0
    else
        echo -e "${RED}✗${NC} Directory missing: $1"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

echo "1. Checking Custom Frontend Build..."
check_dir "~/HomeAssistant/front/hass_frontend"
if [ -d ~/HomeAssistant/front/hass_frontend ]; then
    echo "   Frontend files count: $(find ~/HomeAssistant/front/hass_frontend -type f | wc -l)"
fi

echo -e "\n2. Checking Custom Core Distribution..."
check_dir "~/HomeAssistant/core/dist"
check_file "~/HomeAssistant/core/dist/homeassistant-2025.5.0.dev0-py3-none-any.whl"
check_file "~/HomeAssistant/core/dist/homeassistant-2025.5.0.dev0.tar.gz"

echo -e "\n3. Checking Custom Core Integration..."
check_file "~/HomeAssistant/core/homeassistant/components/frontend/custom_static/index.html"
if [ -d ~/HomeAssistant/core/homeassistant/components/frontend/custom_static ]; then
    echo "   Custom static files count: $(find ~/HomeAssistant/core/homeassistant/components/frontend/custom_static -type f | wc -l)"
fi

echo -e "\n4. Checking OS Build Configuration..."
check_dir "~/HomeAssistant/os/buildroot-external/package/homeassistant-custom"
check_file "~/HomeAssistant/os/buildroot-external/package/homeassistant-custom/homeassistant-custom.mk"
check_file "~/HomeAssistant/os/buildroot-external/package/homeassistant-custom/Config.in"
check_file "~/HomeAssistant/os/buildroot-external/scripts/post-build-custom.sh"

echo -e "\n5. Checking Package Configuration..."
if grep -q "BR2_PACKAGE_HOMEASSISTANT_CUSTOM=y" ~/HomeAssistant/os/buildroot-external/configs/generic_x86_64_defconfig; then
    echo -e "${GREEN}✓${NC} Custom package enabled in generic_x86_64_defconfig"
else
    echo -e "${RED}✗${NC} Custom package not enabled in generic_x86_64_defconfig"
    ERRORS=$((ERRORS + 1))
fi

if grep -q "homeassistant-custom/Config.in" ~/HomeAssistant/os/buildroot-external/Config.in; then
    echo -e "${GREEN}✓${NC} Custom package registered in main Config.in"
else
    echo -e "${RED}✗${NC} Custom package not registered in main Config.in"
    ERRORS=$((ERRORS + 1))
fi

echo -e "\n6. Checking Build Environment..."
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker is available"
    if docker ps &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker daemon is running"
    else
        echo -e "${RED}✗${NC} Docker daemon is not running"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗${NC} Docker is not installed"
    ERRORS=$((ERRORS + 1))
fi

echo -e "\n=== Verification Summary ==="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All prerequisites met! Ready to build.${NC}"
    exit 0
else
    echo -e "${RED}✗ Found $ERRORS issues. Please fix them before building.${NC}"
    exit 1
fi
