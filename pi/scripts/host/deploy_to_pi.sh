#!/bin/bash

# HOST SCRIPT - Deploy and run Pi VPN Gateway setup
# This script runs ON the HOST and deploys scripts to Pi
# Usage: ./deploy_to_pi.sh

set -e

# Check if we're accidentally running on Pi
if [ -f /proc/device-tree/model ] && grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    echo "❌ ERROR: This script should run on the HOST, not on the Pi!"
    echo "You're currently on a Raspberry Pi. Please run this script from your host machine."
    exit 1
fi

# Source centralized configuration
if [ -f "../config.sh" ]; then
    source "../config.sh"
    KEY="$SSH_KEY"
    USER="$SSH_USER"
    HOST="$SSH_HOST"
    PORT="$SSH_PORT"
else
    echo "❌ Configuration file '../config.sh' not found"
    echo "Please make sure config.sh exists in the scripts directory"
    exit 1
fi

echo "🚀 Deploying Pi VPN Gateway setup to Pi..."
echo "==========================================="
echo ""

# Check SSH connectivity
echo "🔧 Checking SSH connection to Pi..."
if [ ! -f "$KEY" ]; then
    echo "❌ SSH key '$KEY' not found"
    exit 1
fi

if ! ssh -i "$KEY" -p "$PORT" -o ConnectTimeout=5 -o BatchMode=yes "$USER@$HOST" exit 2>/dev/null; then
    echo "❌ Cannot connect to Pi at $HOST"
    exit 1
fi
echo "✅ SSH connection successful"
echo ""

# Create permanent scripts directory on Pi
echo "🔧 Creating scripts directory on Pi..."
ssh -i "$KEY" -p "$PORT" "$USER@$HOST" "mkdir -p ~/scripts"

# Copy all pi scripts and config to Pi
echo "🔧 Copying scripts and config to Pi..."
scp -i "$KEY" -P "$PORT" ../pi/*.sh ../config.sh "$USER@$HOST:~/scripts/"
ssh -i "$KEY" -p "$PORT" "$USER@$HOST" "chmod +x ~/scripts/*.sh"

# Check if WireGuard config file exists
if [ -f "$WG_CONFIG_SOURCE" ]; then
    echo "🔧 Copying WireGuard config to Pi..."
    scp -i "$KEY" -P "$PORT" "$WG_CONFIG_SOURCE" "$USER@$HOST:~/"
    ssh -i "$KEY" -p "$PORT" "$USER@$HOST" "sudo mkdir -p /etc/wireguard && sudo mv ~/$(basename $WG_CONFIG_SOURCE) $WG_CONFIG_DEST"
else
    echo "⚠️  WireGuard config not found at $WG_CONFIG_SOURCE"
    echo "Please place your WireGuard config file there first"
    exit 1
fi

# Execute setup on Pi
echo "🔧 Executing setup on Pi..."
echo ""
ssh -i "$KEY" -p "$PORT" "$USER@$HOST" "cd ~/scripts && sudo bash setup_pi.sh"

echo ""
echo "✅ Pi VPN Gateway setup completed successfully!"
echo ""
echo "Scripts are now permanently installed at ~/scripts on the Pi"
echo ""
echo "Next steps:"
echo "1. Access your router's admin panel"
echo "2. Disable the router's DHCP server to avoid conflicts"
echo "3. Connect clients so they lease from the Pi (gateway + DNS)"
echo "4. Reboot clients if they keep old DHCP leases"
