---
title: yuchichi Wi-Fi resume hook never ran — systemd 255 ignores /etc/systemd/system-sleep
summary: The Aug 27 post-resume reconnect hook was installed to /etc/systemd/system-sleep, which systemd 255 does not scan (only /usr/lib/systemd/system-sleep; /etc support landed in v256). The hook also backgrounded its work with `&`, which systemd-suspend.service kills with its cgroup. Fixed by installing to /usr/lib and dispatching the delayed reconnect via systemd-run.
symptoms:
  - Password dialog still appears after standby despite `yuchichi-wifi-fix status` showing "resume hook present"
  - `journalctl -b -t yuchichi-wifi-resume` returns "No entries" even though suspends occurred
  - /tmp/yuchichi-wifi-resume.log does not exist
  - Kernel still logs `Reason: 15=4WAY_HANDSHAKE_TIMEOUT` on the first post-resume association
root_cause: Two independent bugs. (1) systemd 255 (Ubuntu 24.04) compiles a single SYSTEM_SLEEP_PATH of /usr/lib/systemd/system-sleep; /etc/systemd/system-sleep is not read until systemd 256, so the hook was never executed. (2) systemd-suspend.service is Type=oneshot with KillMode=control-group, so the hook's `( sleep 5; ... ) &` subshell would be SIGTERMed as soon as the hook returned, even once the path was correct.
fix: yuchichi-wifi-fix now installs the hook to /usr/lib/systemd/system-sleep/yuchichi-wifi-resume, removes the stale /etc copy, and has the post branch launch /usr/local/sbin/yuchichi-wifi-reconnect through `systemd-run --no-block --collect` so the delayed reconnect survives in its own transient unit. The helper retries 4 times.
tags: [wifi, mt7925, mt7925e, networkmanager, yuchichi, thinkpad, suspend, resume, systemd, systemd-sleep, system-sleep, cgroup, systemd-run]
date: 2026-08-28
---

# Resume hook never ran (systemd 255 ignores /etc/systemd/system-sleep)

Follow-up to [`2026-08-27_yuchichi-wifi-password-after-standby-on-mt7925-resume-hook.md`](./2026-08-27_yuchichi-wifi-password-after-standby-on-mt7925-resume-hook.md).
That note's diagnosis was right; the *delivery* of the fix was broken, so the
password dialog kept appearing.

## Symptoms

`yuchichi-wifi-fix status` was all green, including `resume hook present`, yet
the wake on 2026-08-28 10:26 still failed:

```text
10:26:48.360  policy: auto-activating connection 'yuchichi'
10:26:48.525  supplicant interface state: associating -> 4way_handshake
10:26:53.635  kernel: deauthenticated ... (Reason: 15=4WAY_HANDSHAKE_TIMEOUT)
10:26:53.777  wpa_supplicant: 4-Way Handshake failed - pre-shared key may be incorrect
10:26:53.784  Activation: (wifi) disconnected during association, asking for new key
10:26:53.791  no secrets: User canceled the secrets request.
```

The tell: **the hook produced no log lines at all.**

```bash
journalctl -b -t yuchichi-wifi-resume --no-pager   # -- No entries --
ls /tmp/yuchichi-wifi-resume.log                   # No such file
```

`logger -t yuchichi-wifi-resume test` worked fine, so the hook simply never ran.

## Root cause 1 — wrong directory

Unlike most systemd drop-in directories, sleep hooks are **not** searched in
both `/usr` and `/etc`. On systemd 255 there is exactly one path:

```bash
$ strings /usr/lib/systemd/systemd-sleep | rg system-sleep
/usr/lib/systemd/system-sleep

$ man systemd-suspend.service | rg system-sleep
       /usr/lib/systemd/system-sleep
       will run all executables in /usr/lib/systemd/system-sleep/ and pass two
```

`/etc/systemd/system-sleep/` support was only added in **systemd 256**. Ubuntu
24.04 ships 255, so the hook sat there inert.

### How to confirm hooks run at all

`sysstat` ships a hook in the correct directory, and its datafile mtime is a
free timestamp of every pre/post invocation:

```bash
ls -la --time-style=full-iso /var/log/sysstat/
# sa27 ... 2026-08-27 22:54:09  <- pre-suspend
# sa28 ... 2026-08-28 10:26:42  <- post-resume
```

Those matched the suspend/resume times exactly, proving systemd was running
hooks and that only *our* file was being skipped.

## Root cause 2 — backgrounded work gets killed

Even in the right directory the original hook would have failed. It did:

```sh
post)
  ( sleep 5; nmcli connection up id "$SSID" ) &
```

`systemd-suspend.service` is `Type=oneshot` with the default
`KillMode=control-group`:

```bash
$ systemctl show systemd-suspend.service -p Type -p KillMode
Type=oneshot
KillMode=control-group
```

When the hook returns, the service completes and systemd tears down the cgroup,
SIGTERMing the still-sleeping subshell. Anything that must outlive the hook has
to escape the cgroup — `systemd-run` gives it its own transient unit.

## Fix

```bash
yuchichi-wifi-fix              # reinstall to the correct path
yuchichi-wifi-fix status       # resume hook + reconnect helper present
```

Layout after apply:

| Path | Role |
| --- | --- |
| `/usr/lib/systemd/system-sleep/yuchichi-wifi-resume` | thin hook; `pre` radio off, `post` dispatch |
| `/usr/local/sbin/yuchichi-wifi-reconnect` | delayed reconnect worker, run detached |

The `post` branch is now just a handoff:

```sh
systemd-run --no-block --collect \
  --unit=yuchichi-wifi-reconnect \
  /usr/local/sbin/yuchichi-wifi-reconnect
```

The worker waits `RESUME_DELAY_SEC` (5) after resume, disables autoconnect,
powers the radio, waits `RESUME_SETTLE_SEC` (8) with the radio up, then tries
`nmcli connection up` up to `RESUME_ATTEMPTS` (6) times with an 11 s gap. See
"Round 2" below for why each of those numbers is what it is.

Safety: if `systemd-run` itself fails, the hook re-enables the radio inline. The
worker restores both the radio and `connection.autoconnect yes` from a trap on
`EXIT`/`INT`/`TERM` — the pre-suspend `nmcli radio wifi off` and the autoconnect
toggle must never be left unpaired. `yuchichi-wifi-fix status` now flags
`autoconnect != yes` for exactly this reason.

## Round 2 — the helper was sabotaging its own first attempt

With the hook finally running, the first verified suspend reconnected, but only
on attempt 4, about 43 s after wake:

```text
12:20:12  pre-suspend: wifi radio off
12:20:16  post-resume: handing off to reconnect helper
12:20:28  attempt 1/4 to reach yuchichi failed
12:20:39  attempt 2/4 to reach yuchichi failed
12:20:51  attempt 3/4 to reach yuchichi failed
12:20:59  reconnected to yuchichi on attempt 4
```

Attempt 1 failed for a self-inflicted reason:

```text
12:20:21.537  audit: op="radio-control" arg="wireless-enabled:on"
12:20:22.216  policy: auto-activating connection 'yuchichi'      <- NM races in 0.7s later
12:20:22.379  supplicant interface state: associating -> 4way_handshake
12:20:22.580  state change: config -> deactivating (reason 'user-requested')
12:20:22.580  audit: op="device-disconnect" pid=642345           <- our own helper
12:20:22.689  WPA: 4-Way Handshake failed - pre-shared key may be incorrect
12:20:22.689  CTRL-EVENT-SSID-TEMP-DISABLED ... duration=10 reason=WRONG_KEY
```

The helper's `nmcli device disconnect` — meant to clear "any half-open
activation" — aborted a handshake that NetworkManager had legitimately started.
wpa_supplicant cannot distinguish a locally-requested deauth mid-handshake from
a bad password, so it logged `WRONG_KEY` and temp-disabled the SSID for 10 s.

Two lessons folded into the current helper:

- **Prevent the race instead of aborting it.** Set
  `connection.autoconnect no` *before* `nmcli radio wifi on`, drive the connect
  explicitly, and restore autoconnect from an `EXIT`/`INT`/`TERM` trap.
- **Respect the penalty window.** A handshake timeout costs ~5.3 s and then a
  10 s `SSID-TEMP-DISABLED`. The old 6 s gap retried inside that window, so the
  gap is now 11 s.

### What is genuinely wrong (not yet solved)

Ruled out by this run:

- **Not a bad AP radio.** Every attempt used the same BSSID
  `0c:c7:63:23:10:c7` (ch 36, 5180 MHz) and got `AssocResp status=0`. The AP
  has three BSSIDs (`…c6` 2.4 GHz, `…c7` 5 GHz, `…c8` 6 GHz WPA3).
- **Not stale firmware.** `WM Firmware Version ... Build Time: 20260605184805`,
  files from Jul 13 2026 — already updated once.

What remains: association succeeds every time, but the mt7925 drops EAPOL
frames for roughly 35 s after the radio is powered on. Every failure is
`Reason: 15=4WAY_HANDSHAKE_TIMEOUT`. The delay is measured from radio-on, not
from resume, which is why the helper now waits `RESUME_SETTLE_SEC` with the
radio up before its first attempt.

Also worth knowing: the driven attempts *do* still ask for secrets —

```text
Activation: (wifi) disconnected during association, asking for new key
no secrets: No agents were available for this request.
```

No dialog appeared only because the GNOME agent was not yet registered (session
still locked). If a reconnect fails while the session is unlocked, the dialog
will appear. Suppressing it entirely means making the first attempt succeed,
not retrying more.

## Verify

```bash
yuchichi-wifi-fix status
systemctl suspend      # wait ~30s, wake
journalctl -b -t yuchichi-wifi-resume --no-pager
```

Expected — and this time the log must be non-empty:

```text
pre-suspend: wifi radio off
post-resume: handing off to reconnect helper
reconnected to yuchichi on attempt 1
```

## Lessons

1. **"Hook file exists" is not "hook runs."** A status check that only stats a
   file reports green on a hook systemd never reads. Verify drop-in *locations*
   against `man` or the binary's compiled paths. `yuchichi-wifi-fix status` now
   also reports the last `yuchichi-wifi-resume` journal line, so a hook that
   never fired cannot show green.
2. **Don't interrupt a handshake to "clean up".** A mid-handshake
   `device disconnect` is indistinguishable from a wrong password to
   wpa_supplicant, and costs a 10 s lockout. Prevent the unwanted connect
   attempt up front instead.
3. **Check whether the retry loop is fighting a backoff.** Three of the four
   attempts were spaced inside the very penalty window the previous failure
   created.

## Related

- Resume-path diagnosis: `docs/troubleshooting/2026-08-27_yuchichi-wifi-password-after-standby-on-mt7925-resume-hook.md`
- Throughput / 5 GHz preference: `docs/troubleshooting/2026-08-20_yuchichi-wifi-slow-on-mt7925-5ghz-auth-retries.md`
