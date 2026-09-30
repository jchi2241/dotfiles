---
title: yuchichi Wi-Fi password prompt after standby on ThinkPad P16s MT7925
summary: After suspend/resume the first 5 GHz 4-way handshake times out (reason=15); NetworkManager asks for a "new" password even though the PSK is correct. auth-retries does not apply to WPA-PSK. Fix with a systemd post-resume reconnect hook.
symptoms:
  - Password dialog every time the laptop wakes from standby/sleep
  - Logs: wake requested → 4WAY_HANDSHAKE_TIMEOUT → "asking for new key"
  - Sometimes "User canceled the secrets request" or "No agents were available"
  - Same stored PSK succeeds on a later manual retry
  - August 2026 band=a / auth-retries profile still shows all green in status
root_cause: mt7925e firmware is not ready for EAPOL immediately after resume; the first handshake fails. NetworkManager treats association-drop as a wrong password and asks the secret agent for a new key. connection.auth-retries only applies to 802.1x, so it never absorbed these WPA-PSK failures.
fix: PARTIALLY CORRECTED 2026-08-28 — diagnosis is right, but the hook was installed to /etc/systemd/system-sleep, which systemd 255 never reads, so it never ran. See the Aug 28 note for the working install path and dispatch.
tags: [wifi, mt7925, mt7925e, networkmanager, yuchichi, thinkpad, suspend, resume, standby, wpa, 4way]
date: 2026-08-27
---

# yuchichi Wi-Fi password prompt after standby (MT7925)

> **Corrected 2026-08-28.** The root-cause analysis below is accurate, but the
> hook shipped here never executed: it was written to `/etc/systemd/system-sleep`,
> which systemd 255 does not scan, and its `post` work was backgrounded into a
> cgroup systemd tears down. See
> [`2026-08-28_resume-hook-never-ran-on-systemd-255-etc-system-sleep-ignored.md`](./2026-08-28_resume-hook-never-ran-on-systemd-255-etc-system-sleep-ignored.md).

## Symptoms

- Every wake from standby: GNOME asks for the `yuchichi` password again
- `journalctl -u NetworkManager` around wake:

```text
manager: sleep: wake requested
Activation: (wifi) connection 'yuchichi' has security, and secrets exist.  No new secrets needed.
...
supplicant interface state: 4way_handshake -> disconnected
Activation: (wifi) disconnected during association, asking for new key
no secrets: User canceled the secrets request.   # or: No agents were available
```

- Kernel: `deauthenticated ... Reason: 15=4WAY_HANDSHAKE_TIMEOUT`
- `yuchichi-wifi-fix status` still all green (ASPM, powersave, band=a)

## Root cause

Same MediaTek `mt7925e` EAPOL drop as the Aug 20 note, but the **resume** path is worse:

1. Laptop suspends; NM puts wifi unmanaged.
2. On wake the radio/firmware needs a few seconds to settle.
3. NM immediately reconnects; first 4-way handshake times out.
4. NM assumes wrong password → secret-agent dialog (or fails hard if the session is still locked: "No agents were available").
5. Canceling the dialog leaves wifi disconnected until a manual reconnect.

### Why the Aug 20 fix did not stop this

`connection.auth-retries` is documented to apply **only to 802.1x**. For WPA-PSK it is a no-op. The profile settings (band=a, powersave off, ASPM off) still help throughput and reduce some flake, but they do not prevent the post-resume password dialog.

## Fix

```bash
yuchichi-wifi-fix              # apply (installs resume hook; no reboot)
yuchichi-wifi-fix status       # confirm "resume hook present"
```

Source: `~/.dotfiles/bin/yuchichi-wifi-fix` → `~/.local/bin/yuchichi-wifi-fix`

### What the resume hook does

`/etc/systemd/system-sleep/yuchichi-wifi-resume`:

1. **pre-suspend:** `nmcli radio wifi off` — prevents NM from racing into a cold handshake on wake.
2. **post-resume:** wait 5 seconds (override with `RESUME_DELAY_SEC`), `nmcli radio wifi on`, then `nmcli connection up id yuchichi` with the stored PSK.

Logs: `journalctl -t yuchichi-wifi-resume` and `/tmp/yuchichi-wifi-resume.log`.

## Verify

1. `yuchichi-wifi-fix status` → resume hook present.
2. Suspend (lid or `systemctl suspend`), wait ~30s, wake.
3. Within ~10s wifi should return on 5 GHz with **no** password dialog.
4. Confirm: `journalctl -b -t yuchichi-wifi-resume --no-pager`

## Related

- Throughput / 5 GHz preference: `docs/troubleshooting/2026-08-20_yuchichi-wifi-slow-on-mt7925-5ghz-auth-retries.md`
- Old 2.4 GHz lock (superseded): `docs/troubleshooting/2026-07-29_yuchichi-wifi-password-loop-on-mt7925-aspm-powersave-2ghz-lock.md`
