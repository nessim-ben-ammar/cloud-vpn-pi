#!/bin/bash

# PI SCRIPT - Restore VPN state on boot
# This script runs ON the PI to re-apply the last requested VPN state

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_PATH="$SCRIPT_DIR/config.sh"

if [ -f "$CONFIG_PATH" ]; then
    source "$CONFIG_PATH"
fi

WG_INTERFACE=${WG_INTERFACE:-wg0}
WG_STATE_FILE=${WG_STATE_FILE:-/etc/wireguard/state}

STATE="inactive"
if [ -f "$WG_STATE_FILE" ]; then
    STATE="$(cat "$WG_STATE_FILE")"
fi

if [ "$STATE" = "active" ]; then
    set +e
    bash "$SCRIPT_DIR/start_vpn.sh"
    RESULT=$?
    set -e

    if [ $RESULT -ne 0 ]; then
        echo "⚠️  Failed to restore active VPN state; leaving VPN disabled"
        echo "inactive" > "$WG_STATE_FILE"
        chmod 600 "$WG_STATE_FILE"
        bash "$SCRIPT_DIR/stop_vpn.sh"
    fi
else
    bash "$SCRIPT_DIR/stop_vpn.sh"
fi
