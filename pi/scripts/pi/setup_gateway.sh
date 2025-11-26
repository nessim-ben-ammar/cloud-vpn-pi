#!/bin/bash

# Script to setup Raspberry Pi as Internet Gateway
# This script runs ON the Pi (called by orchestrator)
# Usage: ./setup_gateway.sh

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

echo "Setting up Raspberry Pi as Internet Gateway..."
echo "This will configure the Pi to route all network traffic through the VPN"
echo ""

echo "Configuring Pi as Internet Gateway..."

# Check if WireGuard configuration exists
if [ ! -f "/etc/wireguard/$WG_INTERFACE.conf" ]; then
    echo "⚠️  WireGuard configuration not found. Continuing without activating VPN."
    echo "The gateway will be prepared but the VPN interface and NAT rules will be applied only when a WireGuard config is activated via the web UI or the restore service."
    WG_CONF_PRESENT=0
else
    WG_CONF_PRESENT=1
fi

# 1. Enable IP forwarding (runtime)
echo "📡 Enabling IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward

# 2. Make IP forwarding persistent
echo "💾 Making IP forwarding persistent..."
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo "Added IP forwarding to /etc/sysctl.conf"
else
    echo "IP forwarding already configured in /etc/sysctl.conf"
fi

# 3. Clear all iptables rules for clean slate
echo "🧹 Clearing all iptables rules..."
iptables -t nat -F
iptables -t filter -F
iptables -t mangle -F
iptables -X 2>/dev/null || true
echo "✅ iptables cleared"

if [ "$WG_CONF_PRESENT" -eq 1 ]; then
    # 4. Stop and restart WireGuard for fresh start
    echo "🔄 Restarting WireGuard for clean setup..."
    systemctl stop wg-quick@$WG_INTERFACE 2>/dev/null || true
    systemctl start wg-quick@$WG_INTERFACE
    echo "✅ WireGuard restarted"

    # 5. Configure gateway iptables rules
    echo "🔥 Configuring gateway iptables rules..."

    # NAT rule - masquerade traffic going out through VPN
    iptables -t nat -A POSTROUTING -o $WG_INTERFACE -j MASQUERADE

    # Forward traffic from LAN to VPN
    iptables -A FORWARD -i $LAN_INTERFACE -o $WG_INTERFACE -j ACCEPT

    # Allow established connections back from VPN to LAN
    iptables -A FORWARD -i $WG_INTERFACE -o $LAN_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT

    echo "✅ Gateway iptables rules configured"

    # 6. Save iptables rules persistently
    echo "💾 Saving iptables rules..."
    if command -v iptables-save >/dev/null 2>&1; then
        iptables-save > /etc/iptables/rules.v4
        echo "✅ iptables rules saved to /etc/iptables/rules.v4"
    else
        echo "⚠️  Warning: iptables-save not found, rules may not persist after reboot"
    fi
else
    echo "⚠️  Skipping WireGuard restart and NAT/forward rules because $WG_INTERFACE config is missing."
    echo "These will be applied when a config is activated from the web UI or during restore after reboot."
fi

# 7. Verify configuration
echo ""
echo "🔍 Verifying configuration..."
echo "IP forwarding: $(cat /proc/sys/net/ipv4/ip_forward)"
echo ""
echo "NAT rules:"
iptables -t nat -L POSTROUTING -v --line-numbers || true
echo ""
echo "FORWARD rules:"
iptables -L FORWARD -v --line-numbers || true
echo ""
echo "WireGuard interface status:"
ip addr show $WG_INTERFACE | grep -E "(inet|state)" || echo "No $WG_INTERFACE interface info"

echo ""
echo "✅ Gateway setup completed!"
