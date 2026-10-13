# herdr-lock

A Claude Code plugin for [Herdr](https://herdr.dev) users who let Claude spawn worker agents. Install it once and every worker opens in its own tab of the **same Herdr workspace and folder as the Claude session that spawned it**. Workers no longer end up in whatever workspace you happen to be looking at, in a new workspace, or in a git worktree somewhere else. It works the same for every project and every `CLAUDE.md`; nothing in your repositories has to change.

## The problem

When a Claude session in Herdr starts helpers, it's easy for them to land in the wrong place:

- [herd](https://github.com/vladzima/herd)'s `herd-spawn` runs `herdr tab create` without naming a workspace, so each worker opens in **whichever workspace has focus**. Switch to another project while workers are spawning and they appear there, working in the wrong folder.
- Agents create extra Herdr workspaces, tabs or worktrees, or point a worker at a folder outside the project.
- Claude delegates work with its built-in Agent tool or a split pane, so helpers run inside or below the main session instead of in a tab you can watch.
- Different `CLAUDE.md` files give different instructions ("use Herdr worktrees", "background Agent workers", "use panes"), so behaviour changes from repo to repo.

## What it does

| Part | What it does |
|---|---|
| `herdr-worker` command | The one way to start a worker. Opens it in a **new tab of the calling session's workspace**, in the session's folder (or a subfolder with `-C`), starts the agent (Claude in auto mode by default) and hands it the task. Also `herdr-worker list` and `herdr-worker close <name>`. |
| Guard (PreToolUse hook) | Blocks Claude from creating Herdr workspaces, tabs or worktrees itself, from putting panes or agents in another workspace, from opening panes outside the project folder, and from running upstream `herd-spawn`/`herd-up`. It sees through `bash -c`, `eval`, backticks and wrappers like `env` or `timeout`, and ignores text such as heredocs and quoted strings. |
| Worker rule (SessionStart hook) | In sessions running inside Herdr, adds a short rule: every new agent opens in its own new tab via `herdr-worker`, never as a built-in subagent or a split pane, and a worker that needs its own branch gets a git worktree folder inside the project. The rule overrides any `CLAUDE.md` or skill instruction about how agents run. Outside Herdr it adds nothing. |
| Self-check (SessionStart hook) | Silently tests the guard each session, warns once per Herdr version if Herdr gained commands the guard hasn't been reviewed against, and flags a user-level copy of upstream herd's skill. |
| `herd` skill | A coordinator skill (`herdr-lock:herd`) for delegating tasks to workers, watching them and collecting their reports. |

## Requirements

- Claude Code with plugin support (tested on 2.1.295)
- Herdr (tested on 0.9.3), with Claude sessions started inside Herdr panes
- `jq` and `python3` (3.9 or later)
- macOS (tested). Linux should work but hasn't been tested yet.

## Install

In Claude Code:

```
/plugin install herdr-lock --marketplace aalvarezdeliveryhub/herdr-lock
```

or from a shell:

```bash
claude plugin marketplace add aalvarezdeliveryhub/herdr-lock
```

```bash
claude plugin install herdr-lock@herdr-lock
```

Then start new Claude sessions; hooks load when a session starts. If you have upstream herd installed, remove its user-level skill (`~/.claude/skills/herd`) so Claude isn't told to use `herd-spawn`; the session check reminds you if it's still there.

## Use

Ask Claude in a Herdr session to split work across workers, for example "spawn three workers to update the API docs, the CLI help and the changelog". Claude will use `herdr-worker`. You can also call it yourself from Claude's shell:

```
herdr-worker [-k kind] [-a "agent args"] [-C subdir] <name> "<task>"
herdr-worker list
herdr-worker close <name>
```

- `-k` picks another agent kind Herdr supports (`codex`, `gemini`, ...); `-a` passes arguments to it and replaces the default `--permission-mode auto` for Claude.
- Names must be unique across all Herdr workspaces; `herdr-worker` refuses one already in use.
- Each worker writes its report to `/tmp/herd/<name>.md`.
- Exit status 3 means the worker started but is waiting at startup, usually Claude Code's "trust this folder?" prompt in a new folder. Approve it in the worker's tab, then send the task with the command `herdr-worker` printed.
- Workers share the session's checkout and branch, so give parallel workers separate files. A worker that needs its own branch (one branch and PR per ticket) gets a git worktree inside the project: `git worktree add .worktrees/<name> -b <branch>`, then `herdr-worker -C .worktrees/<name> <name> "<task>"`. Keep `.worktrees/` in `.gitignore`.
- The rule tells Claude not to delegate with its built-in Agent tool inside Herdr. That's a rule, not a block, so foreground subagents used by other skills keep working.

## What gets blocked

| Claude tries to run | Result |
|---|---|
| `herdr-worker fix-docs "…"` | Allowed: new tab in this workspace, this folder |
| `herdr tab create …`, `herdr workspace create …`, `herdr worktree create/open …` | Blocked |
| `herdr pane split --pane <other workspace's pane>` | Blocked |
| `herdr pane split --cwd /somewhere/else` | Blocked; folders inside the project are fine |
| `herdr pane move … --new-tab` / `--new-workspace` / `--workspace <other>` | Blocked |
| `herd-spawn …`, `herd-up` | Blocked, with a pointer to `herdr-worker` |
| `bash -c "herdr tab create"`, `eval "…"`, `` `…` `` | Checked the same way as the plain command |
| `herdr agent list`, `herdr agent read …`, `herdr tab list`, `-h`/`--help` | Allowed |

## Limits

- It's a guardrail against mistakes, not a security boundary. A program that talks to Herdr's socket directly isn't seen, and Herdr itself has no access control on that socket.
- The guard is a Claude Code hook, so it governs Claude sessions. Codex, Gemini and other agents don't run Claude Code hooks.
- A plugin with commands (`bin/`) can't be distributed through claude.ai organization settings; install it from GitHub in Claude Code.
- Herdr's CLI changes between releases. When the session check reports new commands, the guard may need an update.

## How it was tested

- `test/run-tests.sh`: 133 checks, from guard cases (wrapped commands, heredocs, other workspaces, folders spelled with different capitals, help flags) to `herdr-worker` behaviour against a stand-in for Herdr (one tab per worker, duplicate names, failed and stuck starts, `list`/`close`), the session check, and `claude plugin validate`.
- `test/live-checks.sh`: fresh `claude -p` sessions with the plugin loaded, confirming the rule appears only inside Herdr and beats a conflicting `CLAUDE.md`, a delegated ticket goes to a `herdr-worker` tab rather than the built-in Agent tool, the guard blocks, and `herdr-worker` is on the PATH. If herdr-lock is also installed, disable that copy first to test only your checkout.
- Live in Herdr: three workspaces, each with a Claude session spawning five workers at the same time while focus switched between workspaces every two seconds. All 15 workers opened in their own session's workspace and folder, one tab each, and the other workspaces were untouched. With the same focus switching, upstream `herd-spawn` put its worker in the wrong workspace. In separate runs, agents tried 140 ways to get around the guard, from plain commands to `bash -c`, `eval`, backticks, other workspaces' IDs and `cd /tmp && …`, and none got through.

## Update and uninstall

```bash
claude plugin marketplace update herdr-lock
```

```bash
claude plugin uninstall herdr-lock@herdr-lock
```

## Credits and license

MIT; see [LICENSE](LICENSE). `herdr-worker` and the `herd` skill are adapted from [herd](https://github.com/vladzima/herd) by Vlad Arbatov (MIT). Herdr is by [ogulcancelik](https://github.com/ogulcancelik/herdr).
