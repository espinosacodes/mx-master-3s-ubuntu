#!/usr/bin/env bash
# Makes the MX Keys S screenshot and lock keys work on GNOME (Ubuntu).
# Run as your normal user (no sudo): these are per-user GNOME settings.
#
# In Mac mode (Fn+O) the keys send macOS shortcuts:
#   screenshot -> Super+Shift+4    lock -> Super+Ctrl+Q
# In Windows mode (Fn+P) the screenshot key sends Super+Shift+S and lock sends
# Super+L, which GNOME already uses for locking.
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not with sudo." >&2
    exit 1
fi

has_key() {
    gsettings list-keys "$1" 2>/dev/null | grep -qx "$2"
}

# Appends a binding to a GNOME keybinding list unless it is already there.
add_binding() {
    local schema="$1" key="$2" binding="$3"
    local current
    current="$(gsettings get "$schema" "$key")"
    if [[ "$current" == *"'$binding'"* ]]; then
        return
    fi
    if [[ "$current" == "@as []" || "$current" == "[]" ]]; then
        gsettings set "$schema" "$key" "['$binding']"
    else
        gsettings set "$schema" "$key" "${current%]}, '$binding']"
    fi
}

# The Ubuntu dock uses Super+Shift+4 to open a new window of the 4th dock app.
DOCK=org.gnome.shell.extensions.dash-to-dock
if has_key "$DOCK" app-shift-hotkey-4 && [[ "$(gsettings get "$DOCK" app-shift-hotkey-4)" == *"<Shift><Super>4"* ]]; then
    echo "==> Freeing Super+Shift+4 from the Ubuntu dock"
    gsettings set "$DOCK" app-shift-hotkey-4 "[]"
fi

echo "==> Screenshot key opens the GNOME screenshot tool"
add_binding org.gnome.shell.keybindings show-screenshot-ui '<Shift><Super>4'
add_binding org.gnome.shell.keybindings show-screenshot-ui '<Shift><Super>s'

echo "==> Lock key locks the session"
add_binding org.gnome.settings-daemon.plugins.media-keys screensaver '<Control><Super>q'

echo
echo "Done. Press the screenshot key or the lock key to try it."
