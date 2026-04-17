# request

kind: input
source: caller

---

Mosh session restore is broken in tmux. The tmux dotfiles have a session restore setup that works for everything except Mosh connections. Running `~/.config/tmux/scripts/restore-mosh.sh` exits with status 1 (failure).

There have been multiple previous iterations trying to make Mosh restore work — check git blame and git log for the history of attempts and learnings. The final fix must incorporate all past learnings and not repeat previous mistakes.

Key details:
- The script is at `dotfiles/default/tmux/scripts/restore-mosh.sh`
- Tmux session restore works for everything except Mosh
- Previous iterations exist in git history with accumulated learnings
- Host: verse, User: eksno
