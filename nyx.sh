#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCHER="$SCRIPT_DIR/scripts/nyx_launcher.py"

if [ ! -f "$LAUNCHER" ]; then
    echo "Error: nyx_launcher.py not found at $LAUNCHER"
    exit 1
fi

exec python3 "$LAUNCHER" "$@"
