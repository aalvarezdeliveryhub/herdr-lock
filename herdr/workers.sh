#!/usr/bin/env bash
# herdr-lock workers pane: list the agents in the current Herdr workspace, then
# wait for a key.
set -u
PATH="$PATH:$("${SHELL:-/bin/bash}" -lic 'printf %s "$PATH"' 2>/dev/null)"
herdr=${HERDR_BIN_PATH:-herdr}

if [ -z "${HERDR_WORKSPACE_ID:-}" ]; then
  echo "No current workspace."
else
  echo "Agents in this workspace ($HERDR_WORKSPACE_ID):"
  echo
  "$herdr" agent list | jq -r --arg ws "$HERDR_WORKSPACE_ID" '
    [.result.agents[] | select(.workspace_id == $ws)]
    | if length == 0 then "  none" else .[] | "  \(.name)\t\(.tab_id)\t\(.agent_status // "-")\t\(.cwd // "-")" end'
fi
echo
echo "Close one from Claude with: herdr-worker close <name>. Press any key to close."
read -r -n 1 -s
