# Web Control Panel

A lightweight Flask interface for controlling the Raspberry Pi VPN gateway. It lets you enable/disable the WireGuard tunnel and switch between VPN endpoints (Frankfurt and Marseille by default).

## Setup

### Deploy via host automation

If you're already using the host deployment scripts in `pi/scripts/host`, running `./deploy_to_pi.sh` from that directory will
sync this `pi/web` folder to the Pi (at `~/vpn-web`) and call `sudo ./setup_web_service.sh` to install/enable the systemd
service.

1. **Install dependencies**

   ```bash
   sudo apt-get update && sudo apt-get install -y python3-pip
   cd /home/pi/cloud-vpn-pi/pi/web
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

2. **Ensure WireGuard configs exist**

Place your location/device-specific configs on the Pi under `/etc/wireguard/configs` (e.g., `frankfurt-home.conf`,
`marseille-office.conf`). The Pi setup scripts copy every config from `$WG_REMOTE_CONFIG_DIR` into that directory and write
the current location to `/etc/wireguard/current_location` so the web UI knows which endpoint is active even after a reboot.

3. **Run the app**

   ```bash
   sudo FLASK_SECRET_KEY=$(openssl rand -hex 16) python3 app.py
   ```

   The app listens on port `8080` by default. Set `PORT` to change it.

4. **(Recommended) Install as a service and auto-start on boot**

   From the `pi/web` directory run:

   ```bash
   sudo ./setup_web_service.sh
   ```

   This will create a virtual environment (if one does not exist), install dependencies, generate a secret key at
   `/etc/default/vpn-web`, and register `vpn-web.service` with systemd so the web UI starts on reboot. Adjust the
   port or secret key by editing `/etc/default/vpn-web` and restarting the service:

   ```bash
   sudo systemctl restart vpn-web.service
   ```

## Behavior

- Reads interface settings from `pi/scripts/config.sh` (`WG_INTERFACE`, `LAN_INTERFACE`).
- The Pi setup process installs configs but leaves WireGuard disabled until you select a location from the UI.
- "Enable VPN" mirrors the `start_vpn.sh` behavior: starts `wg-quick@<interface>` and updates NAT rules to route through WireGuard.
- "Disable VPN" mirrors `stop_vpn.sh`: stops/disables `wg-quick@<interface>` and restores NAT on the LAN interface.
- Switching locations copies the selected config from `/etc/wireguard/configs/<location>-<device>.conf` into `/etc/wireguard/<interface>.conf`,
  records the choice in `/etc/wireguard/current_location`, and restarts the service if it was already active. The status card reads
  from that file to display the active location after restarts.
- The last requested state (connected or disconnected) is stored in `/etc/wireguard/state` and restored on boot via
  `vpn-state-restore.service`, so the Pi returns to the previous VPN status after power loss.

> Run the app with root privileges so it can manage `systemctl` and `iptables`.
