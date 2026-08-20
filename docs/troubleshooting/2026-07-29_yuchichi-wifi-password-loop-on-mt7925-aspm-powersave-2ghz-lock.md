---
title: yuchichi Wi-Fi password-prompt loop on ThinkPad P16s MT7925 (superseded)
summary: SUPERSEDED 2026-08-20. Original mitigation locked yuchichi to 2.4 GHz for handshake stability. Prefer the current fix (5 GHz + auth-retries=10) in the Aug 20 note.
symptoms:
  - NetworkManager repeatedly re-asks for the yuchichi Wi-Fi password
  - Logs show reason=15 (4WAY_HANDSHAKE_TIMEOUT) then "pre-shared key may be incorrect"
  - Same PSK connects successfully on a later retry
  - Failures common on 5/6 GHz BSSIDs; 2.4 GHz stable
root_cause: MediaTek mt7925e + tri-band AP handshake instability; first EAPOL on 5/6 GHz often dropped. Not an incorrect password.
fix: SUPERSEDED — use yuchichi-wifi-fix with band=a and auth-retries=10 (see 2026-08-20 note). Historical apply used band=bg.
tags: [wifi, mt7925, mt7925e, networkmanager, yuchichi, thinkpad, aspm, powersave, wpa, superseded]
date: 2026-07-29
---

# yuchichi Wi-Fi password-prompt loop (MT7925) — superseded

**Superseded 2026-08-20.** The 2.4 GHz band lock (`band=bg`) stopped the password-prompt loop but capped throughput at ~30–40 Mbps. Current fix prefers 5 GHz and lets NetworkManager retry the stored PSK silently:

→ [`2026-08-20_yuchichi-wifi-slow-on-mt7925-5ghz-auth-retries.md`](./2026-08-20_yuchichi-wifi-slow-on-mt7925-5ghz-auth-retries.md)

## Historical approach (do not re-apply)

```bash
# Old profile settings (slow but stable)
# band=bg, powersave=2, pmf=1
# plus disable_aspm=1 and global wifi.powersave=2
```

`yuchichi-wifi-fix` no longer sets `band=bg`. Running `apply` now sets `band=a` and `connection.auth-retries=10`.
