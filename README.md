# Cloud VPN Pi

A Raspberry Pi–based VPN gateway with automation for provisioning cloud VPN endpoints, deploying Pi setup scripts, and controlling the gateway through a lightweight web UI. Use this repository to provision WireGuard servers in the cloud, manage client configs, and keep your Pi routing traffic through the desired location.

## Repository layout

- `clients/`: Utility scripts and stored WireGuard client configurations generated from cloud servers.
- `iac/`: Terraform configuration for provisioning cloud infrastructure and WireGuard servers.
- `pi/scripts/`: Host and Pi-side automation for configuring the Pi gateway and syncing configs.
- `pi/web/`: Flask control panel that toggles the VPN and switches locations.

## Quick start

1. **Customize Pi settings**
   - Edit `pi/scripts/config.sh` to match your LAN, SSH, and WireGuard preferences.
   - Place VPN endpoint configs in `clients/configs/<location>-<device>.conf`.

2. **Provision VPN endpoints (optional)**
   - From `iac/`, run Terraform to create cloud instances and WireGuard servers. See `iac/README.md` for details.

3. **Deploy to the Pi**
   - From `pi/scripts/host/`, run `./deploy_to_pi.sh` to sync scripts, copy configs, and install the web UI service on the Pi.
   - Use `./connect.sh` in the same directory for a configured SSH session.

4. **Control the gateway**
   - Visit the web UI (defaults to port `8080` on the Pi) to enable/disable the VPN or switch locations.
   - You can also run Pi-side scripts in `pi/scripts/pi/` (e.g., `start_vpn.sh`, `stop_vpn.sh`, `setup_wireguard.sh`).

## Docs per area

- **Pi automation:** `pi/scripts/README.md`
- **Web control panel:** `pi/web/README.md`
- **Client management:** `clients/README.md`
- **Infrastructure provisioning:** `iac/README.md`

## Notes

- The Pi scripts expect a Debian-based Pi with `iptables`, `dnsmasq`, and `WireGuard` available (handled by `setup_pi.sh`).
- Ensure your router hands DHCP to the Pi so gateway and DNS settings propagate to clients.
