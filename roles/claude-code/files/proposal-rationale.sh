#!/usr/bin/env bash
set -euo pipefail
cat <<'EOF'
[Standing rule — code-change proposals] Before presenting ANY code change, diff,
or implementation proposal, prepend a brief rationale covering all four points:
1. Task (high level): the problem being solved.
2. This suggestion: what the change does, concretely.
3. Relevance: how it connects to the problem.
4. Why best: justification from mature devops / software-engineering practice.
Never present code without this framing.
EOF
