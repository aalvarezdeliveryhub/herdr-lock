#!/usr/bin/env bash
# herdr-lock setup pane: install the herdr-lock Claude Code plugin, or update it
# when it's already installed, then wait for a key.
set -u
# Herdr starts panes with its own environment; take PATH from the user's shell.
PATH="$PATH:$("${SHELL:-/bin/bash}" -lic 'printf %s "$PATH"' 2>/dev/null)"

echo "herdr-lock: setting up the Claude Code plugin"
echo
if ! command -v claude >/dev/null; then
  echo "Claude Code (claude) isn't on PATH. Install Claude Code, then open this pane again."
elif claude plugin list 2>/dev/null | grep -q "herdr-lock@herdr-lock"; then
  claude plugin marketplace update herdr-lock && claude plugin update herdr-lock@herdr-lock
else
  { claude plugin marketplace list 2>/dev/null | grep -q "aalvarezdeliveryhub/herdr-lock" \
      || claude plugin marketplace add aalvarezdeliveryhub/herdr-lock; } \
    && claude plugin install herdr-lock@herdr-lock --scope user
fi
echo
command -v claude >/dev/null && claude plugin list 2>/dev/null | grep -A4 "herdr-lock@herdr-lock" | grep -E "Version|Status"
for tool in jq python3; do
  command -v "$tool" >/dev/null || echo "Missing $tool: herdr-lock needs it."
done
echo
echo "Start new Claude sessions in Herdr so they load it. Press any key to close."
read -r -n 1 -s
