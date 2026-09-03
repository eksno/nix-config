---
type: project
title: Phonetic mic dead / no audio sources → restart wireplumber
created: 2026-09-03
---

On `lewis` (ASUS Zenbook UX3405MA, SOF `sof-hda-dsp`), WirePlumber intermittently
leaves `alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic` on profile `off`
after a boot. In that state ACP exposes only `off` and `pro-audio` — no HiFi — so
PipeWire has **zero audio Sources** and the only sink is `Dummy Output`.

**Symptom:** `phonetic --trigger Migrated` fails instantly with
`PaErrorCode -9999 ... [ALSA error -2]` from `pa_linux_alsa.c:2099/2733/2845`.
Any other capture client fails the same way.

**Diagnostic (one command):** `wpctl status` — if the Audio → Sources section is
empty and the only sink is `Dummy Output`, this is it.

**Fix:** `systemctl --user restart wireplumber`. Sources return immediately; no
phonetic restart, no rebuild, no repo change.

**Do NOT re-investigate** the kernel/SOF/UCM layer — firmware, topology, codec
binding and `alsaucm -c hw:0 list _verbs` were all proven healthy on 2026-08-22.
Occurrences: 2026-08-22, 2026-09-03. See FIXES.md entry
`phonetic-mic-dead-paerrorcode-9999`.
