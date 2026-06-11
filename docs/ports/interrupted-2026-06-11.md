# Interrupted runs — capacity wind-down, 2026-06-11 ~02:00

Three in-flight runs were terminated mid-session when the owner called
the night on agent capacity (codex at 25% of weekly) — the incident
behind ADR 0022. No commits had landed in any of the three workspaces,
and the workspaces themselves were later deleted for disk space, so
only these task descriptions survive. Relaunch each by scaffolding
fresh on the current loop (`loop/new-port.sh <name>` with a goal
restating the probe below, then `loop/run-port.sh <name>`):

| Name | Type | What it was probing |
|---|---|---|
| tmux | expedition-lite | the terminfo/host-data limit (pinned ncurses tic → hermetic TERMINFO); regress/ suite both sides |
| neovim | expedition | legacy_cmake's offline bundled-deps story (FetchContent redirection) on a real superbuild; oldtest slice |
| excalidraw-probe | expedition | the pnpm/React wall (ADR 0017): lockfile translation, offline bundle, and what bundle parity even means |
