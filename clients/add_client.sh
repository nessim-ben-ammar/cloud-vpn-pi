#!/bin/bash

SSH_KEY="../iac/ssh_keys/oci-instance-ssh-key"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <location> <client-name>"
  echo "Example: $0 frankfurt alice-phone"
  exit 1
fi

LOCATION="$1"
CLIENT_NAME="$2"
COMBINED_NAME="${LOCATION}-${CLIENT_NAME}"

get_output_value() {
  local output_name="$1"
  local location="$2"

  local json
  if ! json=$(terraform -chdir=../iac output -json "$output_name" 2>/dev/null); then
    echo "Error: terraform failed to get output '$output_name'" >&2
    exit 1
  fi

  # If jq is available prefer it (more robust JSON parsing)
  if command -v jq >/dev/null 2>&1; then
    # Try to get value for the requested location (map case)
    local val
    val=$(printf '%s' "$json" | jq -r --arg loc "$location" 'if (type=="object" or type=="array") and has($loc) then .[$loc] elif type=="string" then . else empty end')
    if [ -n "$val" ]; then
      printf '%s' "$val"
      return 0
    fi

    # If location wasn't found, show available keys (if any)
    local keys
    keys=$(printf '%s' "$json" | jq -r 'if type=="object" then keys[] else empty end' 2>/dev/null | paste -sd', ' -)
    if [ -z "$keys" ]; then
      echo "Unknown location '$location'. (no keys found)" >&2
      exit 1
    else
      echo "Unknown location '$location'. Available: $keys" >&2
      exit 1
    fi
  else
    # No jq available: fallback to a conservative text parse.
    # Remove whitespace/newlines for simpler matching
    local compact
    compact=$(printf '%s' "$json" | tr -d '[:space:]')

    # Try match as object: "location":"value"
    local val
    val=$(printf '%s' "$compact" | sed -n "s/.*\"$location\":\"\([^\"]*\)\".*/\1/p")
    if [ -n "$val" ]; then
      printf '%s' "$val"
      return 0
    fi

    # If the output is just a plain string ("value"), return it
    val=$(printf '%s' "$compact" | sed -n 's/^"\(.*\)"$/\1/p')
    if [ -n "$val" ]; then
      printf '%s' "$val"
      return 0
    fi

    # Otherwise, try to list available keys for a friendlier error
    local keys
    keys=$(printf '%s' "$compact" | grep -o '"[^"\\]*":' | sed 's/":$//' | sed 's/"//g' | paste -sd', ' -)
    if [ -z "$keys" ]; then
      echo "Unknown location '$location'." >&2
    else
      echo "Unknown location '$location'. Available: $keys" >&2
    fi
    exit 1
  fi
}

SERVER_IP=$(get_output_value "instance_public_ips" "$LOCATION")
# Endpoint can be the Global Accelerator DNS, a static IP, or the instance's public IP
VPN_ENDPOINT=$(get_output_value "vpn_endpoints" "$LOCATION")
SERVER="ubuntu@$SERVER_IP"

# Execute everything remotely over SSH
ssh -i "$SSH_KEY" $SERVER "sudo bash -s" <<EOF
set -e
CLIENT_NAME="$CLIENT_NAME"
SERVER_PUBLIC_IP="$SERVER_IP"
SERVER_ENDPOINT="$VPN_ENDPOINT"

cd /etc/wireguard
mkdir -p clients/\$CLIENT_NAME
cd clients/\$CLIENT_NAME
umask 077

# Generate key pair
wg genkey | tee \${CLIENT_NAME}_private.key | wg pubkey > \${CLIENT_NAME}_public.key
CLIENT_PRIV=\$(cat \${CLIENT_NAME}_private.key)
CLIENT_PUB=\$(cat \${CLIENT_NAME}_public.key)

# Detect server public key
SERVER_PUB=\$(wg show wg0 public-key)

# Determine next available IP in 192.168.2.x
USED_IPS=\$(grep -oP 'AllowedIPs\s*=\s*\K[0-9.]+' /etc/wireguard/wg0.conf | cut -d. -f4 | sort -n)
NEXT=2
for ip in \$USED_IPS; do
  if [ "\$ip" -eq "\$NEXT" ]; then
    NEXT=\$((NEXT + 1))
  else
    break
  fi
done
CLIENT_IP="192.168.2.\$NEXT"

# Create client config
cat > \${CLIENT_NAME}.conf <<EOC
[Interface]
PrivateKey = \$CLIENT_PRIV
Address = \$CLIENT_IP/32
DNS = 192.168.2.1

[Peer]
PublicKey = \$SERVER_PUB
Endpoint = \$SERVER_ENDPOINT:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOC

# Add peer to server config (if not present)
grep -q \$CLIENT_PUB /etc/wireguard/wg0.conf || echo "
[Peer]
PublicKey = \$CLIENT_PUB
AllowedIPs = \$CLIENT_IP/32
" >> /etc/wireguard/wg0.conf

# Restart WireGuard
systemctl restart wg-quick@wg0

# Generate QR code
qrencode -t ansiutf8 < \${CLIENT_NAME}.conf

# Make config readable by ubuntu user for scp
chmod 644 \${CLIENT_NAME}.conf

# Copy config to ubuntu user's home directory for scp access, renamed with location for clarity
cp \${CLIENT_NAME}.conf /home/ubuntu/\${COMBINED_NAME}.conf
chown ubuntu:ubuntu /home/ubuntu/\${COMBINED_NAME}.conf
EOF

# Copy config back to host
OUTPUT_DIR="configs"
mkdir -p "$OUTPUT_DIR"
scp -i "$SSH_KEY" $SERVER:/home/ubuntu/${COMBINED_NAME}.conf "$OUTPUT_DIR/${COMBINED_NAME}.conf"

# Clean up temporary file on server
ssh -i "$SSH_KEY" $SERVER "rm -f /home/ubuntu/${COMBINED_NAME}.conf"

echo "Client config saved to $OUTPUT_DIR/${COMBINED_NAME}.conf"
