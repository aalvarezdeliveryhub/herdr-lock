# Changelog

## 1.2.0 (2026-10-13)

- Sessions outside Herdr, such as the Claude desktop app, now follow the rule too: `herdr-worker` opens their agents as tabs in the Herdr workspace for the session's folder, and with no such workspace Claude asks you to open the folder in Herdr instead of using background agents. Before, those sessions got no rule and fell back to background Agent-tool workers that ran inside the main session.
- A daily GitHub Actions job tests each new Herdr release and records it when it passes, or opens an issue when the guard needs review. Tests also run on every push.
- Tested with Herdr 0.9.5 (no new commands or options the guard needs to know about since 0.9.3).
- Listed in Herdr's plugin directory: `herdr-plugin.toml` adds a **set up** pane that installs or updates the Claude Code plugin when you open it, and an **agents** pane that lists the agents in the current workspace. Nothing runs at install time.

## 1.1.0 (2026-10-13)

- `herdr-worker list` shows the workers in your workspace; `herdr-worker close <name>` closes one by name.
- `herdr-worker` refuses a name another Herdr agent already uses, before opening a tab.
- A worker that fails to start has its tab closed again.
- A worker stuck at a folder-trust prompt keeps its tab, `herdr-worker` exits with status 3, and its task is saved so it can be sent once the prompt is approved.
- Every new agent opens in its own new tab: the rule now tells Claude to delegate only through `herdr-worker`, never with its built-in Agent tool, background agents or a split pane (1.0's rule sent parallel tickets to background Agent-tool workers, which ran under the main session).
- A worker that needs its own branch gets a git worktree folder inside the project (`git worktree add .worktrees/<name>`, then `herdr-worker -C .worktrees/<name>`).
- The worker rule overrides user, project and repository CLAUDE.md files and other skills, not just repository instructions.
- The `herd` skill no longer carries one person's Codex model and price table.
- The guard lets `-h`/`--help` through.
- The Herdr CLI check warns only about new commands or options, once per Herdr version, and remembers versions it has checked.
- MIT license, with the notice for the parts adapted from vladzima/herd.
- `test/live-checks.sh` runs the end-to-end checks in fresh Claude Code sessions.

## 1.0.0 (2026-10-08)

First release as a Claude Code plugin: `herdr-worker`, the `herdr-guard` PreToolUse hook, the session rule and checks, and the `herd` skill.
