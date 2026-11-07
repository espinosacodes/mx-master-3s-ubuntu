#!/usr/bin/env bash
# Installs logiops and maps the MX Master 3S thumb button to workspace switching on GNOME.
set -euo pipefail

RAW_URL="https://raw.githubusercontent.com/espinosacodes/mx-master-3s-ubuntu/main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"

echo "==> Installing logiops"
sudo apt-get update -qq
sudo apt-get install -y logiops

TMP_CFG="$(mktemp)"
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/logid.cfg" ]]; then
    cp "$SCRIPT_DIR/logid.cfg" "$TMP_CFG"
else
    echo "==> Downloading config"
    curl -fsSL "$RAW_URL/logid.cfg" -o "$TMP_CFG"
fi

# Business edition mice report a different name, so match it if logid sees it.
if [[ "${1:-}" == "--business" ]]; then
    sed -i 's/name: "MX Master 3S";/name: "MX Master 3S B";/' "$TMP_CFG"
fi

if [[ -f /etc/logid.cfg ]]; then
    BACKUP="/etc/logid.cfg.bak.$(date +%Y%m%d%H%M%S)"
    echo "==> Backing up existing config to $BACKUP"
    sudo cp /etc/logid.cfg "$BACKUP"
fi

echo "==> Writing /etc/logid.cfg"
sudo install -m 644 "$TMP_CFG" /etc/logid.cfg
rm -f "$TMP_CFG"

echo "==> Enabling the logid service"
sudo systemctl enable logid >/dev/null 2>&1 || true
sudo systemctl restart logid

# logid can lose track of the mouse after it sleeps (for example when an MX Keys on the
# same receiver connects). The watchdog notices and restarts logid.
echo "==> Installing the logid watchdog"
WD_TMP="$(mktemp -d)"
for f in logid-watchdog logid-watchdog.service logid-watchdog.timer; do
    if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/watchdog/$f" ]]; then
        cp "$SCRIPT_DIR/watchdog/$f" "$WD_TMP/$f"
    else
        curl -fsSL "$RAW_URL/watchdog/$f" -o "$WD_TMP/$f"
    fi
done
sudo install -m 755 "$WD_TMP/logid-watchdog" /usr/local/bin/logid-watchdog
sudo install -m 644 "$WD_TMP/logid-watchdog.service" "$WD_TMP/logid-watchdog.timer" /etc/systemd/system/
rm -rf "$WD_TMP"
sudo systemctl daemon-reload
sudo systemctl enable --now logid-watchdog.timer >/dev/null 2>&1

cat <<'MSG'

Done. Last step: turn the mouse OFF and back ON with the switch underneath.
logid only configures the mouse when it (re)connects.

Then hold the thumb button and move left or right to switch workspaces.
MSG
