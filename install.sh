#!/bin/bash

set -e

APP_NAME="FunctionKeysSwitcher"
LABEL="de.raudzis.function-keys-switcher"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

INSTALL_DIR="$HOME/Library/Application Support/$APP_NAME"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_FILE="$HOME/Library/Logs/$APP_NAME.log"

SOURCE="$SCRIPT_DIR/src/function-keys-switcher.m"
DEFAULT_CONFIG="$SCRIPT_DIR/config/apps.conf"

BINARY="$INSTALL_DIR/function-keys-switcher"
CONFIG="$INSTALL_DIR/apps.conf"

echo
echo "Installing $APP_NAME..."
echo

# --------------------------------------------------
# Requirements
# --------------------------------------------------

if ! command -v clang >/dev/null 2>&1; then
    echo "Error: clang was not found."
    echo
    echo "Install Apple's Command Line Tools first:"
    echo
    echo "    xcode-select --install"
    echo
    exit 1
fi

if [ ! -f "$SOURCE" ]; then
    echo "Error: Source file not found:"
    echo "$SOURCE"
    exit 1
fi

# --------------------------------------------------
# Directories
# --------------------------------------------------

mkdir -p "$INSTALL_DIR"
mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$HOME/Library/Logs"

# --------------------------------------------------
# Stop existing service
# --------------------------------------------------

launchctl bootout \
    "gui/$(id -u)/$LABEL" \
    2>/dev/null || true

# --------------------------------------------------
# Compile
# --------------------------------------------------

echo "Compiling..."

clang \
    -fobjc-arc \
    -fblocks \
    -framework Cocoa \
    "$SOURCE" \
    -o "$BINARY"

chmod +x "$BINARY"

# --------------------------------------------------
# Configuration
# --------------------------------------------------

if [ ! -f "$CONFIG" ]; then

    echo "Installing default configuration..."

    cp "$DEFAULT_CONFIG" "$CONFIG"

else

    echo "Keeping existing configuration:"
    echo "$CONFIG"

fi

# --------------------------------------------------
# LaunchAgent
# --------------------------------------------------

echo "Installing LaunchAgent..."

cat > "$LAUNCH_AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>

    <key>Label</key>
    <string>$LABEL</string>

    <key>ProgramArguments</key>
    <array>
        <string>$BINARY</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>$LOG_FILE</string>

    <key>StandardErrorPath</key>
    <string>$LOG_FILE</string>

</dict>
</plist>
EOF

plutil -lint "$LAUNCH_AGENT"

# --------------------------------------------------
# Start
# --------------------------------------------------

echo "Starting service..."

launchctl bootstrap \
    "gui/$(id -u)" \
    "$LAUNCH_AGENT"

sleep 1

# --------------------------------------------------
# Status
# --------------------------------------------------

if launchctl print \
    "gui/$(id -u)/$LABEL" \
    >/dev/null 2>&1; then

    echo
    echo "$APP_NAME installed successfully."
    echo
    echo "Configuration:"
    echo "  $CONFIG"
    echo
    echo "Log:"
    echo "  $LOG_FILE"
    echo

else

    echo
    echo "Error: LaunchAgent did not start."
    exit 1

fi