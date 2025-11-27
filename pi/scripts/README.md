# Pi VPN Gateway Scripts

This directory contains scripts organized by where they should run:

## Directory Structure

```
scripts/
├── config.sh       # Centralized configuration file
├── host/           # Scripts that run on your HOST machine
│   ├── deploy_to_pi.sh   # Main deployment script
│   └── connect.sh        # SSH connection script
├── pi/             # Scripts that run ON the Pi
│   ├── setup_pi.sh       # Main orchestrator
│   ├── install_packages.sh
│   ├── setup_fail2ban.sh
│   ├── setup_wireguard.sh
│   ├── setup_gateway.sh
│   ├── setup_unbound.sh
│   └── setup_dnsmasq.sh
└── README.md
```

## Configuration

All scripts use centralized configuration from `config.sh`. Key settings:

- **SSH Configuration**: Host, user, key path, port
- **WireGuard Configuration**: Interface name plus per-location configs stored in `../clients/configs/<location>-<device>.conf`. The deploy script copies every config to the Pi at `$WG_REMOTE_CONFIG_DIR`, `setup_wireguard.sh` syncs them into `$WG_CONFIG_ARCHIVE` (default `/etc/wireguard/configs`), records the active site in `$WG_ACTIVE_LOCATION_FILE`, and activates the location specified (defaults to `$WG_DEFAULT_LOCATION`).
- **Network Configuration**: IP addresses and DHCP range (Pi hands out leases)
- **fail2ban Configuration**: Ban times, retry limits
- **DNS Configuration**: dnsmasq always forwards to the local Unbound resolver
  on `127.0.0.1#5335`. Unbound switches upstreams automatically: it uses the
  VPN-provided DNS when WireGuard is active, and falls back to
  `UPSTREAM_DNS_SERVER` (default `1.1.1.1`) when the VPN is disabled.

Edit `config.sh` to customize for your environment.

## Usage

### From Host Machine

1. **Deploy everything to Pi:**

   ```bash
   cd host/
   ./deploy_to_pi.sh
   ```

    This syncs the VPN gateway scripts, copies all per-location WireGuard configs, and deploys the web UI to `~/vpn-web` on
    the Pi before enabling its systemd service via `sudo bash setup_web_service.sh`.

2. **Connect to Pi:**
   ```bash
   cd host/
   ./connect.sh
   ```

### On Pi (if running manually)

1. **Full setup:**

   ```bash
   cd pi/
   sudo ./setup_pi.sh
   ```

2. **Individual components:**
   ```bash
   cd pi/
    sudo ./install_packages.sh
    sudo ./setup_fail2ban.sh
     sudo ./setup_wireguard.sh frankfurt
    sudo ./setup_gateway.sh
    sudo ./setup_unbound.sh
    sudo ./setup_dnsmasq.sh
    ```

3. **Operational commands:**

   - `activate_vpn.sh <location>` installs the specified WireGuard profile onto the Pi, makes it the active config, then calls `start_vpn.sh`.
   - `start_vpn.sh` starts the currently installed WireGuard profile and rewrites NAT rules; it assumes the config already exists in `/etc/wireguard`.
   - `deactivate_vpn.sh` is a JSON-friendly wrapper that logs output and calls `stop_vpn.sh`.
   - `stop_vpn.sh` stops the WireGuard unit, rewrites NAT rules for direct internet, and restores upstream DNS.

   Use the wrappers when driving from the web UI or when you need to switch locations, and the `start_vpn.sh`/`stop_vpn.sh` pair for straight service control.

### Router

- Disable the router's DHCP server so the Pi can provide leases that point
  clients at the Pi for gateway and DNS.

## Protection

- **Host scripts** check that they're NOT running on a Pi
- **Pi scripts** check that they ARE running on a Pi
- This prevents accidental execution on the wrong system

## Prerequisites

- Place your WireGuard config files in `../clients/configs/<location>-<device>.conf` before running `deploy_to_pi.sh`
- SSH key setup for Pi access (see `connect.sh` for configuration)
