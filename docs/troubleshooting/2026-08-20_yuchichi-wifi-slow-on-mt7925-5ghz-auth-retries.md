---
title: yuchichi Wi-Fi slow on ThinkPad P16s MT7925 (5 GHz preference)
summary: Prefer 5 GHz (band=a) plus ASPM/powersave off so throughput recovers (~345 Mbps vs ~30–40 on 2.4 GHz). Password-prompt / resume behavior is covered by the 2026-08-27 note — auth-retries does not apply to WPA-PSK.
symptoms:
  - Laptop stuck at 30–40 Mbps while phone on same SSID gets 400+
  - Associated to 2.4 GHz (2412 MHz / 130 Mbit/s) despite a strong 5 GHz BSSID
  - Occasional reason=15 handshake timeouts on 5 GHz
root_cause: Earlier 2.4 GHz band lock avoided MT7925 5 GHz handshake flake but capped throughput. ASPM/powersave also contribute to flake.
fix: Run yuchichi-wifi-fix (disable_aspm, global powersave=2, profile band=a + powersave/pmf off, plus the post-resume sleep hook).
tags: [wifi, mt7925, mt7925e, networkmanager, yuchichi, thinkpad, aspm, powersave, wpa, 5ghz]
date: 2026-08-20
updated: 2026-08-27
---

# yuchichi Wi-Fi slow / 5 GHz preference (MT7925)

## Symptoms

- Speed ~30–40 Mbps on the laptop; phone on `yuchichi` gets 400+
- `nmcli` shows 2.4 GHz association (`2412 MHz`, PHY rate ~130 Mbit/s)

## Root cause

An older workaround locked the profile to **2.4 GHz** (`band=bg`) for handshake stability. That was stable but slow. Prefer 5 GHz with ASPM/powersave mitigations instead.

MediaTek `mt7925e` (ThinkPad P16s Gen 4 AMD) still sometimes drops the first EAPOL on 5 GHz (reason=15). That path — especially after **standby** — is handled by the resume hook, not by `auth-retries`.

**Correction (2026-08-27):** `connection.auth-retries` only applies to **802.1x**, not WPA-PSK. Setting it to 10 never absorbed these failures. See the standby note linked below.

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
3. Profile `yuchichi`: `band=a`, `powersave=2`, `pmf=1`
4. `/etc/systemd/system-sleep/yuchichi-wifi-resume` — post-resume reconnect (see Aug 27 note)

## Verified (2026-08-20)

- 5 GHz connect: channel 36 / 5180 MHz, PHY ~270 Mbit/s
- Download ~345 Mbps (Cloudflare 50 MB) vs ~30–40 Mbps on the old 2.4 GHz lock

## Related

- **Password prompt after standby:** [`2026-08-27_yuchichi-wifi-password-after-standby-on-mt7925-resume-hook.md`](./2026-08-27_yuchichi-wifi-password-after-standby-on-mt7925-resume-hook.md)
- Old 2.4 GHz lock (superseded): `docs/troubleshooting/2026-07-29_yuchichi-wifi-password-loop-on-mt7925-aspm-powersave-2ghz-lock.md`
- Optional older firmware staging: `~/mt7925-fw-update/`
