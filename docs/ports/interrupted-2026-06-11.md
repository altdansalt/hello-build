# Interrupted runs — capacity wind-down, 2026-06-11 ~02:00

Three in-flight runs were terminated mid-session when the owner called
the night on agent capacity (codex at 25% of weekly). No commits had
landed in any of the three workspaces; the scratch work is lost but the
task definitions are preserved, so each is a single-command relaunch:

```sh
cd /home/exedev/fleet/<name> && codex exec --dangerously-bypass-approvals-and-sandbox \
  "Read PORT_TASK.md in the current directory and carry it out completely."
```

| Workspace | Type | What it was probing |
|---|---|---|
| /home/exedev/fleet/tmux | expedition-lite | the terminfo/host-data limit (pinned ncurses tic → hermetic TERMINFO); regress/ suite both sides |
| /home/exedev/fleet/neovim | expedition | legacy_cmake's offline bundled-deps story (FetchContent redirection) on a real superbuild; oldtest slice |
| /home/exedev/fleet/excalidraw-probe | expedition | the pnpm/React wall (ADR 0017): lockfile translation, offline bundle, and what bundle parity even means |

Note for relaunch: the task files pin hello_build at 6f79e42; bump the
git_override commit to current HEAD first to pick up post-0021 fixes.
