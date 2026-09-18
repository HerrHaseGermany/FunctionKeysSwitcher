#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$SCRIPT_DIR"

echo
echo "Updating FunctionKeysSwitcher..."
echo

if [ -d ".git" ]; then
    git pull --ff-only
fi

"$SCRIPT_DIR/install.sh"