#!/usr/bin/env bash
set -euo pipefail
desc=$(jq -r '.tool_input.description // ""')
if ! { echo "$desc" | grep -qi 'why:' \
    && echo "$desc" | grep -qi 'what:' \
    && echo "$desc" | grep -qi 'impact:'; }; then
  echo "Blocked: this command has no why/what/impact explanation. Re-issue it with all three lines in the command description before running." 1>&2
  exit 2
fi
exit 0
