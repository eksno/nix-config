---
type: project
title: Chrome blank tabs can be blocked by keyring unlock
created: 2026-10-15
---

On lewis, Chrome blank tabs and a lingering background browser after closing all windows were caused by a locked login keyring with an invisible stuck gcr password prompt. DNS and curl worked. GPU, X11, extension, fresh-profile, proxy and DNS changes did not fix it. A disposable profile with --password-store=basic loaded HTTPS, identifying the keyring path; do not apply that setting to the real profile.

Check org.freedesktop.Secret.Collection Locked on /org/freedesktop/secrets/collection/login via org.freedesktop.secrets. Killing the prompter alone did not clear the daemon's queued request. Restarting gnome-keyring-daemon with --replace --daemonize --components=secrets,pkcs11, then requesting Unlock and Prompt on one persistent D-Bus connection produced the dialog. The installed gcr-3 prompter was launched with GDK_BACKEND=x11, LIBGL_ALWAYS_SOFTWARE=1, GDK_GL=disable and forced NVIDIA variables unset. User entered their password locally. After Locked=false, normal Chrome loaded Example Domain.

A busctl Unlock followed by a separate busctl Prompt fails: prompts belong to the original connection. A persistent Gio connection is required. Never request passwords in chat, delete keyring data, or reset the browser profile for this symptom. See FIXES.md 2026-10-15 for evidence and dead ends. The hardware freeze itself remains unconfirmed (i915 GuC TLB timeouts before shutdown).
