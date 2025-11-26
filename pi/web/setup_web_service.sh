#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR"
VENV_PATH="$APP_DIR/.venv"
SERVICE_NAME="vpn-web.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
ENV_FILE="/etc/default/vpn-web"

if [[ "$EUID" -ne 0 ]]; then
  echo "This installer must be run as root." >&2
  exit 1
fi

if [[ -d "$VENV_PATH" ]]; then
  echo "Found existing virtualenv at $VENV_PATH — removing to avoid conflicts..."
  rm -rf "$VENV_PATH"
fi

echo "Creating virtualenv at $VENV_PATH..."
python3 -m venv "$VENV_PATH"

echo "Upgrading pip and installing requirements (no cache)..."
"$VENV_PATH/bin/pip" install --upgrade pip
"$VENV_PATH/bin/pip" install --no-cache-dir -r "$APP_DIR/requirements.txt"

if [[ ! -f "$ENV_FILE" ]]; then
  SECRET_KEY=$(openssl rand -hex 16)
  cat > "$ENV_FILE" <<EOF_ENV
FLASK_SECRET_KEY=${SECRET_KEY}
PORT=8080
EOF_ENV
fi

cat > "$SERVICE_PATH" <<EOF_SERVICE
[Unit]
Description=Cloud VPN Pi Web UI
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
EnvironmentFile=$ENV_FILE
ExecStart=$VENV_PATH/bin/python $APP_DIR/app.py
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF_SERVICE

systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"

echo "Web UI service installed and enabled. Manage with:"
echo "  sudo systemctl status $SERVICE_NAME"
echo "  sudo systemctl restart $SERVICE_NAME"
echo "  sudo systemctl stop $SERVICE_NAME"
