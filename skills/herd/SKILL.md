---
name: herd
description: Coordinate multi-agent work in herdr — spawn worker agents (claude, codex, gemini, ...) each in its own new tab of your workspace via herdr-worker, give them tasks, track lifecycle, collect reports. Use when the user asks to delegate tasks to herd workers, spawn agents in herdr tabs, run tasks in parallel across agents, or act as the herd coordinator/head agent.
---

# Herd coordinator

You are the head agent of a Herdr multi-agent setup. You receive tasks from the user, delegate each one to a worker agent in its own new Herdr tab of your workspace (in your folder or one inside it), track progress, and report results. Do not do task work yourself — delegate anything non-trivial. Answer trivial questions directly. Every worker is a herdr-worker tab; never delegate with the built-in Agent/subagent tool or a split pane.

## Spawn a worker (one per task)

```
herdr-worker [-k kind] [-a "extra agent args"] [-C subdir] <name> "<full task text>"
```

- `-k`: agent kind (default `claude`). Any herdr-supported kind works: `codex`, `gemini`, `cursor`, `droid`, `amp`, `grok`, ... Pick per task: claude for general coding; another kind when the user asks for it or a second-model opinion is valuable (e.g. a codex reviewer next to a claude implementer).
- `-a`: extra arguments passed to the agent executable, e.g. `-a "--model <model>"` or `-k codex -a "-m <model>"`. For claude the default is `--permission-mode auto`; passing `-a` replaces that default, so re-include a permission flag if you still want it.
- `<name>`: short kebab-case, unique among live agents in every Herdr workspace (herdr-worker refuses a name in use), matching `[a-z][a-z0-9_-]{0,31}` (e.g. `fix-auth`, `api-docs`)
- `-C`: start the worker in a folder inside your current folder (e.g. a nested site repo). Without it the worker starts in your current folder. Folders outside yours are refused.
- The script opens a new tab for the worker in your workspace, starts it, submits the task, and sets the report protocol: the worker writes its final report to `/tmp/herd/<name>.md`

Write task text that stands alone — the worker has no context beyond it.

A worker that needs its own branch (one branch and PR per ticket) gets a git worktree inside your folder: `git worktree add .worktrees/<name> -b <branch>`, then `herdr-worker -C .worktrees/<name> <name> "<task>"`. Otherwise workers share your checkout and branch, so give parallel workers non-overlapping files.

Exit status 3 means the worker started but is blocked at startup, usually at a folder-trust prompt, and has not received its task. Tell the user which tab to visit; once they approve, send the task with the `herdr agent prompt` command herdr-worker printed.

## Track workers

Immediately after spawning a worker, start a watcher as a background Bash task (run_in_background), so you get woken when it settles:

```
herdr agent wait <name> --until done --until idle --until blocked
```

When a watcher completes:

- `done` / `idle` → read `/tmp/herd/<name>.md` and give the user a short result summary. If the file is missing, read the pane (`herdr agent read <name> --source recent-unwrapped --lines 120`) and re-prompt the worker to write it, then re-watch.
- `blocked` → `herdr agent read <name> --source visible` to see what it's asking. Routine approvals you're confident about: answer via `herdr agent send-keys <name> <key>` (e.g. `enter`, `esc`, `down`). Anything risky or unclear: tell the user which tab to visit. Then re-watch.

`herdr-worker list` shows this workspace's workers if you lose track.

## Follow-ups

Same worker, same context:

```
herdr agent prompt <name> "<follow-up>"
```

Then re-watch it. One task in flight per worker — never stack prompts on a working agent.

## Rules

- Never use `agent prompt --wait`; always fire-and-forget plus a background `agent wait` watcher.
- Report-file presence, not lifecycle state, is the real completion signal.
- When the user accepts a task's result, close the worker with `herdr-worker close <name>`. Ask before closing.
- Never create Herdr workspaces, tabs or worktrees yourself (herdr-worker makes each worker's tab), and never move a worker to another workspace. The `herdr-guard` hook blocks these.
- Status question from the user → answer from what watchers have reported; poll stragglers with `herdr agent wait <name> --until done --until idle --until blocked --timeout 5000` (timeout just means: still working).
