---
title: Feker Alice80 — VIA says device not compatible on Linux
summary: Chrome can list the Alice80 in the WebHID picker, but VIA fails with "not compatible" because /dev/hidraw* for the VIA raw-HID interface is root-only; fixed with a scoped udev rule.
symptoms:
  - Device appears in the usevia.app picker
  - After loading the Alice80 JSON, Configure says the device is not compatible
  - Keyboard works normally for typing
root_cause: Linux hidraw nodes for USB 36b0:305f default to root:root mode 0600, so WebHID enumeration works but VIA cannot open the 0xFF60 raw-HID channel.
fix: Install a udev rule scoped to 36b0:305f via alice80-via-udev enable; reversible with disable.
tags: [keyboard, alice80, feker, via, udev, hidraw, linux, webhid]
date: 2026-07-20
---

## Symptoms

- [usevia.app](https://www.usevia.app/) shows the Alice80 in the device picker.
- Loading `Alice80 wired.JSON` in the Design tab succeeds.
- Configure still reports the device is not compatible.
- Typing works; this is only a VIA/WebHID access problem.

## Root cause

`lsusb` shows `ID 36b0:305f RDMCTMZT Alice80`. The board exposes three HID interfaces, including a QMK/VIA raw-HID interface on usage page `0xFF60`.

On Linux those map to `/dev/hidraw*` nodes owned by `root:root` with mode `0600`. Chrome can still authorize/list the device, but VIA cannot open the raw channel — which surfaces as "not compatible" even when the JSON VID/PID matches.

Confirmed by:

```bash
lsusb -d 36b0:305f
ls -l /dev/hidraw*   # Alice80 nodes are crw------- root root
```

## Fix

Reversible helper (symlinked to `~/.local/bin/alice80-via-udev` from `~/.dotfiles/bin/alice80-via-udev`):

```bash
alice80-via-udev enable    # install /etc/udev/rules.d/99-alice80-via.rules
alice80-via-udev status    # check rule + live hidraw perms
alice80-via-udev disable   # remove rule and restore root-only perms
```

The rule is scoped to USB `36b0:305f` only, so other keyboards (including the Lofree Flow Lite) are unaffected. You generally do **not** need to disable this when swapping boards.

After enabling, reload usevia.app, authorize the keyboard again, and re-load the JSON if needed:

```text
~/Downloads/Feker_Alice80_wired.JSON/Alice80 wired.JSON/Alice80 wired.JSON
```

## Notes

- Use a Chromium-based browser (Chrome / Edge / Chromium). Firefox lacks WebHID.
- Keep the board in wired mode (`Fn+N`) while using VIA.
- If permissions are fixed and VIA still fails, the remaining suspect is non-VIA stock firmware — some Alice80 units need the manufacturer's VIA firmware flash first.
