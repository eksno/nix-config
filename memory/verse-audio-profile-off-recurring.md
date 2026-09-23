---
type: project
title: verse built-in audio vanishes — WirePlumber card profile lands on "off"
created: 2026-08-26
---

# verse: built-in speakers/mics vanish (WirePlumber profile `off`)

**Recurring hardware/stack quirk on verse (ASUS Zenbook UX3405MA, sof-hda-dsp).**
Seen 2026-04-25 and again 2026-08-26. Expect it again.

## Signature
`wpctl status` shows the ALSA device but **zero real sinks**; `Dummy Output` is the
default sink. ALSA itself is fine (`/proc/asound/cards`, `aplay -l`, `arecord -l` all
list card0 `sofhdadsp`) — the failure is above ALSA.

## Cause
The card enumerates its HiFi profile under **two different names** depending on the
boot: `HiFi (… Mic1, Mic2, Speaker)` vs `HiFi (… Headphones, Mic1, Mic2)`. WirePlumber
persists the elected name in `~/.local/state/wireplumber/default-profile`. When the
next boot enumerates the *other* variant, the saved name doesn't exist and the
replacement reports `available=no`, so WirePlumber elects `off` — no profile, no nodes.
The mechanism behind the name flip is **not established** (the CS35L41-probe-race theory
was weakened on 2026-08-26; see FIXES.md).

## Fix (both steps, in order)
```
wpctl set-profile <device-id> 1        # forces the lone HiFi profile despite available=no
systemctl --user restart wireplumber   # re-elects, usually landing on the Speaker variant
wpctl set-volume <sink-id> 0.5 && wpctl set-mute <sink-id> 0   # saved volume comes back 0.00
```

## Gotchas
- `pactl` is **not installed** on this box — use `wpctl` / `pw-dump` / `amixer`.
- Persisting the fix does **not** prevent recurrence; the saved name is what breaks the
  next divergent boot.
- Don't re-debug the kernel/SOF/CS35L41 layer — it has been healthy both times.

Full detail: `FIXES.md` entries `2026-08-26 builtin-audio-gone-again-…` and
`2026-04-25 builtin-audio-disappeared-…`.
