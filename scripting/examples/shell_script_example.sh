#!/bin/bash
# Shell Script Example for RUI Scripting
# This demonstrates how to control a RUI app from a bash script
#
# Usage: ./shell_script_example.sh /path/to/rui/app

APP_DIR="${1:-.}"  # Use first argument or current directory
COMMAND_FILE="$APP_DIR/commands.txt"
RESPONSE_FILE="$APP_DIR/responses.txt"
LOCK_FILE="$APP_DIR/.lock"

# Wait for app to be ready (no lock file)
wait_for_app() {
    while [ -f "$LOCK_FILE" ]; do
        sleep 0.1
    done
}

# Send command and wait for response
send_command() {
    local id=$1
    local selector=$2
    local command=$3
    local value=$4

    # Build command line
    local line="$id $selector $command"
    if [ -n "$value" ]; then
        line="$line $value"
    fi

    # Delete old response file
    rm -f "$RESPONSE_FILE"

    # Write command
    echo "$line" > "$COMMAND_FILE"

    # Wait for lock to appear
    while [ ! -f "$LOCK_FILE" ]; do
        sleep 0.05
    done

    # Wait for lock to disappear (processing complete)
    while [ -f "$LOCK_FILE" ]; do
        sleep 0.05
    done

    # Read response
    sleep 0.05  # Small delay to ensure file is written
    if [ -f "$RESPONSE_FILE" ]; then
        cat "$RESPONSE_FILE"
    else
        echo "No response"
    fi
}

# Main script
echo "RUI App Automation via Shell Script"
echo "App directory: $APP_DIR"
echo ""

wait_for_app

# Test 1: Fill in username
echo "Setting username..."
response=$(send_command 1 "usernameInput" "write" "testuser")
echo "Response: $response"
echo ""

wait_for_app

# Test 2: Fill in password
echo "Setting password..."
response=$(send_command 2 "passwordInput" "write" "password123")
echo "Response: $response"
echo ""

wait_for_app

# Test 3: Click login button
echo "Clicking login button..."
response=$(send_command 3 "loginButton" "invoke")
echo "Response: $response"
echo ""

wait_for_app
sleep 1  # Wait for login to process

# Test 4: Check status
echo "Checking login status..."
response=$(send_command 4 "statusLabel" "read")
echo "Status: $response"
echo ""

wait_for_app

# Test 5: List form widgets
echo "Listing form widgets..."
response=$(send_command 5 "loginForm/*" "read")
echo "Widgets: $response"
echo ""

echo "Done!"
