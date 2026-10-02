{ ... }:
{
  # Keep local Nix builds from starving the desktop. Defaults were
  # max-jobs = 22 (one per thread) x cores = 0 (all threads), at normal
  # priority — a rebuild that misses the binary cache (e.g. phonetic's
  # python3.12 scipy chain) ran 14+ compilers at once, load ~54, CPU at 96 °C,
  # and made Hyprland/browser unusable for the whole rebuild.

  # Builds only get CPU/IO time the desktop isn't using.
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";

  # At most 4 parallel derivations x 6 threads each (~22 threads total)
  # instead of up to 22 x 22. Also bounds peak RAM of parallel C++/Rust builds.
  nix.settings.max-jobs = 4;
  nix.settings.cores = 6;

  # No swap device on this box; a memory spike during a big build used to
  # hard-freeze it (FIXES.md 2026-07-30). Compressed in-RAM swap gives the
  # kernel somewhere to go before the OOM killer / freeze.
  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };
}
