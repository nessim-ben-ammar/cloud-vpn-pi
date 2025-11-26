#!/bin/bash

# PI SCRIPT - Switch Pi gateway from normal internet to VPN
# This script runs ON the PI to switch gateway routing to go through the VPN
# Usage: sudo ./start_vpn.sh

set -e

# Check if we're running as root/sudo
if [ "$EUID" -ne 0 ]; then
    echo "❌ ERROR: This script must be run as root (with sudo)"
    echo "Usage: sudo ./start_vpn.sh"
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

if [ ! -f "/etc/wireguard/$WG_INTERFACE.conf" ]; then
    echo "❌ Active WireGuard config '/etc/wireguard/$WG_INTERFACE.conf' not found"
    echo "Select a location via the web UI before starting the VPN."
    exit 1
fi

echo "🔧 Starting WireGuard VPN..."
systemctl enable wg-quick@$WG_INTERFACE
systemctl start wg-quick@$WG_INTERFACE

echo "🔄 Updating iptables for VPN routing..."
iptables -t nat -F POSTROUTING
iptables -t nat -A POSTROUTING -o $WG_INTERFACE -j MASQUERADE

echo "✅ VPN started! Pi gateway now routes traffic through the VPN."

echo "Current NAT rules:"
iptables -t nat -L POSTROUTING -v --line-numbers

echo "WireGuard status:"
wg show

echo "active" > "${WG_STATE_FILE:-/etc/wireguard/state}"
chmod 600 "${WG_STATE_FILE:-/etc/wireguard/state}"
