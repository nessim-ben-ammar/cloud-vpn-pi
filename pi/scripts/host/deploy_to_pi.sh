#!/bin/bash

# HOST SCRIPT - Deploy and run Pi VPN Gateway setup
# This script runs ON the HOST and deploys scripts to Pi
# Usage: ./deploy_to_pi.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PI_DIR="$SCRIPT_DIR/.."
PI_PI_DIR="$PI_DIR/pi"
CONFIG_PATH="$PI_DIR/config.sh"
WEB_DIR="$PI_DIR/../web"
REMOTE_SCRIPTS_DIR="~/scripts"
REMOTE_WEB_DIR="~/vpn-web"

# Check if we're accidentally running on Pi
if [ -f /proc/device-tree/model ] && grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    echo "❌ ERROR: This script should run on the HOST, not on the Pi!"
    echo "You're currently on a Raspberry Pi. Please run this script from your host machine."
    exit 1
fi

# Source centralized configuration
if [ -f "$CONFIG_PATH" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_PATH"
    KEY="$SSH_KEY"
    USER="$SSH_USER"
    HOST="$SSH_HOST"
    PORT="$SSH_PORT"
else
    echo "❌ Configuration file '$CONFIG_PATH' not found"
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
ssh -i "$KEY" -p "$PORT" "$USER@$HOST" "mkdir -p $REMOTE_SCRIPTS_DIR"

# Copy all pi scripts and config to Pi
echo "🔧 Copying scripts and config to Pi..."
scp -i "$KEY" -P "$PORT" "$PI_PI_DIR"/*.sh "$CONFIG_PATH" "$USER@$HOST:$REMOTE_SCRIPTS_DIR/"
ssh -i "$KEY" -p "$PORT" "$USER@$HOST" "chmod +x $REMOTE_SCRIPTS_DIR/*.sh"

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

if [ ! -d "$WEB_DIR" ]; then
    echo "❌ Web UI directory not found at $WEB_DIR"
    exit 1
fi

echo "🔧 Syncing web UI to Pi..."
# Ensure remote web dir exists and is writable by the remote user
ssh -i "$KEY" -p "$PORT" "$USER@$HOST" "mkdir -p $REMOTE_WEB_DIR && sudo chown -R $USER:$USER $REMOTE_WEB_DIR || true"

# Rsync web UI to Pi. Exclude local virtualenv and ensure deletions.
rsync -az --delete --exclude='.venv' -e "ssh -i $KEY -p $PORT" "$WEB_DIR/" "$USER@$HOST:$REMOTE_WEB_DIR/"

# Fix ownership on remote in case any files were created by sudo operations
ssh -i "$KEY" -p "$PORT" "$USER@$HOST" "sudo chown -R $USER:$USER $REMOTE_WEB_DIR || true"

echo "🔧 Installing/refreshing web UI service on Pi..."
ssh -i "$KEY" -p "$PORT" "$USER@$HOST" "cd $REMOTE_WEB_DIR && sudo bash setup_web_service.sh"
echo "✅ Web UI deployed and service enabled"

# Execute setup on Pi
echo "🔧 Executing setup on Pi..."
echo ""
ssh -i "$KEY" -p "$PORT" "$USER@$HOST" "cd $REMOTE_SCRIPTS_DIR && sudo bash setup_pi.sh"

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
