#!/bin/bash

# Home Assistant OS Background Build Script
# This script builds HAOS in the background and logs everything

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="/home/ploi/HomeAssistant/os"
LOG_FILE="${SCRIPT_DIR}/build-$(date +%Y%m%d-%H%M%S).log"
PID_FILE="${SCRIPT_DIR}/build.pid"
STATUS_FILE="${SCRIPT_DIR}/build.status"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to update status
update_status() {
    echo "$1" > "$STATUS_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] STATUS: $1" >> "$LOG_FILE"
}

# Function to cleanup on exit
cleanup() {
    log "Build process interrupted or completed"
    rm -f "$PID_FILE"
    if [ $? -eq 0 ]; then
        update_status "COMPLETED"
    else
        update_status "FAILED"
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Check if already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "Build is already running with PID $OLD_PID"
        echo "Log file: $LOG_FILE"
        echo "Use 'kill $OLD_PID' to stop it if needed"
        exit 1
    else
        echo "Removing stale PID file"
        rm -f "$PID_FILE"
    fi
fi

# Save our PID
echo $$ > "$PID_FILE"

# Start logging
log "=== Home Assistant OS Build Started ==="
log "Build script PID: $$"
log "Log file: $LOG_FILE"
log "Working directory: $SCRIPT_DIR"

update_status "STARTING"

# Change to the correct directory
cd "$SCRIPT_DIR" || {
    log "ERROR: Cannot change to directory $SCRIPT_DIR"
    exit 1
}

# Verify we're in the right place
if [ ! -f "scripts/enter.sh" ]; then
    log "ERROR: scripts/enter.sh not found. Are we in the correct directory?"
    exit 1
fi

log "Current directory: $(pwd)"
log "Contents: $(ls -la)"

update_status "CLEANING"

# Clean previous build if it exists
log "=== Cleaning previous build ==="
if [ -d "output_generic_x86_64" ]; then
    log "Removing existing output_generic_x86_64 directory..."
    sudo rm -rf output_generic_x86_64 2>&1 | tee -a "$LOG_FILE"
fi

update_status "BUILDING"

log "=== Starting Home Assistant OS Build ==="
log "This may take 30-90 minutes depending on your system..."

# Execute the build inside the container
# We use 'script' command to capture all output including colors and progress
log "Entering build container and starting build..."

sudo scripts/enter.sh bash -c "
    set -e
    echo '[$(date '+%Y-%m-%d %H:%M:%S')] Inside build container'
    echo '[$(date '+%Y-%m-%d %H:%M:%S')] Starting make command...'
    echo '[$(date '+%Y-%m-%d %H:%M:%S')] Build target: output_generic_x86_64 generic_x86_64'
    
    # Run the actual build
    make O=output_generic_x86_64 generic_x86_64
    
    echo '[$(date '+%Y-%m-%d %H:%M:%S')] Build completed successfully!'
" 2>&1 | tee -a "$LOG_FILE"

# Check if build was successful
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    log "=== Build completed successfully! ==="
    log "Output directory: $SCRIPT_DIR/output_generic_x86_64"
    
    # List the generated images
    if [ -d "output_generic_x86_64/images" ]; then
        log "Generated images:"
        ls -la "output_generic_x86_64/images/" | tee -a "$LOG_FILE"
    fi
    
    update_status "SUCCESS"
else
    log "=== Build failed! ==="
    update_status "FAILED"
    exit 1
fi

log "=== Build process finished ==="
