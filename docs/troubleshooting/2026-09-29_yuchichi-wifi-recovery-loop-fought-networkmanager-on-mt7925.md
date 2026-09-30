---
title: yuchichi Wi-Fi recovery helper made MT7925 firmware-reset outages worse
summary: The firmware-reset watcher's nmcli up/down retry loop tore down connections NetworkManager had just made, and driver reloads did not shorten recovery. Replaced with a radio-off settle (45s) that leaves reconnecting to NetworkManager; disabled the mt7925 CLC command that 6.17 sends malformed (fixed upstream in HWE 7.0).
symptoms:
  - Repeated password dialogs for yuchichi, several times a day, with no suspend involved
  - Kernel: "mt7925e ... WM Firmware Version" banner mid-session (spontaneous firmware reset)
  - Followed by several "Reason: 15=4WAY_HANDSHAKE_TIMEOUT" and wpa_supplicant "reason=WRONG_KEY"
  - yuchichi-wifi-resume logs "attempt N/6 failed", sometimes "giving up"
root_cause: mt7925e firmware resets on its own (6 times in boot of Sep 21–28 on 6.17.0-1032-oem, firmware build 20260605). Handshakes fail for ~20–30s afterwards. The old helper kept calling nmcli connection up/down during that window, and on Sep 29 it disconnected a connection that had succeeded 5s earlier (reason=3 locally_generated=1).
fix: yuchichi-wifi-fix apply (new helper + mt7925-common disable_clc=1), reboot. Longer term, HWE 7.0 has the upstream CLC fix (62e037aa).
tags: [wifi, mt7925, mt7925e, networkmanager, yuchichi, thinkpad, firmware, kernel, hwe]
date: 2026-09-29
---

# yuchichi Wi-Fi recovery helper fought NetworkManager (MT7925)

## Evidence

Firmware resets were not tied to suspend.
Resets on Sep 21, 23, 25 (twice), 27, and 29 all happened mid-session.

After a reset, the first handshake at ~19s failed and the next at ~30s succeeded (Sep 23, 25, 27).

Driver reloads did not help.
On Sep 21 every attempt after `modprobe -r mt7925e` still timed out, and Wi-Fi only returned 43 minutes later.
The reload also re-printed the firmware banner, re-triggering the watcher.

On Sep 29 the helper killed a working link:

```text
11:18:48 CTRL-EVENT-CONNECTED - Connection to 0c:c7:63:23:10:c7 completed
11:18:53 CTRL-EVENT-DISCONNECTED bssid=0c:c7:63:23:10:c7 reason=3 locally_generated=1
```

After the helper gave up at 11:19:31, NetworkManager reconnected on its own at 11:20:45.

## Fix

The helper now only keeps the radio off while the firmware settles, then turns it back on and lets NetworkManager autoconnect.
No `connection up/down`, no autoconnect toggling, no driver reload.
Settle times: 13s after resume, 45s after a firmware reset (`RESUME_SETTLE_SEC`, `FW_RESET_SETTLE_SEC`).

```bash
yuchichi-wifi-fix apply
```

### Likely underlying cause: malformed CLC command (added later on 2026-09-29)

6.17.0-1032-oem sends the MT7925 CLC (regulatory) command with a wrong TLV length.
Upstream fix: `62e037aa8cf5` "wifi: mt76: mt7925: fix incorrect TLV length in CLC command" (Cc: stable).
Checked via `apt changelog`: absent from linux-oem-6.17 6.17.0-1032.32, present in linux-hwe-7.0 since 7.0.0-28.

[Red Hat bug 2430575](https://bugzilla.redhat.com/show_bug.cgi?id=2430575) matches: ThinkPad T14 Gen 6 AMD (same `c2:00.0` / `wlp194s0`), WPA2 connects fail and re-prompt for the password on 2026 firmware.
Fixed by `options mt7925-common disable_clc=1` (comments 33–42) and by kernel 7.0.4 with no module options (comment 44).
Their failures were constant; ours cluster after firmware resets, which fits the driver re-sending CLC on every firmware init but is not proven here.

`yuchichi-wifi-fix apply` now writes `/etc/modprobe.d/mt7925-common-disable-clc.conf`.
The modules are not in the initramfs, so a reboot is enough.
Cost: the chip skips its per-country power table and uses the kernel regdb, which mainly limits 6 GHz (unused).

Firmware rollback to the 20251210 backup was ruled out: it is reported bad on the same laptop family (pop-os#3995), and the machine ran it Apr–Jul while already troubleshooting.

If `disable_clc` helps, move to the HWE kernel and drop the option:

```bash
sudo apt install linux-generic-hwe-24.04
sudo reboot
```

The 6.17 OEM kernel stays in GRUB "Advanced options" as a fallback.

## Verify

```bash
uname -r                                         # 6.17.0-1032-oem now; 7.0.x-generic after HWE
yuchichi-wifi-fix status
journalctl -b -k | grep -cE 'WM Firmware Version'  # 1 means no resets since boot
journalctl -b -k | grep -c 4WAY_HANDSHAKE_TIMEOUT
cat /sys/module/mt7925_common/parameters/disable_clc   # Y
journalctl -b -t yuchichi-wifi-resume
```

## Related

- [`2026-08-27_yuchichi-wifi-password-after-standby-on-mt7925-resume-hook.md`](./2026-08-27_yuchichi-wifi-password-after-standby-on-mt7925-resume-hook.md)
- [`2026-08-20_yuchichi-wifi-slow-on-mt7925-5ghz-auth-retries.md`](./2026-08-20_yuchichi-wifi-slow-on-mt7925-5ghz-auth-retries.md)
