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
# - Store multiple VPN configs in the clients/configs directory (one file per endpoint/device, e.g., frankfurt-home.conf)
# - WG_DEFAULT_LOCATION can be used for manual activation, but setup_pi leaves the VPN inactive
# - WG_REMOTE_CONFIG_DIR is where all configs are copied on the Pi for later switching
WG_CONFIGS_DIR="/workspaces/cloud-vpn-pi/clients/configs"
WG_DEFAULT_LOCATION="frankfurt"
WG_REMOTE_CONFIG_DIR="/home/pi/wireguard-configs"
# - WG_CONFIG_ARCHIVE is where configs are persisted for the web UI and switching after reboot
# - WG_ACTIVE_LOCATION_FILE tracks the last applied location so restarts keep the UI in sync
# - WG_STATE_FILE tracks whether the VPN should be active after a reboot
WG_CONFIG_ARCHIVE="/etc/wireguard/configs"
WG_ACTIVE_LOCATION_FILE="/etc/wireguard/current_location"
WG_STATE_FILE="/etc/wireguard/state"
WG_INTERFACE="wg0"

# DNS Configuration
# - LOCAL_DNS_SERVER is where dnsmasq forwards (Unbound on localhost by default)
# - UPSTREAM_DNS_SERVER is the non-VPN resolver Unbound should use when VPN is off
LOCAL_DNS_SERVER="127.0.0.1#5335"
UPSTREAM_DNS_SERVER="1.1.1.1"
DOMAIN_NAME="local"

# Network Interface Configuration
LAN_INTERFACE="eth0"
SUBNET_MASK="255.255.255.0"

# fail2ban Configuration
FAIL2BAN_MAXRETRY=5
FAIL2BAN_BANTIME=3600
FAIL2BAN_FINDTIME=600
