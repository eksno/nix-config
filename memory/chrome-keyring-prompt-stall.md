---
type: project
title: Chrome blank tabs can be blocked by keyring unlock
created: 2026-10-15
---

On lewis, Chrome blank tabs and a lingering background browser after closing all windows were caused by a locked login keyring with an invisible stuck gcr password prompt. DNS and curl worked. GPU, X11, extension, fresh-profile, proxy and DNS changes did not fix it. A disposable profile with --password-store=basic loaded HTTPS, identifying the keyring path; do not apply that setting to the real profile.

Check org.freedesktop.Secret.Collection Locked on /org/freedesktop/secrets/collection/login via org.freedesktop.secrets. Killing the prompter alone did not clear the daemon's queued request. Restarting gnome-keyring-daemon with --replace --daemonize --components=secrets,pkcs11, then requesting Unlock and Prompt on one persistent D-Bus connection produced the dialog. The installed gcr-3 prompter was launched with GDK_BACKEND=x11, LIBGL_ALWAYS_SOFTWARE=1, GDK_GL=disable and forced NVIDIA variables unset. User entered their password locally. After Locked=false, normal Chrome loaded Example Domain.

A busctl Unlock followed by a separate busctl Prompt fails: prompts belong to the original connection. A persistent Gio connection is required. Never request passwords in chat, delete keyring data, or reset the browser profile for this symptom. See FIXES.md 2026-10-15 for evidence and dead ends. The hardware freeze itself remains unconfirmed (i915 GuC TLB timeouts before shutdown).


Recurrence on the next boot (2026-10-15 18:12) was recovered the same way. Persistent host workaround lives in system/hosts/lewis/keyring-prompt.nix: user-local D-Bus SystemPrompter and PrivatePrompter service files invoke an X11/software wrapper. NixOS activation reinstalls them; user-local files take precedence over system service directories. Both files are already installed in ~/.local/share/dbus-1/services and their store closure is retained by ~/.local/state/nix-config/keyring-prompter. Verified D-Bus autoactivation selected the new wrapper and inspected its process environment. Overriding gnome-keyring's private gcr dependency misses D-Bus activation; globally overriding gcr_3 rebuilds unrelated consumers including Bitwarden, so use the dedicated launcher package. The Intel lewis host's erroneous shared/device/nvidia Lua import was removed; its causality for the prompt stall remains unconfirmed.

User says the preceding shutdown happened automatically. Journal records Power key pressed short at 18:09:58 and logind orderly shutdown; Aquamarine segfaults at 18:10:01 during teardown. Do not label that teardown fault as the cause of the shutdown. Origin of the unexpected power-button event remains unknown.
