# Client Utilities

## WireGuard configuration storage
- Place server configuration files for each VPN location in `clients/configs`.
- Name each file `<location>.conf` (for example, `frankfurt.conf` or `marseille.conf`).
- These files are copied to the Pi at `$WG_REMOTE_CONFIG_DIR` during deployment so you can switch the active tunnel without re-uploading.

## Client management
- `add_client.sh <location> <client-name>`: creates a client for the specified location and saves the config under `clients/configs/<location>/`.
- `backup_configs.sh <location>`: archives `/etc/wireguard` from the chosen server, outputting `wireguard-backup-<location>.tar.gz`.
- `restore_configs.sh <location> [archive]`: restores a backup to the specified server (defaults to `wireguard-backup-<location>.tar.gz`).
