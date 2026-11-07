#!/usr/bin/env bash
# Installs logiops and maps the MX Master 3S thumb button to workspace switching on GNOME.
set -euo pipefail

CFG_URL="https://raw.githubusercontent.com/espinosacodes/mx-master-3s-ubuntu/main/logid.cfg"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"

echo "==> Installing logiops"
sudo apt-get update -qq
sudo apt-get install -y logiops

TMP_CFG="$(mktemp)"
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/logid.cfg" ]]; then
    cp "$SCRIPT_DIR/logid.cfg" "$TMP_CFG"
else
    echo "==> Downloading config"
    curl -fsSL "$CFG_URL" -o "$TMP_CFG"
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

cat <<'MSG'

Done. Last step: turn the mouse OFF and back ON with the switch underneath.
logid only configures the mouse when it (re)connects.

Then hold the thumb button and move left or right to switch workspaces.
MSG
