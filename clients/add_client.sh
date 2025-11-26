#!/bin/bash

SSH_KEY="../iac/ssh_keys/oci-instance-ssh-key"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <location> <client-name>"
  echo "Example: $0 frankfurt alice-phone"
  exit 1
fi

LOCATION="$1"
CLIENT_NAME="$2"

get_output_value() {
  local output_name="$1"
  local location="$2"
  python - <<'PY' "$output_name" "$location"
import json
import subprocess
import sys

output_name, location = sys.argv[1], sys.argv[2]
data = json.loads(subprocess.check_output([
    "terraform", "-chdir=../iac", "output", "-json", output_name
]))

if location not in data:
    sys.stderr.write(f"Unknown location '{location}'. Available: {', '.join(sorted(data))}\n")
    sys.exit(1)

print(data[location])
PY
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

# Copy config to ubuntu user's home directory for scp access
cp \${CLIENT_NAME}.conf /home/ubuntu/\${CLIENT_NAME}.conf
chown ubuntu:ubuntu /home/ubuntu/\${CLIENT_NAME}.conf
EOF

# Copy config back to host
OUTPUT_DIR="configs/$LOCATION"
mkdir -p "$OUTPUT_DIR"
scp -i "$SSH_KEY" $SERVER:/home/ubuntu/${CLIENT_NAME}.conf "$OUTPUT_DIR/"

# Clean up temporary file on server
ssh -i "$SSH_KEY" $SERVER "rm -f /home/ubuntu/${CLIENT_NAME}.conf"

echo "Client config saved to $OUTPUT_DIR/${CLIENT_NAME}.conf"
