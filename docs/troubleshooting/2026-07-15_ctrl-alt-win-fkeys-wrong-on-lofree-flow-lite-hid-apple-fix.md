---
title: Lofree Flow Lite keyboard — Alt/Win swapped and F-keys act as media keys on Ubuntu
summary: The Lofree Flow Lite's 2.4GHz dongle spoofs an Apple keyboard USB ID, so Linux's hid_apple driver handles it with Mac-oriented defaults; fixed via hid_apple module parameters.
symptoms:
  - Physical Windows/Cmd key sends Alt instead of Super
  - Physical Alt key sends Super/Windows (opens GNOME Activities overview) instead of Alt
  - F1-F12 act as media/brightness keys by default; Fn+F2 is needed to get a plain F2
tags: [keyboard, lofree, hid_apple, ubuntu, gnome, modprobe, systemd, fn-keys, alt, super]
date: 2026-07-15
---

## Symptoms

- Pressing the physical **Windows/Cmd** key does nothing GNOME-Super-like — `xev` shows it sending the **Alt_L** keycode (X keycode 64) instead.
- Pressing the physical **Alt** key opens the GNOME Activities overview — `xev` never sees the event because it's actually sending **Super/Meta**, which GNOME's compositor grabs globally before it reaches any X11 client.
- Pressing **F2** alone triggers a media/brightness action (nothing forwarded to the focused app); only **Fn+F2** produces a plain `F2` keysym.
- (Not a bug: if Ctrl and Alt also look swapped, check GNOME Tweaks → Keyboard & Mouse → "Ctrl+Alt" swap option first — that's a common independent user setting, not related to the issue below.)

## Root cause

The Lofree Flow Lite's **2.4GHz USB dongle** identifies itself over USB as a genuine Apple product: `lsusb` shows `ID 05ac:024f Apple, Inc. Aluminium Keyboard (ANSI)`, even though the device's own string descriptor is `CX 2.4G Wireless Receiver`. Because of that spoofed vendor/product ID, Linux binds it to the kernel's **`hid_apple`** driver (see `/sys/bus/hid/drivers/apple/`) instead of a generic HID driver.

`hid_apple` has Mac-oriented defaults, controlled by module parameters in `/sys/module/hid_apple/parameters/`:

- `fnmode` — default `3` (`auto`), which behaves like media-keys-first. Setting it to `2` (`fkeysfirst`) makes F1-F12 act as normal function keys by default, with Fn+F-key giving the media/brightness action.
- `swap_opt_cmd` — default `0` ("as-is, Mac layout"), which maps the physical **Option**-position key to Alt and the physical **Command**-position key to Super/Meta. On a keyboard that's physically laid out for Windows (Ctrl, Win, Alt from left to right) rather than Mac (Control, Option, Command), this makes the Win-position key send Alt and the Alt-position key send Super. Setting it to `1` ("swapped, Windows layout") fixes this.

Diagnosed by watching `xev -event keyboard` output while tapping each modifier key individually (had to restart `xev` cleanly between tests — reusing a truncated log file while the old process keeps its file offset produces a garbled/null-padded log).

## Fix

Confirm the driver is in play:

```bash
lsusb | grep -i apple                       # dongle shows up spoofing an Apple product ID
ls /sys/bus/hid/drivers/apple/               # device instance(s) bound to hid_apple
cat /sys/module/hid_apple/parameters/fnmode  # current value
```

Apply the reversible fix (installed as `~/.local/bin/lofree-flow-lite-fix`, symlinked from `~/.dotfiles/bin/lofree-flow-lite-fix`):

```bash
lofree-flow-lite-fix enable    # apply: fnmode=2, swap_opt_cmd=1
lofree-flow-lite-fix status    # check current state
lofree-flow-lite-fix disable   # revert to stock defaults (fnmode=3, swap_opt_cmd=0)
```

The script writes `/etc/modprobe.d/99-lofree-flow-lite.conf`, and also applies the values live via sysfs plus an unbind/rebind of the driver so the change takes effect immediately without needing a reboot or `update-initramfs` (confirmed `hid_apple` isn't part of this system's initramfs, so that step is unnecessary here).

Because this only ever touches `hid_apple` module parameters — never xkb, GNOME settings, or udev hwdb — it has zero effect on any other keyboard (e.g. the laptop's built-in keyboard, or a genuine Apple keyboard) unless that keyboard is *also* recognized as an Apple-ID device.

## Gotcha: the modprobe.d file alone did not survive a reboot

After a reboot, `/etc/modprobe.d/99-lofree-flow-lite.conf` was still present and correct, and `modprobe -c | grep hid_apple` confirmed it resolves cleanly with no conflicting files — but the live driver came up with stock defaults (`fnmode=3`, `swap_opt_cmd=0`) anyway. Manually reloading the module confirmed the config file itself was fine and picked up correctly:

```bash
sudo modprobe -r hid_apple
sudo modprobe hid_apple
cat /sys/module/hid_apple/parameters/fnmode        # → 2, correctly picked up the conf file
cat /sys/module/hid_apple/parameters/swap_opt_cmd  # → 1
```

So something loads `hid_apple` at boot through a path that bypasses modprobe's normal config resolution (a known quirk with wireless HID dongles — some community write-ups for this exact keyboard mention having to re-apply the fix on every boot for the same reason). Rather than chase the exact boot-ordering root cause, the script now also installs a oneshot **systemd service** (`lofree-flow-lite-fix.service`, `WantedBy=multi-user.target`) that reapplies the live sysfs values + reprobes the device on every boot, independent of how/when the module actually got loaded. `lofree-flow-lite-fix enable` installs and enables it; `disable` removes and disables it — so the fix (and its removal) is still a single reversible command.

## Notes

- Untouched on purpose: `iso_layout` (left at `-1`/auto) and `swap_ctrl_cmd` / `swap_fn_leftctrl` (left at defaults) — no symptoms pointed to those needing to change for this specific keyboard/layout.
- If reconnecting via Bluetooth also spoofs an Apple ID, the same fix should apply automatically since it's not tied to a specific USB path — only to the `hid_apple` driver binding. A wired USB-C cable connection was not tested and may present a different (non-Apple) USB ID, which would need a different fix (e.g. udev hwdb or `xkb`/`keyd` remapping) if it exhibits the same symptoms.
