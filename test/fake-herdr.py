#!/usr/bin/env python3
"""Minimal stand-in for the herdr CLI, for testing herdr-worker.

Models tabs, panes and named agents, and logs every invocation to
$FAKE_HERDR_LOG. State lives in $FAKE_HERDR_STATE (JSON); when missing it starts
as tab "<ws>:t1" holding the caller pane "<ws>:p1", where <ws> is
$HERDR_WORKSPACE_ID. Errors are JSON on stderr with exit status 1, like herdr.

$FAKE_AGENT_START picks how `agent start` behaves: "ok" (default), "fail", or
"not_ready" (the agent is detected but blocked at startup, e.g. at a trust
prompt). $FAKE_PANE_TEXT is what `pane read` prints (plain text, like herdr).
"""
import json
import os
import sys

state_path = os.environ["FAKE_HERDR_STATE"]
args = sys.argv[1:]
with open(os.environ["FAKE_HERDR_LOG"], "a") as log:
    log.write("herdr " + " ".join(args) + "\n")


def load():
    if os.path.exists(state_path):
        with open(state_path) as f:
            return json.load(f)
    ws = os.environ.get("HERDR_WORKSPACE_ID", "w1")
    return {"next": 2, "tabs": {f"{ws}:t1": [f"{ws}:p1"]}, "agents": {}}


def save(state):
    with open(state_path, "w") as f:
        json.dump(state, f)


def opt(name):
    return args[args.index(name) + 1] if name in args else None


def fail(code, message):
    print(json.dumps({"error": {"code": code, "message": message}}), file=sys.stderr)
    sys.exit(1)


def tab_of(state, pane):
    for tab, panes in state["tabs"].items():
        if pane in panes:
            return tab
    fail("pane_not_found", f"pane {pane} not found")


def new_id(state, ws, kind):
    n = state["next"]
    state["next"] += 1
    return f"{ws}:{kind}{n}"


state = load()
cmd = tuple(args[:2])

if cmd == ("tab", "create"):
    ws = opt("--workspace") or os.environ["HERDR_WORKSPACE_ID"]
    tab, pane = new_id(state, ws, "t"), new_id(state, ws, "p")
    state["tabs"][tab] = [pane]
    state.setdefault("cwd", {})[pane] = opt("--cwd")
    save(state)
    print(json.dumps({"result": {"tab": {"tab_id": tab}, "root_pane": {"pane_id": pane}}}))
elif cmd == ("tab", "close"):
    tab = args[2]
    if tab not in state["tabs"]:
        fail("tab_not_found", f"tab {tab} not found")
    for name in [n for n, a in state["agents"].items() if a["tab_id"] == tab]:
        del state["agents"][name]
    del state["tabs"][tab]
    save(state)
    print(json.dumps({"result": {"type": "ok"}}))
elif cmd == ("agent", "start"):
    name, pane = args[2], opt("--pane")
    if name in state["agents"]:
        fail("agent_name_taken", f"agent name {name} is already in use")
    mode = os.environ.get("FAKE_AGENT_START", "ok")
    if mode == "fail":
        fail("agent_start_failed", "agent did not start")
    tab = tab_of(state, pane)
    state["agents"][name] = {"name": name, "pane_id": pane, "tab_id": tab,
                             "workspace_id": tab.split(":")[0],
                             "cwd": state.get("cwd", {}).get(pane), "agent_status": "idle"}
    save(state)
    if mode == "not_ready":
        fail("agent_not_ready", f"agent {name} is blocked during startup")
    print(json.dumps({"result": {"agent": state["agents"][name]}}))
elif cmd == ("agent", "list"):
    print(json.dumps({"result": {"agents": list(state["agents"].values())}}))
elif cmd == ("agent", "get"):
    if args[2] not in state["agents"]:
        fail("agent_not_found", f"agent target {args[2]} not found")
    print(json.dumps({"result": {"agent": state["agents"][args[2]]}}))
elif cmd == ("pane", "read"):
    print(os.environ.get("FAKE_PANE_TEXT", ""))
else:
    print(json.dumps({"result": {}}))
