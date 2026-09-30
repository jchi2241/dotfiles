---
title: mt7925e firmware reset breaks the 4-way handshake until the driver is reloaded
summary: The recurring "Wi-Fi asks for the password again" failures are not really about suspend. The mt7925e chip does a firmware recovery (re-loads firmware without a PCI re-probe); afterwards it still associates but can never complete the WPA 4-way handshake. Suspend/resume was only one way to reach that state. A full `modprobe -r mt7925e && modprobe mt7925e` clears it.
symptoms:
  - Password dialog / "asking for new key" with no suspend anywhere in the journal
  - Kernel logs the mt7925e HW/SW + WM Firmware Version banners a second time mid-session
  - Immediately after, `wlp194s0: Driver requested disconnection from AP`
  - From then on every attempt associates (`AssocResp status=0`) but dies at `Reason: 15=4WAY_HANDSHAKE_TIMEOUT`
  - wpa_supplicant reports `WRONG_KEY` and escalating `SSID-TEMP-DISABLED` even though the PSK is correct
  - Wi-Fi can stay broken for hours; reconnect attempts do not recover it
root_cause: mt7925e performs a firmware recovery/reset while running. The recovery path reloads firmware but does not fully re-initialise the chip, leaving its EAPOL/crypto path broken — association works, the 4-way handshake never completes. NetworkManager interprets the handshake timeout as a bad password and asks for new secrets. Resume-from-suspend hits the same broken state because it also re-initialises the chip.
fix: `yuchichi-wifi-fix apply` installs a systemd watcher that detects future mt7925e firmware reload banners and starts an automatic recovery job. Recovery temporarily disables NetworkManager autoconnect, retries with the existing PSK, reloads mt7925e after two failures, and restores autoconnect. The same helper handles resume.
tags: [wifi, mt7925, mt7925e, networkmanager, yuchichi, thinkpad, firmware, reset, handshake, eapol, modprobe, wpa_supplicant]
date: 2026-09-04
updated: 2026-09-17
---

# mt7925e firmware reset breaks the 4-way handshake

Third round on this. The Aug 27 and Aug 28 notes both framed it as a
suspend/resume problem. It is not — suspend was just one trigger.

## The observation that reframed it

On the 2026-09-03 boot the password prompt came back, but:

```bash
$ journalctl -b | rg "PM: suspend (entry|exit)"
# (nothing — no suspend at all this boot)
```

The link was solid for nearly eight hours after boot, then:

```text
Sep 03 12:54:20  mt7925e 0000:c2:00.0: enabling device (0000 -> 0002)
Sep 03 12:54:20  mt7925e 0000:c2:00.0: ASIC revision: 79250000
Sep 03 12:54:20  mt7925e 0000:c2:00.0: HW/SW Version: 0x8a108a10 ...      <- normal boot load
Sep 03 12:54:21  mt7925e 0000:c2:00.0: WM Firmware Version: ...

Sep 03 20:44:18  mt7925e 0000:c2:00.0: HW/SW Version: 0x8a108a10 ...      <- firmware loaded AGAIN
Sep 03 20:44:18  mt7925e 0000:c2:00.0: WM Firmware Version: ...
Sep 03 20:44:19  wlp194s0: Driver requested disconnection from AP 0c:c7:63:23:10:c7
```

Note what is **missing** from the 20:44 block: no `enabling device`, no
`ASIC revision`. The driver reloaded firmware into the chip without a PCI
re-probe — that is the mt76 error-recovery path, i.e. **the firmware crashed and
was restarted**.

Everything after that point fails identically:

```text
20:44:26  deauthenticated ... (Reason: 15=4WAY_HANDSHAKE_TIMEOUT)
23:13:01  deauthenticated ... (Reason: 15=4WAY_HANDSHAKE_TIMEOUT)
23:13:07  deauthenticated ... (Reason: 15=4WAY_HANDSHAKE_TIMEOUT)
...
Sep 04 10:28-10:30  five more, then finally connected
```

Wi-Fi was down from 23:13 to 10:28 — overnight — and only came back after
repeated manual attempts.

## Root cause

After a firmware recovery the chip **associates fine but cannot complete the
4-way handshake**. Every failed attempt shows `RX AssocResp ... status=0`
followed by an EAPOL timeout. wpa_supplicant cannot tell a broken crypto path
from a wrong password, so it logs:

```text
WPA: 4-Way Handshake failed - pre-shared key may be incorrect
CTRL-EVENT-SSID-TEMP-DISABLED ... reason=WRONG_KEY
```

and NetworkManager turns that into `asking for new key` → the password dialog.

This single mechanism explains every episode so far:

| Trigger | What it does to the chip |
| --- | --- |
| Resume from suspend | re-initialises the chip → same broken EAPOL window |
| Firmware crash/recovery mid-session | re-initialises the chip → same broken EAPOL window |

The Aug 28 note's "EAPOL is dropped for ~35 s after radio-on" was the same
effect seen through a narrower window; sometimes it self-clears, sometimes (as
overnight here) it does not clear for hours.

## Fix

Install the automatic recovery once:

```bash
yuchichi-wifi-fix apply
```

This enables `yuchichi-wifi-watch.service`. It follows new kernel messages
without replaying boot history. When it sees the MT7925 firmware banner appear
mid-boot, it starts `yuchichi-wifi-recover.service`, which:

1. disables profile autoconnect and powers off the radio before NetworkManager
   races into repeated bad-password prompts;
2. waits for firmware to settle, powers the radio back on, and reconnects with
   the stored PSK;
3. after two failures, fully reloads `mt7925e` and keeps retrying outside
   wpa_supplicant's 10-second lockout window;
4. always restores the radio and autoconnect from an exit trap.

`mt7925e` has refcount 0 (`lsmod` shows `mt7925e 24576 0`), so it unloads
cleanly; `mt7925_common`, `mt792x_lib`, `mt76_connac_lib` and `mt76` stay
loaded as dependencies.

The watcher and recovery are separate services. A driver reload produces
another firmware banner, but systemd does not start a second recovery while the
first recovery unit is active. A file lock also prevents overlap with the
resume hook.

Manual fallback remains available:

```bash
yuchichi-wifi-fix recover
```

Logs:

```bash
journalctl -b -t yuchichi-wifi-resume --no-pager
journalctl -b -u yuchichi-wifi-watch.service -u yuchichi-wifi-recover.service
```

## Ruled out

- **Not the AP / not client steering.** Every failure is on the same BSSID
  `0c:c7:63:23:10:c7` (ch 36). Client steering was disabled on the eero and the
  failures continued — expected, since the trigger is a local firmware crash.
  The AP has three BSSIDs: `…c6` 2.4 GHz, `…c7` 5 GHz, `…c8` 6 GHz WPA3.
- **Not a wrong PSK.** Same stored key succeeds once the chip is healthy.
- **Not stale firmware.** `Build Time: 20260605184805`, already updated once via
  `~/mt7925-fw-update/apply.sh`.
- **Not the resume hook being broken.** That was the Aug 28 bug and it is fixed;
  this boot never suspended.

## Open question

Why the firmware reinitializes is still unresolved. During the Sep 9–17 boot it
happened six times, usually 34–37 hours apart. One event logged
`Message 00020016 ... timeout`; the others only showed the reload banners.
There were no SWIOTLB exhaustion warnings, and all 47 recorded associations
used the same 5 GHz BSSID, ruling out steering/roaming as the immediate cause.

This matches upstream [openwrt/mt76#1103](https://github.com/openwrt/mt76/issues/1103):
the same firmware build drops EAPOL after initialization even on kernel 7.0.
The upstream issue remains open as of 2026-09-17.

Worth capturing after another event:

```bash
journalctl -b -k | rg -i "mt7925e|mt76"
ls /sys/kernel/debug/ieee80211/*/mt76/    # fw crash counters, if exposed
```

If it recurs often, the next lever is checking whether disabling ASPM entirely
at the PCIe level (kernel `pcie_aspm=off`) or a newer `linux-firmware` changes
the crash rate.

## Related

- Hook delivery bugs: `docs/troubleshooting/2026-08-28_resume-hook-never-ran-on-systemd-255-etc-system-sleep-ignored.md`
- Resume-path diagnosis: `docs/troubleshooting/2026-08-27_yuchichi-wifi-password-after-standby-on-mt7925-resume-hook.md`
- Throughput / 5 GHz preference: `docs/troubleshooting/2026-08-20_yuchichi-wifi-slow-on-mt7925-5ghz-auth-retries.md`
