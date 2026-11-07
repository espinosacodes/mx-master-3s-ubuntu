# Make the MX Master 3S thumb button switch desktops on Ubuntu (like a Mac)

On macOS, Logi Options+ lets you hold the MX Master 3S thumb button and swipe to
switch desktops. Logitech doesn't ship Options+ for Linux, so on Ubuntu the button
does nothing useful out of the box.

You can get the same behavior back with about two minutes of setup. Here's how I did it.

## What you get

| Thumb button | Result |
|---|---|
| Hold and move **left** | Next workspace (to the right) |
| Hold and move **right** | Previous workspace (to the left) |
| **Tap** it, or hold and move up/down | Activities overview, the GNOME version of Mission Control |

It also turns on SmartShift (the scroll wheel switches to free spin when you flick it)
and sets 1500 DPI. Hi-res scrolling is left off on purpose, because on GNOME it makes
many apps scroll way too far per notch.

Tested on Ubuntu 26.04 (GNOME, Wayland) with an MX Master 3S on a Logi Bolt receiver.
It should work the same over Bluetooth, and on any Ubuntu release that has the
`logiops` package (22.04 and newer).

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/espinosacodes/mx-master-3s-ubuntu/main/install.sh | bash
```

Or clone it first if you'd rather read the script before running it (you should):

```bash
git clone https://github.com/espinosacodes/mx-master-3s-ubuntu.git
cd mx-master-3s-ubuntu
./install.sh
```

**Then turn the mouse off and back on** with the switch underneath. Don't skip this
step (see "The gotcha" below).

## How it works

### 1. logiops

[logiops](https://github.com/PixlOne/logiops) is an open source daemon that talks to
Logitech mice using Logitech's own HID++ protocol, which is what Options+ uses too. It
runs in the background as the `logid` systemd service.

```bash
sudo apt install logiops
```

### 2. The config

logid reads `/etc/logid.cfg`. The important part tells the mouse to hand the thumb
button (control ID `0xc3`) to logid instead of handling it itself. logid then tracks
which way you move while holding it and sends a shortcut GNOME already knows:

```
Left   ->  Ctrl+Alt+Right   (next workspace)
Right  ->  Ctrl+Alt+Left    (previous workspace)
None   ->  Super            (overview)
```

These are GNOME's default workspace shortcuts, so you don't need to change anything in
Settings. The full file is [`logid.cfg`](logid.cfg).

The directions follow a Mac trackpad (you "push" the desktop away). If that feels
backwards, swap `KEY_RIGHT` and `KEY_LEFT` in the config and run
`sudo systemctl restart logid`.

### 3. Start the service

```bash
sudo systemctl enable --now logid
```

## The gotcha: power-cycle the mouse

When I first set this up, nothing happened. The logs showed:

```
[INFO] Detected receiver at /dev/hidraw2
[DEBUG] /dev/hidraw2:4 timed out, waiting for input from device to initialize.
```

logid found the receiver but never set up the mouse, because the mouse was already
connected and idle when logid started. Moving it and clicking didn't help. **Turning
the mouse off and on** did: the mouse announces itself to the receiver again, logid
catches it, and you get:

```
[INFO] Device found: MX Master 3S on /dev/hidraw2:4
```

After that it works, including after reboots, since logid starts before the mouse
connects. If the thumb button ever stops working, the watchdog below usually brings it
back on its own. If it doesn't, power-cycle the mouse.

## The second gotcha: it stops working when the keyboard connects

If you also have an MX Keys (or any other Logitech device) on the same Bolt receiver,
the thumb button can suddenly stop working. In my case the log showed the mouse going
to sleep and never coming back:

```
[INFO] /dev/hidraw2:4 fell asleep.
```

The mouse was awake and answering on the receiver, but logiops 0.3.x missed the wake-up
event, so it never re-applied the config. Restarting logid fixed it every time.

So the installer also adds a tiny watchdog
([`watchdog/logid-watchdog`](watchdog/logid-watchdog)), run by a systemd timer every
20 seconds. It pings each device logid has configured before. If a device answers but
logid hasn't noticed it's awake on two checks in a row, the watchdog restarts logid.
Worst case, the button comes back on its own within about 40 seconds.

```bash
systemctl list-timers logid-watchdog.timer    # is it running?
journalctl -u logid-watchdog                  # has it had to restart logid?
```

## Troubleshooting

**Check what logid sees:**

```bash
sudo systemctl stop logid
sudo logid -v DEBUG      # power-cycle the mouse now, then Ctrl+C
sudo systemctl start logid
```

Look for the `Device found:` line. The name in `logid.cfg` has to match it exactly.

**It says `MX Master 3S B`:** that's the business edition. Re-run the installer with
`./install.sh --business`, or change the `name:` line by hand.

**Scrolling is too fast:** make sure the config has `hires: false` under `hiresscroll`,
then restart logid and power-cycle the mouse.

**The mouse is paired to several computers (Easy-Switch):** logid only configures it
on the channel it's connected to. Pick this computer's channel, then power-cycle.

**Undo everything:**

```bash
sudo systemctl disable --now logid-watchdog.timer logid
sudo rm /etc/systemd/system/logid-watchdog.{service,timer} /usr/local/bin/logid-watchdog
sudo systemctl daemon-reload
sudo apt remove logiops
sudo rm /etc/logid.cfg
```

## License

MIT
