---
title: yuchichi Wi-Fi slow / password prompt on ThinkPad P16s MT7925
summary: MT7925 drops the first 5 GHz 4-way handshake (reason=15); NetworkManager mis-reports it as a wrong password. Prefer 5 GHz with auth-retries=10 so retries stay silent and throughput recovers (~345 Mbps vs ~30–40 on 2.4 GHz).
symptoms:
  - Laptop stuck at 30–40 Mbps while phone on same SSID gets 400+
  - Associated to 2.4 GHz (2412 MHz / 130 Mbit/s) despite a strong 5 GHz BSSID
  - NetworkManager password dialog after 5 GHz connect attempts
  - Logs show reason=15 (4WAY_HANDSHAKE_TIMEOUT) then "asking for new key"
  - Same PSK succeeds on a later retry
root_cause: MediaTek mt7925e firmware silently drops the first EAPOL 2/4 after a band/firmware path change on 5/6 GHz. NM exhausts default auth retries and prompts for a new secret even though the stored PSK is correct. The earlier 2.4 GHz band lock avoided the bug but capped throughput.
fix: Run yuchichi-wifi-fix (disable_aspm, global powersave=2, profile band=a + auth-retries=10 + powersave/pmf off).
tags: [wifi, mt7925, mt7925e, networkmanager, yuchichi, thinkpad, aspm, powersave, wpa, auth-retries, 5ghz]
date: 2026-08-20
---

# yuchichi Wi-Fi slow / password prompt (MT7925)

## Symptoms

- Speed ~30–40 Mbps on the laptop; phone on `yuchichi` gets 400+
- `nmcli` shows 2.4 GHz association (`2412 MHz`, PHY rate ~130 Mbit/s)
- Password dialog after 5 GHz attempts even when the PSK is correct
- Kernel: `deauthenticated ... Reason: 15=4WAY_HANDSHAKE_TIMEOUT`
- NetworkManager: `disconnected during association, asking for new key`

## Root cause

MediaTek `mt7925e` (ThinkPad P16s Gen 4 AMD, ASIC `79250000`) against the tri-band AP `yuchichi`:

1. Association to 5 GHz succeeds.
2. First 4-way handshake often times out (EAPOL 2/4 never leaves the radio).
3. NetworkManager treats the timeout as a wrong password and prompts.
4. An immediate retry with the **same** stored PSK usually completes.

This matches upstream reports (e.g. openwrt/mt76#1103). ASPM/powersave mitigations help other paths but do not fix the dropped first EAPOL. An older workaround locked the profile to **2.4 GHz** (`band=bg`), which was stable but slow.

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
3. Profile `yuchichi`:
   - `band=a` — prefer 5 GHz (BSSID left unset for mesh roaming)
   - `connection.auth-retries=10` — silent retries with the stored PSK; avoids the password dialog
   - `powersave=2`, `pmf=1`

## Why auth-retries works

On handshake failure NM enters `need-auth`. While retries remain it re-uses the **stored** secret (`No new secrets needed`). Only after retries are exhausted does it ask the agent for a **new** secret (the UI prompt). Default is effectively 3; `10` absorbs the MT7925 flake. Use `0` for infinite retries if you accept never being prompted when the real password changes.

## Verified (2026-08-20)

- 5 GHz connect: channel 36 / 5180 MHz, PHY ~270 Mbit/s
- Download ~345 Mbps (Cloudflare 50 MB) vs ~30–40 Mbps on the old 2.4 GHz lock
- Handshake timeout still occurs sometimes; with `auth-retries=10` NM recovers without a password dialog

## Notes

- "Forget network" creates a new profile — re-run `yuchichi-wifi-fix apply`
- Do not re-apply the old `band=bg` lock unless 5 GHz is unusable
- Optional older firmware staging still lives under `~/mt7925-fw-update/` (`apply.sh` / `recover.sh`)
- Earlier 2.4 GHz-lock write-up: `docs/troubleshooting/2026-07-29_yuchichi-wifi-password-loop-on-mt7925-aspm-powersave-2ghz-lock.md` (superseded)
