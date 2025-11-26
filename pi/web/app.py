from __future__ import annotations

import os
import shlex
import shutil
import subprocess
from pathlib import Path
from typing import Dict, List

from flask import Flask, flash, redirect, render_template, request, url_for

BASE_DIR = Path(__file__).resolve().parent
CONFIG_SH = BASE_DIR.parent / "scripts" / "config.sh"
SCRIPT_ROOT = BASE_DIR.parent / "scripts"

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "cloud-vpn-pi-secret")


def _run_command(command: List[str]) -> str:
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    return (result.stdout or result.stderr or "").strip()


def _read_config_variable(variable: str, fallback: str) -> str:
    if not CONFIG_SH.exists():
        return fallback

    quoted_config = shlex.quote(str(CONFIG_SH))
    quoted_var = shlex.quote(variable)
    shell_cmd = (
        "bash -c '"
        f"source {quoted_config} >/dev/null 2>&1; "
        f"printf \"%s\" \"${{{quoted_var}}}\"'"
    )
    output = subprocess.run(shell_cmd, shell=True, capture_output=True, text=True, check=False)
    return output.stdout.strip() or fallback


def load_runtime_config() -> Dict[str, str]:
    wg_interface = _read_config_variable("WG_INTERFACE", "wg0")
    lan_interface = _read_config_variable("LAN_INTERFACE", "eth0")
    dns_upstream = _read_config_variable("UPSTREAM_DNS_SERVER", "8.8.8.8")

    return {
        "wg_interface": wg_interface,
        "lan_interface": lan_interface,
        "dns_upstream": dns_upstream,
    }


RUNTIME_CONFIG = load_runtime_config()

WG_INTERFACE = RUNTIME_CONFIG["wg_interface"]
LAN_INTERFACE = RUNTIME_CONFIG["lan_interface"]
ACTIVE_CONFIG = Path(f"/etc/wireguard/{WG_INTERFACE}.conf")

LOCATIONS: Dict[str, Dict[str, str]] = {
    "frankfurt": {
        "label": "Frankfurt",
        "config": os.environ.get("WG_FRANKFURT_CONFIG", "/etc/wireguard/wg0-frankfurt.conf"),
        "description": "Primary VPN endpoint in Frankfurt",
    },
    "marseille": {
        "label": "Marseille",
        "config": os.environ.get("WG_MARSEILLE_CONFIG", "/etc/wireguard/wg0-marseille.conf"),
        "description": "Backup VPN endpoint in Marseille",
    },
}


class LocationSwitchError(Exception):
    pass


def vpn_is_active() -> bool:
    status = _run_command(["systemctl", "is-active", f"wg-quick@{WG_INTERFACE}"])
    return status == "active"


def current_location() -> str:
    if ACTIVE_CONFIG.exists():
        active_target = ACTIVE_CONFIG.resolve()
        for key, data in LOCATIONS.items():
            if Path(data["config"]).resolve() == active_target:
                return key
    return "unknown"


def _ensure_permissions(config_path: Path) -> None:
    os.chmod(config_path, 0o600)


def _enable_nat_for_vpn() -> None:
    subprocess.run(["iptables", "-t", "nat", "-F", "POSTROUTING"], check=False)
    subprocess.run(["iptables", "-t", "nat", "-A", "POSTROUTING", "-o", WG_INTERFACE, "-j", "MASQUERADE"], check=False)


def _enable_nat_for_direct() -> None:
    subprocess.run(["iptables", "-t", "nat", "-F", "POSTROUTING"], check=False)
    subprocess.run(["iptables", "-t", "nat", "-A", "POSTROUTING", "-o", LAN_INTERFACE, "-j", "MASQUERADE"], check=False)


def _run_pi_script(script_name: str) -> bool:
    script_path = SCRIPT_ROOT / "pi" / script_name
    if not script_path.exists():
        return False

    subprocess.run(["bash", str(script_path)], cwd=SCRIPT_ROOT, check=False)
    return True


def start_vpn() -> None:
    if not _run_pi_script("start_vpn.sh"):
        subprocess.run(["systemctl", "enable", f"wg-quick@{WG_INTERFACE}"], check=False)
        subprocess.run(["systemctl", "start", f"wg-quick@{WG_INTERFACE}"], check=False)
        _enable_nat_for_vpn()


def stop_vpn() -> None:
    if not _run_pi_script("stop_vpn.sh"):
        subprocess.run(["systemctl", "stop", f"wg-quick@{WG_INTERFACE}"], check=False)
        subprocess.run(["systemctl", "disable", f"wg-quick@{WG_INTERFACE}"], check=False)
        _enable_nat_for_direct()


def set_location(location_key: str) -> None:
    if location_key not in LOCATIONS:
        raise LocationSwitchError(f"Unknown location: {location_key}")

    location_config = Path(LOCATIONS[location_key]["config"])
    if not location_config.exists():
        raise LocationSwitchError(
            f"Config for {LOCATIONS[location_key]['label']} not found at {location_config}"
        )

    was_active = vpn_is_active()
    if was_active:
        stop_vpn()

    ACTIVE_CONFIG.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(location_config, ACTIVE_CONFIG)
    _ensure_permissions(ACTIVE_CONFIG)

    if was_active:
        start_vpn()


def get_status() -> Dict[str, str]:
    status = "active" if vpn_is_active() else "inactive"
    try:
        location = current_location()
    except Exception:
        location = "unknown"

    return {
        "status": status,
        "location": location,
        "wg_interface": WG_INTERFACE,
        "lan_interface": LAN_INTERFACE,
    }


@app.route("/")
def index():
    status = get_status()
    return render_template("index.html", status=status, locations=LOCATIONS)


@app.post("/vpn")
def toggle_vpn():
    action = request.form.get("action")
    if action == "start":
        start_vpn()
        flash("VPN enabled. Traffic now routes through WireGuard.", "success")
    elif action == "stop":
        stop_vpn()
        flash("VPN disabled. Traffic now routes directly to the internet.", "warning")
    else:
        flash("Unknown action", "error")

    return redirect(url_for("index"))


@app.post("/location")
def change_location():
    location_key = request.form.get("location")
    try:
        set_location(location_key)
        flash(f"VPN location switched to {LOCATIONS[location_key]['label']}", "success")
    except LocationSwitchError as err:
        flash(str(err), "error")
    except Exception as exc:  # noqa: BLE001
        flash(f"Unexpected error: {exc}", "error")
    return redirect(url_for("index"))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)), debug=False)
