#!/bin/bash

# Script to configure Unbound as the local recursive/forwarding resolver
# dnsmasq will forward all DNS queries to Unbound on localhost:5335

set -euo pipefail

# Check if we're running on a Pi
if [ ! -f /proc/device-tree/model ] || ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    echo "❌ ERROR: This script should run on a Raspberry Pi!"
    echo "You're currently on a different system. Please run this script on the Pi."
    exit 1
fi

# Check if we're running as root/sudo
if [ "$EUID" -ne 0 ]; then
    echo "❌ ERROR: This script must be run as root (with sudo)"
    echo "Usage: sudo ./setup_unbound.sh"
    exit 1
fi

# Source centralized configuration
if [ -f "config.sh" ]; then
    # shellcheck disable=SC1091
    source "config.sh"
else
    echo "❌ Configuration file 'config.sh' not found"
    echo "Please make sure config.sh exists in the current directory"
    exit 1
fi

if ! command -v unbound >/dev/null 2>&1; then
    echo "❌ Error: unbound is not installed. Please run install_packages.sh first."
    exit 1
fi

UNBOUND_CONF_DIR="/etc/unbound/unbound.conf.d"
FORWARD_FILE="$UNBOUND_CONF_DIR/pi-forward.conf"
DEFAULT_UPSTREAM="${UPSTREAM_DNS_SERVER:-1.1.1.1}"

echo "⚙️  Configuring Unbound as local resolver on 127.0.0.1:5335..."

mkdir -p "$UNBOUND_CONF_DIR"

cat > "$UNBOUND_CONF_DIR/pi-gateway.conf" <<EOF_CONF
server:
    interface: 127.0.0.1
    interface: $PI_IP
    access-control: 127.0.0.0/8 allow
    access-control: $PI_IP/32 allow
    port: 5335
    hide-identity: yes
    hide-version: yes
    qname-minimisation: yes
    prefetch: yes

include: "$FORWARD_FILE"
EOF_CONF

cat > "$FORWARD_FILE" <<EOF_FWD
forward-zone:
    name: "."
    forward-addr: $DEFAULT_UPSTREAM
EOF_FWD

systemctl enable unbound
systemctl restart unbound

if systemctl is-active --quiet unbound; then
    echo "✅ Unbound is running and listening on 127.0.0.1:5335"
else
    echo "❌ Unbound failed to start"
    systemctl status unbound --no-pager -l || true
    exit 1
fi
