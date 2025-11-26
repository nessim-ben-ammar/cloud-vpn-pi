#!/bin/bash

# PI SCRIPT - Activate VPN (wrapper for UI)
# Installs the selected WireGuard config and activates VPN routing.
# Usage: sudo ./activate_vpn.sh <location>

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Error: this script must be run as root (sudo)" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_PATH="$SCRIPT_DIR/config.sh"

if [ -f "$CONFIG_PATH" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_PATH"
else
    echo "Error: config.sh not found" >&2
    exit 1
fi

if [ $# -lt 1 ]; then
    echo "Usage: $0 <location>" >&2
    exit 1
fi

LOCATION="$1"

WG_CONFIG_ARCHIVE="${WG_CONFIG_ARCHIVE:-/etc/wireguard/configs}"
WG_REMOTE_CONFIG_DIR="${WG_REMOTE_CONFIG_DIR:-/home/pi/wireguard-configs}"

# Prefer archived config, then remote configs dir
if [ -f "$WG_CONFIG_ARCHIVE/${LOCATION}.conf" ]; then
    CONFIG_FILE="$WG_CONFIG_ARCHIVE/${LOCATION}.conf"
elif [ -f "$WG_REMOTE_CONFIG_DIR/${LOCATION}.conf" ]; then
    CONFIG_FILE="$WG_REMOTE_CONFIG_DIR/${LOCATION}.conf"
else
    echo "Error: configuration for location '$LOCATION' not found" >&2
    exit 2
fi

echo "Activating VPN for location: $LOCATION"

# Install the config and make it the active config
if ! bash "$SCRIPT_DIR/setup_wireguard.sh" "$LOCATION"; then
    echo "Error: failed to install WireGuard config for $LOCATION" >&2
    exit 3
fi

# Start VPN (this applies NAT/iptables rules)
if ! bash "$SCRIPT_DIR/start_vpn.sh"; then
    echo "Error: failed to start VPN for $LOCATION" >&2
    exit 4
fi

echo "OK: VPN activated for $LOCATION"
exit 0
