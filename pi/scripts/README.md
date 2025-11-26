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
│   └── setup_dnsmasq.sh
└── README.md
```

## Configuration

All scripts use centralized configuration from `config.sh`. Key settings:

- **SSH Configuration**: Host, user, key path, port
- **WireGuard Configuration**: Config file location, interface name
- **Network Configuration**: IP addresses and DHCP range (Pi hands out leases)
- **fail2ban Configuration**: Ban times, retry limits
- **DNS Configuration**: Upstream DNS server used by the Pi resolver

Edit `config.sh` to customize for your environment.

## Usage

### From Host Machine

1. **Deploy everything to Pi:**

   ```bash
   cd host/
   ./deploy_to_pi.sh
   ```

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
   sudo ./setup_wireguard.sh /etc/wireguard/vpn-pi.conf
   sudo ./setup_gateway.sh
   sudo ./setup_dnsmasq.sh
   ```

### Router

- Disable the router's DHCP server so the Pi can provide leases that point
  clients at the Pi for gateway and DNS.

## Protection

- **Host scripts** check that they're NOT running on a Pi
- **Pi scripts** check that they ARE running on a Pi
- This prevents accidental execution on the wrong system

## Prerequisites

- Place your WireGuard config at `/etc/wireguard/vpn-pi.conf` on the Pi
- SSH key setup for Pi access (see `connect.sh` for configuration)
