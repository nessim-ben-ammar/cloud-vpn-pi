#!/bin/bash

# PI SCRIPT - Install necessary packages on Raspberry Pi for VPN client functionality
# This script runs ON the Pi (called by orchestrator)

set -e

# Check if we're running on a Pi
if [ ! -f /proc/device-tree/model ] || ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    echo "❌ ERROR: This script should run on a Raspberry Pi!"
    echo "You're currently on a different system. Please run this script on the Pi."
    exit 1
fi

echo "Starting package installation on Raspberry Pi..."

# Update package lists
echo "Updating package lists..."
apt update

# Upgrade existing packages
echo "Upgrading existing packages..."
apt upgrade -y

# Install essential packages for VPN client functionality
echo "🔧 Installing packages..."
apt install -y \
    wireguard \
    iptables-persistent \
    fail2ban \
    resolvconf \
    dnsmasq \
    unbound

# Clean up
echo "🧹 Cleaning up..."
apt autoremove -y
apt autoclean

echo "✅ Package installation completed successfully!"