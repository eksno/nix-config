---
type: feedback
title: Verify before recommending from memory or training data
created: 2026-05-06
---

Before recommending any specific file, function, flag, command, or
package by name, **verify it exists right now**. Memory and training
data give you "X existed when written," not "X exists now."

## When to verify

- Memory says a file exists → `ls` it
- Memory says a function exists → `grep -r` it
- You're about to suggest a kernel param, sysctl, env var, CLI flag
  → check the actual binary's `--help` or man page
- Training data says a Nix attribute exists → check
  `pkgs.<name>` in `nix repl` or search nixpkgs source

## When NOT to verify (avoid over-checking)

- Pure architectural reasoning ("if you put a non-desktop EDID, wlroots
  will advertise it") doesn't need a re-verification of every
  intermediate step every time — that's what the memory entry exists
  for. Verify the *names* and *paths*, not the *concepts* in well-tested
  documents.
- When the user is asking "tell me about the history" not "do this now."

## Why

Past failures from skipping this:

- Recommended a function that had been renamed in a newer version
- Suggested a config flag that was removed in a Mesa update
- Pointed to a file path that had moved during a refactor

A 5-second `ls` or `grep` prevents recommending something that no longer
exists, which costs the user 30+ seconds of confusion plus erodes trust
in everything else recommended in the same response.

## How to apply concretely

When drafting a recommendation that names a path/symbol, before sending
it: parallelize the verification checks. They take a few hundred ms
and run alongside any other parallel tool calls you're already making.

Don't make the user say "that file doesn't exist" — make sure it does
before saying it does.
