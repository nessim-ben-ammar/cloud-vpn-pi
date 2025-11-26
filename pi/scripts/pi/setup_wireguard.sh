#!/bin/bash

# Script to setup WireGuard on Raspberry Pi
# This script runs ON the Pi (called by orchestrator)
# Expects config file to be at /etc/wireguard/wg0.conf

set -e

# Check if we're running on a Pi
if [ ! -f /proc/device-tree/model ] || ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    echo "❌ ERROR: This script should run on a Raspberry Pi!"
    echo "You're currently on a different system. Please run this script on the Pi."
    exit 1
fi

# Source centralized configuration
if [ -f "config.sh" ]; then
    source "config.sh"
else
    echo "❌ Configuration file 'config.sh' not found"
    echo "Please make sure config.sh exists in the current directory"
    exit 1
fi

# Determine which config to use
if [ $# -eq 0 ]; then
    LOCATION="$WG_DEFAULT_LOCATION"
    echo "ℹ️  No location provided, defaulting to '$LOCATION'"
else
    LOCATION="$1"
fi

CONFIGS_DIR=${WG_REMOTE_CONFIG_DIR/#\~/$HOME}
CONFIG_FROM_LOCATION="$CONFIGS_DIR/${LOCATION}.conf"

if [ -f "$1" ] && [[ "$1" == /* ]]; then
    CONFIG_FILE="$1"
    LOCATION=$(basename "$1" .conf)
elif [ -f "$CONFIG_FROM_LOCATION" ]; then
    CONFIG_FILE="$CONFIG_FROM_LOCATION"
else
    echo "Error: Configuration for location '$LOCATION' not found."
    echo "Looked for: $CONFIG_FROM_LOCATION"
    exit 1
fi

echo "Setting up WireGuard on Raspberry Pi..."

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found"
    exit 1
fi

echo "Using configuration file: $CONFIG_FILE"
echo "Configuring WireGuard..."

# Define paths
WG_CONF="/etc/wireguard/$WG_INTERFACE.conf"
WG_CONFIG_ARCHIVE="${WG_CONFIG_ARCHIVE:-/etc/wireguard/configs}"
WG_ACTIVE_LOCATION_FILE="${WG_ACTIVE_LOCATION_FILE:-/etc/wireguard/current_location}"

mkdir -p "$WG_CONFIG_ARCHIVE"

# Sync all known configs locally for future switching via the web UI
if compgen -G "$CONFIGS_DIR/*.conf" > /dev/null; then
    for conf in "$CONFIGS_DIR"/*.conf; do
        install -m 600 "$conf" "$WG_CONFIG_ARCHIVE/$(basename "$conf")"
    done
fi

# Create WireGuard directory and install the active configuration
mkdir -p /etc/wireguard
install -m 600 "$CONFIG_FILE" "$WG_CONFIG_ARCHIVE/${LOCATION}.conf"
install -m 600 "$CONFIG_FILE" "$WG_CONF"
echo "$LOCATION" > "$WG_ACTIVE_LOCATION_FILE"
chmod 600 "$WG_ACTIVE_LOCATION_FILE"

# Enable and start WireGuard service
systemctl enable wg-quick@$WG_INTERFACE
systemctl restart wg-quick@$WG_INTERFACE

echo "✅ WireGuard setup completed!"
echo ""
echo "WireGuard status:"
wg show
