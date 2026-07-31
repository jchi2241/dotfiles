---
title: yuchichi Wi-Fi password-prompt loop on ThinkPad P16s MT7925
summary: MT7925 4-way handshake timeouts were misreported as a wrong password; mitigated with ASPM off, Wi-Fi powersave off, PMF off, and a 2.4 GHz band lock.
symptoms:
  - NetworkManager repeatedly re-asks for the yuchichi Wi-Fi password
  - Logs show reason=15 (4WAY_HANDSHAKE_TIMEOUT) then "pre-shared key may be incorrect"
  - Same PSK connects successfully on a later retry
  - Failures common on 5/6 GHz BSSIDs; 2.4 GHz stable
root_cause: MediaTek mt7925e + tri-band AP handshake instability (ASPM / powersave / WPA3-FT path), not an incorrect password.
fix: Run yuchichi-wifi-fix (disable_aspm, global powersave=2, profile band=bg + powersave/pmf off).
tags: [wifi, mt7925, mt7925e, networkmanager, yuchichi, thinkpad, aspm, powersave, wpa]
date: 2026-07-29
---

# yuchichi Wi-Fi password-prompt loop (MT7925)

## Symptoms

- Password dialog loops for SSID `yuchichi`
- `wpa_supplicant`: `reason=15` then `WRONG_KEY`
- NetworkManager: `asking for new key` even when secrets exist

## Root cause

False "wrong key" from **4-way handshake timeouts** on MediaTek `mt7925e` (ThinkPad P16s Gen 4 AMD) against a tri-band AP advertising one SSID on 2.4 / 5 / 6 GHz. 5/6 GHz paths were flaky; 2.4 GHz was reliable.

## Fix (script in PATH)

```bash
yuchichi-wifi-fix              # apply
yuchichi-wifi-fix apply --reconnect
yuchichi-wifi-fix status
yuchichi-wifi-fix undo         # revert + reboot to restore ASPM
```

Source: `~/.dotfiles/bin/yuchichi-wifi-fix` → `~/.local/bin/yuchichi-wifi-fix`

## What the script sets

1. `/etc/modprobe.d/mt7925e-disable-aspm.conf` → `options mt7925e disable_aspm=1` (reboot if live value is still `N`)
2. `/etc/NetworkManager/conf.d/default-wifi-powersave-on.conf` → `wifi.powersave = 2`
3. Profile `yuchichi`: `band=bg`, `powersave=2`, `pmf=1`

## Notes

- "Forget network" creates a new profile — re-run `yuchichi-wifi-fix apply`
- 2.4 GHz lock trades max throughput for handshake stability (Meet may feel slower than healthy 5 GHz)
- Optional older firmware staging still lives under `~/mt7925-fw-update/` (`apply.sh` / `recover.sh`)
