#!/usr/bin/env bash
# Live checks: start fresh headless Claude Code sessions with this plugin loaded
# (--plugin-dir) and confirm that the rule, the guard and herdr-worker reach them.
# If herdr-lock is also installed, both copies load; disable the installed one
# (claude plugin disable herdr-lock@herdr-lock) to test only this working copy.
# Each check is one short `claude -p` session, so this uses a little of your plan.
# Needs: claude, herdr. Nothing in Herdr is changed: the tab it tries to create
# targets a workspace that does not exist.
set -uo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
pass=0
fail=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "PASS: $1"; else fail=$((fail + 1)); echo "FAIL: $1"; echo "$out" | tail -5 | sed 's/^/  | /'; fi; }
ask() { (cd "$work" && claude --plugin-dir "$repo" -p "$1" --permission-mode auto 2>&1); }

out=$(HERDR_ENV=1 ask "Without running any tools: is there a section titled exactly 'Herdr workers (herdr-lock plugin)' in your context? Reply yes or no only.")
check "inside Herdr, the session gets the worker rule" 'grep -qi "^yes" <<<"$out"'

out=$(HERDR_ENV=0 ask "Without running any tools: is there a section titled exactly 'Herdr workers (herdr-lock plugin)' in your context? Reply yes or no only.")
check "outside Herdr, the session does not get the rule" 'grep -qi "^no" <<<"$out"'

out=$(HERDR_ENV=1 ask "Without running any tools: a CLAUDE.md says to run Herdr workers in git worktrees. Following all your instructions, what exact command would you use to start a Herdr worker? Reply with the command name only.")
check "the rule wins over a CLAUDE.md that says to use worktrees" 'grep -q "herdr-worker" <<<"$out"'

out=$(HERDR_ENV=1 ask "Without running any tools: you need to hand ticket #12 to another agent so it runs in parallel with you, on its own branch. Following all your instructions, which tool or command starts that agent, and where does it run? Answer in one sentence.")
check "inside Herdr, a delegated agent gets its own tab via herdr-worker, not the built-in Agent tool" \
  'grep -q "herdr-worker" <<<"$out" && grep -qi "tab" <<<"$out"'

out=$(ask 'Run this exact Bash command once and quote its result verbatim: herdr tab create --workspace wNOPE --no-focus')
check "the guard blocks herdr tab create" 'grep -q "herdr-guard" <<<"$out"'

out=$(ask 'Run this exact Bash command once and print its output verbatim: command -v herdr-worker')
check "herdr-worker is on the session PATH" 'grep -q "/bin/herdr-worker" <<<"$out"'

echo "pass=$pass fail=$fail"
[ $fail = 0 ]
