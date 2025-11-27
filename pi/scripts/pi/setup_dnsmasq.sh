#!/bin/bash

# Script to setup dnsmasq as DHCP + DNS forwarder on Raspberry Pi
# Router DHCP should be disabled so the Pi can advertise itself as gateway + DNS
# Usage: ./setup_dnsmasq.sh

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

echo "Setting up dnsmasq DHCP + DNS forwarder on Raspberry Pi..."
echo "This will configure the Pi as DHCP server, gateway, and DNS forwarder"
echo ""

echo "Configuring dnsmasq services..."

# Check if dnsmasq is installed
if ! command -v dnsmasq >/dev/null 2>&1; then
    echo "❌ Error: dnsmasq is not installed. Please run install_packages.sh first."
    exit 1
fi


# Stop dnsmasq if running
echo "🛑 Stopping dnsmasq service..."
systemctl stop dnsmasq 2>/dev/null || true

# Backup original dnsmasq configuration
echo "💾 Backing up original dnsmasq configuration..."
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup 2>/dev/null || true

# Create new dnsmasq configuration
echo "📝 Creating dnsmasq configuration..."
cat > /etc/dnsmasq.conf << DNSMASQ_EOF
# dnsmasq configuration for Pi DNS forwarder
# Interface to bind to (Pi's ethernet interface)
interface=$LAN_INTERFACE

# Bind explicitly and listen on the Pi addresses only
bind-interfaces
listen-address=$PI_IP,127.0.0.1

# DHCP range - devices will get IPs in this range
# Make sure router DHCP is disabled to avoid conflicts
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,$SUBNET_MASK,$DHCP_LEASE_TIME

# Gateway option - Pi itself
dhcp-option=3,$PI_IP

# DNS option - Pi itself so queries stay local and forward upstream through dnsmasq
dhcp-option=6,$PI_IP

# Domain name
domain=$DOMAIN_NAME

# Enable DHCP logging
log-dhcp

# Cache size
cache-size=1000

# Upstream DNS server(s) dnsmasq will forward to
server=$UPSTREAM_DNS_SERVER

# Don't forward plain names
domain-needed
bogus-priv

# Provide DHCP on the LAN interface specified by $LAN_INTERFACE.
# Do not use `no-dhcp-interface` here because the Pi will act as DHCP
# server for the LAN (router DHCP should be disabled).

DNSMASQ_EOF

echo "✅ dnsmasq DHCP + DNS configuration created"

# Convert dotted-decimal subnet mask to CIDR prefix length
mask_to_prefix() {
    local mask=$1
    local prefix=0
    local octet

    IFS=. read -r o1 o2 o3 o4 <<< "$mask"
    for octet in "$o1" "$o2" "$o3" "$o4"; do
        while [ $octet -gt 0 ]; do
            prefix=$((prefix + (octet & 1)))
            octet=$((octet >> 1))
        done
    done

    echo "$prefix"
}

echo "🔧 Configuring Pi's static IP via NetworkManager..."
if ! command -v nmcli >/dev/null 2>&1; then
    echo "❌ NetworkManager (nmcli) is not installed. Please install it before continuing."
    exit 1
fi

SUBNET_PREFIX=$(mask_to_prefix "$SUBNET_MASK")

# Find an existing connection bound to the LAN interface or create one
LAN_CONN_NAME=$(nmcli -t -f NAME,DEVICE connection show --active | awk -F: -v iface="$LAN_INTERFACE" '$2 == iface {print $1; exit}')
if [ -z "$LAN_CONN_NAME" ]; then
    LAN_CONN_NAME=$(nmcli -t -f NAME,DEVICE connection show | awk -F: -v iface="$LAN_INTERFACE" '$2 == iface {print $1; exit}')
fi

if [ -z "$LAN_CONN_NAME" ]; then
    LAN_CONN_NAME="${LAN_INTERFACE}-static"
    echo "ℹ️  No existing NetworkManager connection for $LAN_INTERFACE. Creating $LAN_CONN_NAME..."
    nmcli connection add type ethernet ifname "$LAN_INTERFACE" con-name "$LAN_CONN_NAME" ipv4.method manual ipv4.addresses "$PI_IP/$SUBNET_PREFIX" ipv4.gateway "$ROUTER_IP" ipv4.dns "$PI_IP" ipv6.method ignore connection.autoconnect yes
else
    echo "ℹ️  Updating NetworkManager connection '$LAN_CONN_NAME' for $LAN_INTERFACE..."
    nmcli connection modify "$LAN_CONN_NAME" ipv4.method manual ipv4.addresses "$PI_IP/$SUBNET_PREFIX" ipv4.gateway "$ROUTER_IP" ipv4.dns "$PI_IP" ipv6.method ignore connection.autoconnect yes
fi

echo "🔄 Restarting NetworkManager connection '$LAN_CONN_NAME' to apply changes..."
nmcli connection down "$LAN_CONN_NAME" 2>/dev/null || true
nmcli connection up "$LAN_CONN_NAME"

echo "✅ Static IP configuration applied via NetworkManager"

# Enable and start dnsmasq
echo "🚀 Starting dnsmasq service..."
systemctl enable dnsmasq
systemctl start dnsmasq

# Check if dnsmasq started successfully
if systemctl is-active --quiet dnsmasq; then
    echo "✅ dnsmasq started successfully"
else
    echo "❌ dnsmasq failed to start"
    systemctl status dnsmasq
    exit 1
fi

# Show dnsmasq status
echo ""
echo "📊 dnsmasq status:"
systemctl status dnsmasq --no-pager -l

echo ""
echo "📋 Active DHCP leases:"
cat /var/lib/misc/dnsmasq.leases 2>/dev/null || echo "No leases yet"

echo ""
echo "✅ dnsmasq DHCP + DNS server setup completed!"
