#!/bin/bash

# PI SCRIPT - Pi VPN Gateway Setup Orchestrator
# This script runs ON the PI to orchestrate the entire setup process
# Usage: ./setup_pi.sh

set -e

# Source centralized configuration
if [ -f "config.sh" ]; then
    source "config.sh"
else
    echo "❌ Configuration file 'config.sh' not found"
    echo "Please make sure config.sh exists in the current directory"
    exit 1
fi

# Check if we're running on a Pi
if [ ! -f /proc/device-tree/model ] || ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    echo "❌ ERROR: This script should run on a Raspberry Pi!"
    echo "You're currently on a different system. Please run this script on the Pi."
    exit 1
fi

# Check if we're running as root/sudo
if [ "$EUID" -ne 0 ]; then
    echo "❌ ERROR: This script must be run as root (with sudo)"
    echo "Usage: sudo ./setup_pi.sh"
    exit 1
fi

echo "🚀 Starting Pi VPN Gateway setup..."
echo "==================================="
echo ""

./install_packages.sh
./setup_fail2ban.sh
./setup_wireguard.sh "$WG_CONFIG_DEST"
./setup_gateway.sh
./setup_dnsmasq.sh

echo ""
echo "✅ Setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Access your router's admin panel"
echo "2. Set the router DNS server to $PI_IP so clients use the Pi for DNS"
echo "3. Apply/restart router settings so leases pick up the new DNS server"