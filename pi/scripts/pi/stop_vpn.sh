#!/bin/bash

# PI SCRIPT - Switch Pi gateway from VPN to normal internet
# This script runs ON the PI to switch from VPN routing to normal internet
# Pi remains as DNS server and internet gateway, but traffic goes directly to internet
# Usage: sudo ./stop_vpn.sh

set -euo pipefail

# Check if we're running as root/sudo
if [ "$EUID" -ne 0 ]; then
    echo "❌ ERROR: This script must be run as root (with sudo)"
    echo "Usage: sudo ./stop_vpn.sh"
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

DNSMASQ_CONF="/etc/dnsmasq.conf"
UPSTREAM_DNS="${UPSTREAM_DNS_SERVER:-8.8.8.8}"

echo "🔧 Switching Pi gateway from VPN to normal internet..."
echo "====================================================="
echo ""

# 1. Stop and disable WireGuard
echo "🛑 Stopping WireGuard service..."
if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
    systemctl stop wg-quick@$WG_INTERFACE
    echo "✅ WireGuard service stopped"
else
    echo "ℹ️  WireGuard service was not running"
fi

if systemctl is-enabled --quiet wg-quick@$WG_INTERFACE; then
    systemctl disable wg-quick@$WG_INTERFACE
    echo "✅ WireGuard service disabled"
else
    echo "ℹ️  WireGuard service was not enabled"
fi

# 2. Fix iptables: change from VPN routing to direct internet routing
echo "🔄 Updating iptables for direct internet routing..."
iptables -t nat -F POSTROUTING
iptables -t nat -A POSTROUTING -o $LAN_INTERFACE -j MASQUERADE
echo "✅ iptables updated for direct internet routing"

echo "inactive" > "${WG_STATE_FILE:-/etc/wireguard/state}"
chmod 600 "${WG_STATE_FILE:-/etc/wireguard/state}"

# 3. Update dnsmasq DNS to use normal internet DNS
echo "🔄 Updating dnsmasq DNS to normal internet..."
if grep -q "^server=" "$DNSMASQ_CONF"; then
    # Replace the first server= line to avoid duplicates
    sed -i "0,/^server=.*/{s#^server=.*#server=$UPSTREAM_DNS#}" "$DNSMASQ_CONF"
else
    echo "server=$UPSTREAM_DNS" >> "$DNSMASQ_CONF"
fi
systemctl restart dnsmasq
echo "✅ dnsmasq updated to use upstream DNS $UPSTREAM_DNS"

# 4. Save iptables rules
echo "💾 Saving iptables rules..."
if command -v iptables-save >/dev/null 2>&1; then
    iptables-save > /etc/iptables/rules.v4
    echo "✅ iptables rules saved"
else
    echo "⚠️  Warning: iptables-save not found, rules may not persist after reboot"
fi

# 5. Verify
echo ""
echo "🔍 Verifying configuration..."
echo "IP forwarding: $(cat /proc/sys/net/ipv4/ip_forward)"
echo ""
echo "Current NAT rules:"
iptables -t nat -L POSTROUTING -v --line-numbers
echo ""
echo "Testing internet connectivity..."
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "✅ Internet connectivity working!"
else
    echo "⚠️  Internet connectivity test failed"
fi

echo ""
echo "✅ VPN stopped! Pi gateway now routes traffic directly to internet."
echo ""
echo "The Pi continues to serve as:"
echo "- DNS server for your network"
echo "- Internet gateway for all devices"
echo "- DNS server using upstream resolver ($UPSTREAM_DNS)"
echo ""
echo "To re-enable VPN mode, run: ./start_vpn.sh or use the web UI"
