#!/bin/bash

# PI SCRIPT - Deactivate VPN (wrapper for UI)
# Stops the VPN and restores normal routing. Returns JSON-friendly output.
# Usage: sudo ./deactivate_vpn.sh

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    printf '{"status":"error","code":1,"message":"must be run as root (sudo)"}\n'
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_PATH="$SCRIPT_DIR/config.sh"

if [ -f "$CONFIG_PATH" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_PATH"
fi

LOG_MSG=""

if bash "$SCRIPT_DIR/stop_vpn.sh" >/tmp/deactivate_vpn.out 2>&1; then
    LOG_MSG=$(sed -n '1,200p' /tmp/deactivate_vpn.out | sed ':a;N;$!ba;s/\n/\\n/g')
    printf '{"status":"ok","code":0,"message":"VPN deactivated","output":"%s"}\n' "$LOG_MSG"
    rm -f /tmp/deactivate_vpn.out
    exit 0
else
    LOG_MSG=$(sed -n '1,200p' /tmp/deactivate_vpn.out | sed ':a;N;$!ba;s/\n/\\n/g')
    printf '{"status":"error","code":2,"message":"failed to deactivate VPN","output":"%s"}\n' "$LOG_MSG"
    rm -f /tmp/deactivate_vpn.out
    exit 2
fi
