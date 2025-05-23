#!/bin/bash

# Home Assistant OS Build Monitor Script
# Use this to check the status of the background build

SCRIPT_DIR="/home/ploi/HomeAssistant/os"
PID_FILE="${SCRIPT_DIR}/build.pid"
STATUS_FILE="${SCRIPT_DIR}/build.status"

# Function to get the latest log file
get_latest_log() {
    ls -t "${SCRIPT_DIR}"/build-*.log 2>/dev/null | head -1
}

# Function to show usage
show_usage() {
    echo "Home Assistant OS Build Monitor"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status     - Show current build status"
    echo "  log        - Show last 50 lines of build log"
    echo "  tail       - Follow the build log in real-time"
    echo "  stop       - Stop the running build"
    echo "  clean      - Clean up old log files and status"
    echo "  logs       - List all available log files"
    echo ""
    echo "Examples:"
    echo "  $0 status              # Check if build is running"
    echo "  $0 log                 # Show last 50 lines"
    echo "  $0 tail                # Follow log in real-time"
    echo "  $0 stop                # Stop current build"
}

# Function to check if build is running
check_status() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "✓ Build is RUNNING (PID: $PID)"
            
            if [ -f "$STATUS_FILE" ]; then
                STATUS=$(cat "$STATUS_FILE")
                echo "  Current status: $STATUS"
            fi
            
            # Show some system info
            echo "  Build started: $(ps -o lstart= -p "$PID" 2>/dev/null || echo 'Unknown')"
            echo "  CPU usage: $(ps -o %cpu= -p "$PID" 2>/dev/null || echo 'Unknown')%"
            echo "  Memory usage: $(ps -o %mem= -p "$PID" 2>/dev/null || echo 'Unknown')%"
            
            return 0
        else
            echo "✗ Build process not running (stale PID file)"
            rm -f "$PID_FILE"
            return 1
        fi
    else
        echo "✗ No build currently running"
        
        if [ -f "$STATUS_FILE" ]; then
            STATUS=$(cat "$STATUS_FILE")
            echo "  Last status: $STATUS"
        fi
        
        return 1
    fi
}

# Function to show last lines of log
show_log() {
    local lines=${1:-50}
    local log_file=$(get_latest_log)
    
    if [ -n "$log_file" ] && [ -f "$log_file" ]; then
        echo "=== Last $lines lines from: $(basename "$log_file") ==="
        tail -n "$lines" "$log_file"
    else
        echo "No log file found"
    fi
}

# Function to follow log in real-time
follow_log() {
    local log_file=$(get_latest_log)
    
    if [ -n "$log_file" ] && [ -f "$log_file" ]; then
        echo "=== Following log: $(basename "$log_file") ==="
        echo "Press Ctrl+C to stop following"
        tail -f "$log_file"
    else
        echo "No log file found to follow"
    fi
}

# Function to stop build
stop_build() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "Stopping build process (PID: $PID)..."
            kill "$PID"
            sleep 2
            
            if ps -p "$PID" > /dev/null 2>&1; then
                echo "Process still running, force killing..."
                kill -9 "$PID"
            fi
            
            echo "Build stopped"
            rm -f "$PID_FILE"
            echo "STOPPED" > "$STATUS_FILE"
        else
            echo "Build process not running"
            rm -f "$PID_FILE"
        fi
    else
        echo "No build process to stop"
    fi
}

# Function to clean up
clean_up() {
    echo "Cleaning up old files..."
    
    # Remove PID file if process is not running
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ! ps -p "$PID" > /dev/null 2>&1; then
            rm -f "$PID_FILE"
            echo "Removed stale PID file"
        fi
    fi
    
    # List log files older than 7 days
    find "${SCRIPT_DIR}" -name "build-*.log" -mtime +7 2>/dev/null | while read old_log; do
        echo "Would remove old log: $(basename "$old_log")"
        echo "Run 'rm \"$old_log\"' to delete it"
    done
}

# Function to list all log files
list_logs() {
    echo "Available log files:"
    ls -la "${SCRIPT_DIR}"/build-*.log 2>/dev/null | while read line; do
        echo "  $line"
    done
}

# Main script logic
case "${1:-status}" in
    "status")
        check_status
        ;;
    "log")
        show_log "${2:-50}"
        ;;
    "tail")
        follow_log
        ;;
    "stop")
        stop_build
        ;;
    "clean")
        clean_up
        ;;
    "logs")
        list_logs
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        echo "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
