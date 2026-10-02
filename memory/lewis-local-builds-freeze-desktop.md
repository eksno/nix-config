---
type: project
title: lewis freezes during uncached local builds — throttle them
created: 2026-10-02
---

When a fresh nixpkgs rev has no Hydra cache yet, a lewis rebuild compiles
dozens of derivations locally (2026-10-02, nixpkgs `c59305b`: 92 drvs, incl.
scipy for python 3.12, 3.13 AND 3.14 — heavy C++/Fortran). At default
parallelism (22 threads) Hyprland became unresponsive and Jorge had to
hard power off. `--max-jobs 2 --cores 6` still pushed load to ~42.

**How to apply:** for any build Claude starts on lewis that may compile
locally, check `nix build --dry-run` first; if scipy or other big drvs are
listed, run with `--max-jobs 1 --cores 4`, or wait a day for the cache.
Warn Jorge before he runs `./update.sh` right after a nixpkgs bump.
