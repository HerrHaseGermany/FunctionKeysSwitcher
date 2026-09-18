#!/bin/bash

set -e

APP_NAME="FunctionKeysSwitcher"
LABEL="de.raudzis.function-keys-switcher"

INSTALL_DIR="$HOME/Library/Application Support/$APP_NAME"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"

BINARY="$INSTALL_DIR/function-keys-switcher"

echo
echo "Uninstalling $APP_NAME..."
echo

launchctl bootout \
    "gui/$(id -u)/$LABEL" \
    2>/dev/null || true

rm -f "$LAUNCH_AGENT"
rm -f "$BINARY"

echo
echo "$APP_NAME has been uninstalled."
echo
echo "Your configuration was kept at:"
echo
echo "  $INSTALL_DIR/apps.conf"
echo
echo "Delete that file manually if you no longer need it."
echo