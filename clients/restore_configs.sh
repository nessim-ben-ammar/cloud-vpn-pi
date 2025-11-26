#!/bin/bash

# Upload previously archived client configuration files to the server.
# Usage: restore_configs.sh <location> [archive]

if [ -z "$1" ]; then
  echo "Usage: $0 <location> [archive]"
  exit 1
fi

LOCATION="$1"
SSH_KEY="../iac/ssh_keys/oci-instance-ssh-key"
ARCHIVE="${2:-wireguard-backup-$LOCATION.tar.gz}"

SERVER_IP=$(python - <<'PY' "$LOCATION"
import json, subprocess, sys
location = sys.argv[1]
data = json.loads(subprocess.check_output(["terraform", "-chdir=../iac", "output", "-json", "instance_public_ips"]))
if location not in data:
    sys.stderr.write(f"Unknown location '{location}'. Available: {', '.join(sorted(data))}\n")
    sys.exit(1)
print(data[location])
PY
)

SERVER="ubuntu@$SERVER_IP"

if [ ! -f "$ARCHIVE" ]; then
  echo "Archive $ARCHIVE not found"
  exit 1
fi

# Copy archive to the server
scp -i "$SSH_KEY" "$ARCHIVE" "$SERVER:/tmp/"

BASENAME=$(basename "$ARCHIVE")
# Extract archive on the server and restart WireGuard
ssh -i "$SSH_KEY" "$SERVER" "sudo tar -xzf /tmp/$BASENAME -C /etc && sudo rm /tmp/$BASENAME && sudo systemctl restart wg-quick@wg0"

echo "WireGuard configuration restored from $ARCHIVE"

