# Home Assistant OS Custom Core Integration - Progress Log

## Problem Analysis
- **Issue Identified**: Home Assistant Supervisor ignores pre-built custom core containers and always downloads from ghcr.io registry, overriding custom modifications.

## Initial Attempts & Diagnosis
- **Build System Working**: Confirmed custom core (3.9GB) successfully downloads and saves as `core_2025.6.1.tar` during build process.
- **Supervisor Behavior**: Discovered supervisor hardcoded to look for `ghcr.io/home-assistant/generic-x86-64-homeassistant:2025.6.1` and ignores any other naming.
- **Observer Log Analysis**: Confirmed supervisor downloads fresh image despite pre-built containers being available in data partition.

## Core Integration Strategy
- **Container Name Mapping**: Modified fetch script to tag custom core with supervisor-expected name `ghcr.io/home-assistant/generic-x86-64-homeassistant:2025.6.1`.
- **Version Configuration**: Updated `version-custom.json` to use standard version `2025.6.1` instead of custom suffixes.
- **Preload System**: Created systemd service to load containers into Docker before supervisor starts.

## Build System Fixes
- **Fetch Script Enhancement**: Added logic to pull custom core from `doc-reg.three60.app` and tag with supervisor-expected names.
- **Data Partition Optimization**: Created container preloading system that copies all containers to `/docker/preload/` directory.
- **Registry Authentication**: Configured Docker authentication for custom registry access during build and runtime.

## Infrastructure Setup
- **Systemd Service**: Created `hassio-preload-containers.service` to run before supervisor and load pre-built containers.
- **Preload Script**: Developed `/usr/bin/hassio-preload-containers.sh` to load containers and tag custom core appropriately.
- **Directory Structure**: Established proper data partition layout for container preloading and supervisor configuration.

## Size & Space Optimization
- **Disk Space Crisis**: Resolved "No space left on device" error when copying 3.9GB custom core during build.
- **Partition Size Increase**: Expanded data partition from 6GB to 12GB (`DATA_SIZE=12288M`).
- **Total Disk Expansion**: Increased total disk image from 10GB to 18GB (`DISK_SIZE=18G`).
- **Container Handling**: Optimized to move containers instead of copying to save space during build process.

## Configuration Synchronization
- **Genimage Compatibility**: Fixed partition size mismatch between configured and actual data partition sizes.
- **Build Script Updates**: Updated `hdd-image.sh` and board meta files to match new partition sizes.
- **Systemd Integration**: Resolved systemd preset conflicts by removing manual symlinks and adding proper preset files.

## Current Status
- **Build Ready**: All disk space and configuration issues resolved for successful build completion.
- **Integration Complete**: Custom core will be preloaded with supervisor-expected names, preventing internet downloads.
- **Deployment Prepared**: 18GB image with 12GB data partition optimized for 3.9GB custom core and additional containers.
