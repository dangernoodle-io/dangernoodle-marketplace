#!/usr/bin/env bash
set -euo pipefail

fail=0
while IFS= read -r f; do
  if ! jq -e type "$f" >/dev/null; then
    echo "::error file=$f::not valid JSON"
    fail=1
  fi
done < <(find . -type d \( -name node_modules -o -name .git \) -prune -o -type f -name '*.json' -print)
exit $fail
