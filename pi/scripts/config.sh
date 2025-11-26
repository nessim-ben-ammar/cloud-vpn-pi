# Pi VPN Gateway Configuration
# This file contains centralized configuration for all scripts

# Network Configuration
PI_IP="192.168.178.2"
ROUTER_IP="192.168.178.1"
DHCP_RANGE_START="192.168.178.20"
DHCP_RANGE_END="192.168.178.200"
DHCP_LEASE_TIME="24h"

# SSH Configuration
SSH_KEY="/workspaces/cloud-vpn-pi/pi/ssh_keys/pi_ssh_key"
SSH_USER="pi"
SSH_HOST="$PI_IP"
SSH_PORT=22

# WireGuard Configuration
WG_CONFIG_SOURCE="/workspaces/cloud-vpn-pi/clients/vpn-pi.conf"  # Source path on host
WG_CONFIG_DEST="/etc/wireguard/vpn-pi.conf"   # Destination path on Pi
WG_INTERFACE="wg0"

# DNS Configuration
# Upstream resolver that dnsmasq forwards to while the Pi serves local DNS
UPSTREAM_DNS_SERVER="192.168.2.1"
DOMAIN_NAME="local"

# Network Interface Configuration
LAN_INTERFACE="eth0"
SUBNET_MASK="255.255.255.0"

# fail2ban Configuration
FAIL2BAN_MAXRETRY=5
FAIL2BAN_BANTIME=3600
FAIL2BAN_FINDTIME=600
