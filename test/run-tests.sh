#!/usr/bin/env bash
# Tests for herdr-guard, herdr-worker, herdr-lock-check and install-herdr-lock.sh.
# Everything runs against a throwaway HOME; the real herdr binary is used read-only
# (help output) and a logging stand-in replaces it where herdr-worker would change layout.
set -uo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
pass=0
fail=0
ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1"; }

# --- herdr-guard -------------------------------------------------------------
main="$work/project"
mkdir -p "$main/site-a" "$work/elsewhere"
main=$(cd "$main" && pwd -P)
guard() { # expected-exit workspace shell-cwd command
  local json got
  json=$(jq -nc --arg c "$4" --arg d "$3" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}')
  if [ -n "$2" ]; then
    got=$(HERDR_WORKSPACE_ID=$2 CLAUDE_PROJECT_DIR=$main "$repo/scripts/herdr-guard" <<<"$json" >/dev/null 2>&1; echo $?)
  else
    got=$(env -u HERDR_WORKSPACE_ID CLAUDE_PROJECT_DIR=$main "$repo/scripts/herdr-guard" <<<"$json" >/dev/null 2>&1; echo $?)
  fi
  [ "$got" = "$1" ] && ok || bad "guard expected $1 got $got (ws=$2 cwd=$3): $4"
}
# blocked
guard 2 w1 "$main" 'herdr tab create --cwd /tmp --label x'
guard 2 w1 "$main" 'herdr workspace create'
guard 2 w1 "$main" 'herdr --session foo tab create'
guard 2 w1 "$main" 'cd /tmp && herdr worktree create --branch feat'
guard 2 w1 "$main" 'herdr worktree open x'
guard 2 w1 "$main" 'json=$(herdr tab create --no-focus)'
guard 2 w1 "$main" $'echo hi\nherdr tab create'
guard 2 w1 "$main" 'herdr pane split w2:p3 --direction right'
guard 2 w1 "$main" 'herdr pane split --pane w2:p3'
guard 2 w1 "$main" 'herdr pane split --current --cwd /tmp --no-focus'
guard 2 w1 "$main" 'herdr pane split --current --cwd=/tmp'
guard 2 w1 "$main" 'herdr pane split --current --cwd ..'
guard 2 w1 "$main" "herdr pane split --current --cwd $work/elsewhere"
guard 2 w1 "$work/elsewhere" 'herdr pane split --current --cwd "$PWD"'
guard 2 w1 "$main" 'herdr agent start x --kind claude --pane w2:p1'
guard 2 w1 "$main" 'herdr pane move w1:p2 --workspace w3'
guard 2 w1 "$main" 'herdr pane move w1:p2 --tab w3:t1'
guard 2 w1 "$main" 'herdr pane move w1:p2 --target-pane w2:p9'
guard 2 w1 "$main" 'herdr pane move w1:p2 --new-tab'
guard 2 w1 "$main" 'herdr pane move w1:p2 --new-workspace'
guard 2 "" "$main" 'herdr pane split --current'
guard 2 "" "$main" 'herdr agent start x --kind claude --pane w1:p1'
guard 2 w1 "$work/elsewhere" 'herdr-worker fix-a "do it"'
guard 2 w1 "$main" 'cd /tmp && herdr-worker fix-a "do it"'
guard 2 w1 "$main" 'cd .. && herdr pane split --current --cwd "$PWD"'
# real Herdr IDs are opaque (e.g. wH, wH:p2), not only w<number>
guard 2 wH "$main" 'herdr pane split wX:p3 --direction right'
guard 2 wH "$main" 'herdr pane split --pane wX:p3'
guard 2 wH "$main" 'herdr agent start x --kind claude --pane wX:p1'
guard 2 wH "$main" 'herdr pane move wH:p2 --tab wX:t1'
guard 2 wH "$main" 'herdr pane move wH:p2 --workspace wX'
guard 0 wH "$main" 'herdr pane split wH:p4 --direction down --no-focus'
guard 0 wH "$main" 'herdr pane move wH:p2 --tab wH:t2'
# allowed
guard 0 w1 "$main" 'herdr pane split --current --direction right --cwd "$PWD" --no-focus'
guard 0 w1 "$main" "herdr pane split --current --cwd $main"
guard 0 w1 "$main" 'herdr pane split --current --cwd site-a'
guard 0 w1 "$main" 'herdr pane split --current --cwd "$PWD/site-a"'
guard 0 w1 "$main/site-a" 'herdr pane split --current --cwd .'
guard 0 w1 "$main" 'herdr pane split w1:p4 --direction down --no-focus'
guard 0 w1 "$main" 'herdr agent start x --kind claude --pane w1:p5'
guard 0 w1 "$main" 'herdr pane move w1:p2 --tab w1:t1'
guard 0 w1 "$main" 'herdr pane close w2:p3'
guard 0 w1 "$main" 'herdr tab list --workspace w2'
guard 0 w1 "$main" 'herdr agent read x --lines 50'
guard 0 w1 "$main" 'echo "herdr tab create"'
guard 0 w1 "$main" 'ls -la'
guard 0 "" "$main" 'herdr status'
guard 0 w1 "$main" 'herdr-worker fix-a "do it"'
guard 0 w1 "$main/site-a" 'herdr-worker fix-a "do it"'
guard 0 w1 "$main" 'cd site-a && herdr-worker fix-a "do it"'
guard 0 w1 "$main" $'git commit -m "Add lock\n\nherdr-worker opens panes;\nherdr tab create is blocked"'
guard 0 w1 "$main" $'cd "$PWD/site-a" && git commit -q -m "x\nherdr-worker y"'
guard 2 w1 "$main" $'git status\nherdr tab create'
guard 2 w1 "$main" $'cd "/tmp" &&\nherdr-worker fix-a "do it"'
# help output never acts
guard 0 "" "$main" 'herdr agent start -h'
guard 0 w1 "$main" 'herdr tab create --help'
guard 0 w1 "$main" 'herdr workspace create -h'
guard 2 w1 "$main" 'herdr tab create --label -h-x'
# heredoc bodies are text, except command substitutions in an unquoted heredoc
guard 0 w1 "$main" $'cat > notes.md <<\'EOF\'\n- blocks `herd-spawn` and `herdr tab create`\nherdr workspace create\nEOF'
guard 0 w1 "$main" $'cat > notes.md <<EOF\nplain herdr tab create text\nEOF'
guard 0 w1 "$main" $'cat <<-"END"\n\therd-spawn x y\n\tEND\necho done'
guard 2 w1 "$main" $'cat <<EOF\nresult: $(herdr tab create --no-focus)\nEOF'
guard 2 w1 "$main" $'cat <<EOF\nresult: `herdr workspace create`\nEOF'
guard 2 w1 "$main" $'cat > f <<\'EOF\'\ntext\nEOF\nherdr tab create'
guard 0 w1 "$main" $'x=$(cat <<<"herdr tab create")'
# upstream herd's spawners are never allowed; herdr-worker is the only way to open a worker
guard 2 w1 "$main" 'herd-spawn fix-a "do it"'
guard 2 w1 "$main" '~/.local/bin/herd-spawn -k codex fix-a "do it"'
guard 2 w1 "$main" 'herd-up'
guard 2 w1 "$main" 'bash -c "herd-spawn fix-a task"'
guard 0 w1 "$main" 'echo "herd-spawn is upstream"'
# commands wrapped in a shell -c string, eval, or backticks
guard 2 w1 "$main" 'bash -c "herdr tab create --no-focus"'
guard 2 w1 "$main" 'sh -c "herdr workspace create"'
guard 2 w1 "$main" 'zsh -lc "herdr worktree create --branch x"'
guard 2 w1 "$main" '/bin/bash -ec "cd /tmp; herdr-worker a task"'
guard 2 w1 "$main" 'eval "herdr tab create"'
guard 2 w1 "$main" 'eval herdr tab create'
guard 2 w1 "$main" "bash -c 'eval \"herdr tab create\"'"
guard 2 w1 "$main" 'x=`herdr tab create`'
guard 2 wH "$main" 'bash -c "herdr pane split wX:p1"'
guard 0 w1 "$main" 'bash -c "echo herdr tab create is blocked"'
guard 0 w1 "$main" 'bash -c "herdr pane split --current --cwd \"$PWD\""'
guard 0 w1 "$main" 'eval "$(ssh-agent -s)"'
# only the word in command position counts, after assignments and wrappers
guard 0 w1 "$main" 'echo herdr tab create'
guard 0 w1 "$main" 'grep -rn herdr tab create notes.md'
guard 2 w1 "$main" 'FOO=1 herdr tab create'
guard 2 w1 "$main" 'env FOO=1 herdr tab create'
guard 2 w1 "$main" 'timeout 5 herdr workspace create'
guard 2 w1 "$main" 'nohup nice -n 10 herdr tab create'
guard 2 w1 "$main" 'command herdr tab create'
guard 2 w1 "$main" 'nohup bash -c "herdr tab create"'
guard 2 w1 "$main" '/Users/x/.local/bin/herdr tab create'
guard 0 w1 "$main" 'FOO=1 herdr-worker a task && cd /tmp'
guard 2 w1 "$work/elsewhere" 'env herdr-worker a task'

# same folder spelled with different case (macOS volumes are case-insensitive by default)
mkdir -p "$work/CaseProj/site"
if [ -d "$work/caseproj" ]; then
  case_guard() { # expected-exit shell-cwd command
    local got
    got=$(jq -nc --arg c "$3" --arg d "$2" '{tool_input:{command:$c},cwd:$d}' \
      | HERDR_WORKSPACE_ID=w1 CLAUDE_PROJECT_DIR="$work/CaseProj" "$repo/scripts/herdr-guard" >/dev/null 2>&1; echo $?)
    [ "$got" = "$1" ] && ok || bad "case-insensitive guard expected $1 got $got (cwd=$2): $3"
  }
  case_guard 0 "$work/caseproj" "herdr pane split --current --cwd $work/caseproj/site"
  case_guard 0 "$work/caseproj" 'herdr pane split --current --cwd "$PWD"'
  case_guard 0 "$work/caseproj/site" 'herdr-worker a task'
  case_guard 2 "$work/caseproj" "herdr pane split --current --cwd $work/elsewhere"
  case_guard 2 "$work/caseproj" 'cd .. && herdr-worker a task'
fi

# --- herdr-worker (fake herdr that models tabs, panes and agents) --------------
stub="$work/stub"
mkdir -p "$stub"
cp "$repo/test/fake-herdr.py" "$stub/herdr"
chmod +x "$stub/herdr"
export FAKE_HERDR_LOG="$work/herdr.log" FAKE_HERDR_STATE="$work/herdr-state.json"
: >"$FAKE_HERDR_LOG"
rm -f "$FAKE_HERDR_STATE"
worker() { (cd "$1" && shift && HERDR_PANE_ID=wT:p1 HERDR_TAB_ID=wT:t1 HERDR_WORKSPACE_ID=wT PATH="$stub:$PATH" "$repo/bin/herdr-worker" "$@"); }
spawn() { worker "$@" >/dev/null 2>&1; }
ntabs() { python3 -I -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["tabs"]))' "$FAKE_HERDR_STATE"; }

(cd "$main" && env -u HERDR_PANE_ID -u HERDR_WORKSPACE_ID PATH="$stub:$PATH" "$repo/bin/herdr-worker" a task >/dev/null 2>&1)
[ $? = 1 ] && ok || bad "herdr-worker outside Herdr should exit 1"
spawn "$main" a "$main" task; [ $? = 2 ] && ok || bad "herdr-worker old <cwd> syntax should exit 2"
spawn "$main" -C "$work/elsewhere" a task; [ $? = 2 ] && ok || bad "herdr-worker -C outside should exit 2"
spawn "$main" -C .. a task; [ $? = 2 ] && ok || bad "herdr-worker -C .. should exit 2"
[ ! -s "$FAKE_HERDR_LOG" ] && ok || bad "refused spawns must not call herdr"

spawn "$main" w1 "task 1" && ok || bad "first spawn failed"
grep -qx "herdr tab create --workspace wT --cwd $main --label w1 --no-focus" "$FAKE_HERDR_LOG" \
  && ok || bad "a worker opens in its own new tab in the caller's workspace and folder"
grep -q "herdr agent start w1 --kind claude --pane wT:p[0-9]* -- --permission-mode auto$" "$FAKE_HERDR_LOG" \
  && ok || bad "claude workers start in auto mode by default"
spawn "$main" -C site-a -k codex -a "-m x" w2 "task 2" && ok || bad "second spawn failed"
grep -qx "herdr tab create --workspace wT --cwd $main/site-a --label w2 --no-focus" "$FAKE_HERDR_LOG" \
  && ok || bad "-C opens the worker's tab in the subfolder"
grep -q "herdr agent start w2 --kind codex --pane wT:p[0-9]* -- -m x$" "$FAKE_HERDR_LOG" && ok || bad "-a replaces the default agent args"
for i in 3 4 5 6 7 8 9 10; do spawn "$main" "w$i" "task $i" || bad "spawn w$i failed"; done
[ "$(grep -c '^herdr tab create' "$FAKE_HERDR_LOG")" = 10 ] && [ "$(ntabs)" = 11 ] && ok || bad "10 workers should open 10 tabs"
! grep '^herdr tab create' "$FAKE_HERDR_LOG" | grep -v -- "--workspace wT " >/dev/null && ok || bad "every worker tab must be in the caller's workspace"
! grep -q -E "^herdr (pane split|workspace create|worktree)" "$FAKE_HERDR_LOG" && ok || bad "herdr-worker must not split panes or create workspaces/worktrees"

# a name already in use anywhere is refused before any tab opens
before=$(ntabs)
out=$(worker "$main" w1 "again" 2>&1); rc=$?
[ $rc = 2 ] && grep -q "already in use" <<<"$out" && [ "$(ntabs)" = "$before" ] && ok || bad "a duplicate name must be refused without opening a tab (rc=$rc): $out"

# a failed start closes the tab it opened
before=$(ntabs)
out=$(FAKE_AGENT_START=fail worker "$main" w11 "task" 2>&1); rc=$?
[ $rc = 1 ] && [ "$(ntabs)" = "$before" ] && grep -q "did not start" <<<"$out" && ok || bad "a failed start must close its tab (rc=$rc): $out"

# a worker stuck at the folder-trust prompt keeps its tab, and the task is saved for re-sending
before=$(ntabs)
out=$(FAKE_AGENT_START=not_ready FAKE_PANE_TEXT="Do you trust the files in this folder?" worker "$main" w12 "the stuck task" 2>&1); rc=$?
[ $rc = 3 ] && [ "$(ntabs)" = "$((before + 1))" ] && grep -q "trust" <<<"$out" && grep -q "herdr agent prompt w12" <<<"$out" \
  && grep -q "the stuck task" /tmp/herd/w12.task && ok || bad "a trust-prompt start should keep the tab and explain how to resend (rc=$rc): $out"
out=$(FAKE_AGENT_START=not_ready FAKE_PANE_TEXT="Something else" worker "$main" w13 "task" 2>&1); rc=$?
[ $rc = 3 ] && grep -q "blocked during startup" <<<"$out" && ok || bad "other startup blocks should be reported (rc=$rc): $out"
rm -f /tmp/herd/w12.task /tmp/herd/w13.task

# list and close
out=$(worker "$main" list 2>&1)
[ "$(grep -c '^w' <<<"$out")" = 12 ] && ! grep -q "wT:p1" <<<"$out" && ok || bad "list should show this space's 12 workers and not the caller: $out"
python3 -I - "$FAKE_HERDR_STATE" <<'PY'
import json, sys
p = sys.argv[1]; s = json.load(open(p))
s["tabs"]["wX:t9"] = ["wX:p9"]
s["agents"]["other"] = {"name": "other", "pane_id": "wX:p9", "tab_id": "wX:t9", "workspace_id": "wX", "cwd": "/x", "agent_status": "idle"}
s["agents"]["caller"] = {"name": "caller", "pane_id": "wT:p1", "tab_id": "wT:t1", "workspace_id": "wT", "cwd": "/x", "agent_status": "idle"}
json.dump(s, open(p, "w"))
PY
! worker "$main" list 2>&1 | grep -q -E "^(other|caller) " && ok || bad "list should leave out other spaces' workers and the caller"
before=$(ntabs)
worker "$main" close w3 >/dev/null 2>&1 && [ "$(ntabs)" = "$((before - 1))" ] && grep -q "^herdr tab close wT:t" "$FAKE_HERDR_LOG" \
  && ok || bad "close <name> should close that worker's tab"
out=$(worker "$main" close other 2>&1); rc=$?
[ $rc = 2 ] && grep -q "another workspace" <<<"$out" && ok || bad "close must refuse a worker in another workspace (rc=$rc): $out"
out=$(worker "$main" close caller 2>&1); rc=$?
[ $rc = 2 ] && grep -q "your own tab" <<<"$out" && ok || bad "close must refuse the caller's own tab (rc=$rc): $out"
out=$(worker "$main" close nobody 2>&1); rc=$?
[ $rc = 2 ] && grep -q "no worker named" <<<"$out" && ok || bad "close of an unknown name should fail clearly (rc=$rc): $out"
unset FAKE_HERDR_LOG FAKE_HERDR_STATE

# --- plugin: manifest, SessionStart script (throwaway HOME, real herdr help) --
claude plugin validate "$repo" 2>&1 | grep -q "Validation passed" && ok || bad "claude plugin validate should pass"
fake="$work/home"
mkdir -p "$fake"
out=$(HOME="$fake" HERDR_ENV=1 "$repo/scripts/herdr-lock-session" 2>&1); rc=$?
[ $rc = 0 ] && grep -q '^## Herdr workers (herdr-lock plugin)' <<<"$out" && ! grep -q "needs attention" <<<"$out" \
  && ok || bad "inside Herdr the session hook prints the rule and no warning (rc=$rc)"
out=$(env -u HERDR_ENV HOME="$fake" "$repo/scripts/herdr-lock-session" 2>&1); rc=$?
[ $rc = 0 ] && [ -z "$out" ] && ok || bad "outside Herdr the session hook prints nothing when all is well (rc=$rc): $out"
out=$(env -u HERDR_ENV HOME="$fake" PATH="/usr/bin:/bin" "$repo/scripts/herdr-lock-session" 2>&1); rc=$?
[ $rc = 0 ] && [ -z "$out" ] && ok || bad "without herdr installed the session hook is silent (rc=$rc): $out"
CLAUDE_PROJECT_DIR="$main" HERDR_WORKSPACE_ID=wH HOME="$fake" "$repo/scripts/herdr-lock-session" >/dev/null 2>&1 \
  && ok || bad "the self-check must not depend on the session's CLAUDE_PROJECT_DIR or workspace"

mkdir -p "$fake/.claude/skills/herd"
printf 'herd-spawn [-k kind] <name> <cwd> "<task>"\n' >"$fake/.claude/skills/herd/SKILL.md"
out=$(HOME="$fake" "$repo/scripts/herdr-lock-session" 2>&1); rc=$?
[ $rc = 1 ] && grep -q "upstream herd's skill" <<<"$out" && ok || bad "an upstream herd skill should be flagged"
HOME="$fake" "$repo/scripts/herdr-lock-session" --hook >/dev/null 2>&1 && ok || bad "--hook mode must exit 0"
rm -f "$fake/.claude/skills/herd/SKILL.md"

broken="$work/broken-plugin/scripts"
mkdir -p "$broken"
cp "$repo/scripts/herdr-lock-session" "$repo/scripts/herdr-workers-rule.md" "$broken/"
printf '#!/bin/sh\nexit 0\n' >"$broken/herdr-guard"; chmod +x "$broken/herdr-guard"
out=$(HOME="$fake" "$broken/herdr-lock-session" 2>&1)
grep -q "herdr-guard returned 0 (expected 2)" <<<"$out" && ok || bad "a guard that lets everything through should be flagged"

# Herdr CLI drift: warn only about additions, once per Herdr version, and remember clean versions
real_herdr=$(command -v herdr)
drift="$work/drift"
mkdir -p "$drift"
cat >"$drift/herdr" <<EOF
#!/usr/bin/env bash
if [ "\$*" = "--version" ]; then echo "herdr \${FAKE_HERDR_VERSION:-9.9.9}"; exit 0; fi
if [ "\$*" = "tab --help" ] && [ -n "\${FAKE_ADD_TAB_CMD:-}" ]; then
  "$real_herdr" tab --help | sed "/^Commands:/a\\\\
  \$FAKE_ADD_TAB_CMD  Added by a newer Herdr
"
  exit 0
fi
if [ "\$*" = "tab --help" ] && [ -n "\${FAKE_DROP_TAB_CMD:-}" ]; then
  "$real_herdr" tab --help | grep -v "^  \$FAKE_DROP_TAB_CMD "
  exit 0
fi
exec "$real_herdr" "\$@"
EOF
chmod +x "$drift/herdr"
data="$work/plugin-data"
session() { env -u HERDR_ENV HOME="$fake" CLAUDE_PLUGIN_DATA="$data" PATH="$drift:$PATH" "$repo/scripts/herdr-lock-session" "$@" 2>&1; }
out=$(FAKE_HERDR_VERSION=1.0.0 FAKE_ADD_TAB_CMD=spawn session); rc=$?
[ $rc = 1 ] && grep -q "tab: spawn" <<<"$out" && ok || bad "a new tab subcommand should be reported (rc=$rc): $out"
out=$(FAKE_HERDR_VERSION=1.0.0 FAKE_ADD_TAB_CMD=spawn session); rc=$?
[ $rc = 0 ] && [ -z "$out" ] && ok || bad "the same Herdr version should be reported only once (rc=$rc): $out"
out=$(FAKE_HERDR_VERSION=1.0.1 FAKE_DROP_TAB_CMD=rename session); rc=$?
[ $rc = 0 ] && [ -z "$out" ] && ok || bad "removed commands alone should not warn (rc=$rc): $out"
out=$(FAKE_HERDR_VERSION=1.0.2 FAKE_ADD_TAB_CMD=teleport session); rc=$?
[ $rc = 1 ] && grep -q "tab: teleport" <<<"$out" && ok || bad "a new Herdr version with additions should warn again (rc=$rc): $out"

# --- Herdr companion (herdr-plugin.toml and its panes) -------------------------
toml_version=$(sed -n 's/^version = "\(.*\)"$/\1/p' "$repo/herdr-plugin.toml")
[ "$toml_version" = "$(jq -r .version "$repo/.claude-plugin/plugin.json")" ] && ok || bad "herdr-plugin.toml and plugin.json versions differ"
bash -n "$repo/herdr/setup.sh" && bash -n "$repo/herdr/workers.sh" && ok || bad "herdr pane scripts have syntax errors"

fake_claude="$work/fake-claude"
mkdir -p "$fake_claude"
cat >"$fake_claude/claude" <<EOF
#!/usr/bin/env bash
echo "claude \$*" >>"$work/claude.log"
case "\$*" in
  "plugin list") [ -f "$work/claude-installed" ] && printf '  ❯ herdr-lock@herdr-lock\n    Version: 1.2.0\n    Status: ✔ enabled\n' ;;
  "plugin install herdr-lock@herdr-lock --scope user") touch "$work/claude-installed" ;;
esac
exit 0
EOF
chmod +x "$fake_claude/claude"
pane() { (cd "$repo" && PATH="$fake_claude:$PATH" SHELL=/bin/sh bash "herdr/$1" <<<"x" 2>&1); }
: >"$work/claude.log"; rm -f "$work/claude-installed"
pane setup.sh >/dev/null
grep -qx "claude plugin marketplace add aalvarezdeliveryhub/herdr-lock" "$work/claude.log" \
  && grep -qx "claude plugin install herdr-lock@herdr-lock --scope user" "$work/claude.log" \
  && ok || bad "first setup should add the marketplace and install the plugin: $(cat "$work/claude.log")"
: >"$work/claude.log"
pane setup.sh >/dev/null
grep -qx "claude plugin update herdr-lock@herdr-lock" "$work/claude.log" && ! grep -q "plugin install" "$work/claude.log" \
  && ok || bad "setup when installed should update, not install: $(cat "$work/claude.log")"

export FAKE_HERDR_LOG="$work/herdr2.log" FAKE_HERDR_STATE="$work/herdr2-state.json"
python3 -I - "$FAKE_HERDR_STATE" <<'PY'
import json, sys
a = lambda n, ws: {"name": n, "pane_id": f"{ws}:p2", "tab_id": f"{ws}:t2", "workspace_id": ws, "cwd": "/x", "agent_status": "idle"}
json.dump({"next": 5, "tabs": {}, "agents": {"mine": a("mine", "wT"), "theirs": a("theirs", "wX")}}, open(sys.argv[1], "w"))
PY
out=$(cd "$repo" && HERDR_BIN_PATH="$stub/herdr" HERDR_WORKSPACE_ID=wT SHELL=/bin/sh bash herdr/workers.sh <<<"x" 2>&1)
grep -q "mine" <<<"$out" && ! grep -q "theirs" <<<"$out" && ok || bad "workers pane should list only this workspace's agents: $out"
unset FAKE_HERDR_LOG FAKE_HERDR_STATE

echo "pass=$pass fail=$fail"
[ $fail = 0 ]
