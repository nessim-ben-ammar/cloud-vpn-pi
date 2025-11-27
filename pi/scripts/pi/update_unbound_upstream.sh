#!/bin/bash

# Update Unbound forwarders based on VPN state

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_PATH="$SCRIPT_DIR/config.sh"

if [ -f "$CONFIG_PATH" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_PATH"
fi

WG_INTERFACE=${WG_INTERFACE:-wg0}
WG_CONF="/etc/wireguard/${WG_INTERFACE}.conf"
DEFAULT_UPSTREAM="${UPSTREAM_DNS_SERVER:-1.1.1.1}"
UNBOUND_FORWARD_FILE="/etc/unbound/unbound.conf.d/pi-forward.conf"

write_forwarders() {
    local -a servers=("$@")

    if [ ${#servers[@]} -eq 0 ] || [ -z "${servers[0]}" ]; then
        servers=("$DEFAULT_UPSTREAM")
    fi

    mkdir -p "$(dirname "$UNBOUND_FORWARD_FILE")"

    {
        echo "forward-zone:"
        echo "    name: \".\""
        for server in "${servers[@]}"; do
            # Convert dnsmasq-style host#port to unbound host@port if needed
            server=${server//#/@}
            echo "    forward-addr: ${server}"
        done
    } > "$UNBOUND_FORWARD_FILE"

    systemctl reload unbound || systemctl restart unbound
}

vpn_dns_from_config() {
    if [ ! -f "$WG_CONF" ]; then
        return
    fi

    awk -F '=' '/^DNS/ {print $2}' "$WG_CONF" \
        | tr ',' '\n' \
        | tr -d '[:space:]' \
        | sed '/^$/d'
}

MODE=${1:-""}

if [ "$MODE" = "vpn" ]; then
    mapfile -t dns_entries < <(vpn_dns_from_config)
    write_forwarders "${dns_entries[@]}"
else
    write_forwarders "$DEFAULT_UPSTREAM"
fi
