#!/bin/bash

# HOST SCRIPT - Switch Pi gateway from VPN to normal internet remotely
# This script runs ON the HOST to switch Pi from VPN routing to normal internet
# Pi remains as DNS server and internet gateway, but traffic goes directly to internet
# Usage: ./stop_vpn_remote.sh

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

echo "🔧 Switching Pi gateway from VPN to normal internet remotely..."
echo "=============================================================="
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

# Copy restore script to Pi if it doesn't exist
echo "🔧 Copying stop VPN script to Pi..."
scp -i "$KEY" -P "$PORT" ../pi/stop_vpn.sh "$USER@$HOST:~/scripts/"
ssh -i "$KEY" -p "$PORT" "$USER@$HOST" "chmod +x ~/scripts/stop_vpn.sh"

# Execute restore on Pi
echo "🔧 Executing Pi gateway switch on Pi..."
echo ""
ssh -i "$KEY" -p "$PORT" "$USER@$HOST" "cd ~/scripts && sudo bash stop_vpn.sh"

echo ""
echo "✅ Pi gateway switch completed successfully!"
echo ""
echo "The Pi will continue to serve as DNS server and internet gateway."
echo "All network traffic now goes directly to the internet (no VPN)."
echo ""
echo "If you still have connectivity issues:"
echo "1. Confirm clients are using the Pi for DNS"
echo "2. Restart the Pi: ssh -i $KEY -p $PORT $USER@$HOST 'sudo reboot'"
echo "3. Wait a few minutes for network services to stabilize"
echo ""
echo "To re-enable VPN mode later, run:"
echo "  ./deploy_to_pi.sh"
