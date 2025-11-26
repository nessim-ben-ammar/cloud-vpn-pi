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

# Determine which config to use (if any)
ACTIVATE_LOCATION=""
if [ $# -gt 0 ]; then
    ACTIVATE_LOCATION="$1"
fi

CONFIGS_DIR=${WG_REMOTE_CONFIG_DIR/#\~/$HOME}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Setting up WireGuard on Raspberry Pi..."
echo "Copying available configs from $CONFIGS_DIR (expected format: <location>-<device>.conf)"

# Define paths
WG_CONF="/etc/wireguard/$WG_INTERFACE.conf"
WG_CONFIG_ARCHIVE="${WG_CONFIG_ARCHIVE:-/etc/wireguard/configs}"
WG_ACTIVE_LOCATION_FILE="${WG_ACTIVE_LOCATION_FILE:-/etc/wireguard/current_location}"
WG_STATE_FILE="${WG_STATE_FILE:-/etc/wireguard/state}"
RESTORE_SERVICE="/etc/systemd/system/vpn-state-restore.service"

mkdir -p "$WG_CONFIG_ARCHIVE"
mkdir -p /etc/wireguard

# Sync all known configs locally for future switching via the web UI
if compgen -G "$CONFIGS_DIR/*.conf" > /dev/null; then
    for conf in "$CONFIGS_DIR"/*.conf; do
        install -m 600 "$conf" "$WG_CONFIG_ARCHIVE/$(basename "$conf")"
    done
else
    echo "⚠️  No WireGuard configs found in $CONFIGS_DIR"
fi

echo "" > "$WG_ACTIVE_LOCATION_FILE"
chmod 600 "$WG_ACTIVE_LOCATION_FILE"
echo "inactive" > "$WG_STATE_FILE"
chmod 600 "$WG_STATE_FILE"

if [ -n "$ACTIVATE_LOCATION" ]; then
    CONFIG_FILE="$CONFIGS_DIR/${ACTIVATE_LOCATION}.conf"

    if [ -f "$ACTIVATE_LOCATION" ] && [[ "$ACTIVATE_LOCATION" == /* ]]; then
        CONFIG_FILE="$ACTIVATE_LOCATION"
        ACTIVATE_LOCATION=$(basename "$ACTIVATE_LOCATION" .conf)
    elif [ ! -f "$CONFIG_FILE" ] && [ -f "$WG_CONFIG_ARCHIVE/${ACTIVATE_LOCATION}.conf" ]; then
        CONFIG_FILE="$WG_CONFIG_ARCHIVE/${ACTIVATE_LOCATION}.conf"
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Configuration for '$ACTIVATE_LOCATION' not found."
        exit 1
    fi

    install -m 600 "$CONFIG_FILE" "$WG_CONFIG_ARCHIVE/$(basename "$CONFIG_FILE")"
    install -m 600 "$CONFIG_FILE" "$WG_CONF"
    echo "$ACTIVATE_LOCATION" > "$WG_ACTIVE_LOCATION_FILE"
    chmod 600 "$WG_ACTIVE_LOCATION_FILE"
    echo "active" > "$WG_STATE_FILE"
    chmod 600 "$WG_STATE_FILE"

    systemctl enable wg-quick@$WG_INTERFACE
    systemctl restart wg-quick@$WG_INTERFACE
else
    systemctl disable --now wg-quick@$WG_INTERFACE >/dev/null 2>&1 || true
    rm -f "$WG_CONF"
fi

cat > "$RESTORE_SERVICE" <<EOF
[Unit]
Description=Restore WireGuard VPN state
After=network.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_DIR/restore_vpn_state.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vpn-state-restore.service

echo "✅ WireGuard setup completed!"
echo ""
echo "WireGuard status:"
wg show || true
