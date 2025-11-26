#!/bin/bash

# Archive all client configuration files from the server and copy them locally.

if [ -z "$1" ]; then
  echo "Usage: $0 <location>"
  exit 1
fi

LOCATION="$1"
SSH_KEY="../iac/ssh_keys/oci-instance-ssh-key"
ARCHIVE="wireguard-backup-$LOCATION.tar.gz"

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

# Create archive on the server containing entire /etc/wireguard directory
ssh -i "$SSH_KEY" "$SERVER" "sudo tar -czf /tmp/$ARCHIVE -C /etc wireguard"

# Download the archive to the current directory
scp -i "$SSH_KEY" "$SERVER:/tmp/$ARCHIVE" .

# Remove the temporary archive on the server
ssh -i "$SSH_KEY" "$SERVER" "sudo rm -f /tmp/$ARCHIVE"

echo "WireGuard configuration archived to $ARCHIVE"

