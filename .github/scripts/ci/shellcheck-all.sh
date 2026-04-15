#!/usr/bin/env bash
set -euo pipefail

mapfile -t targets < <(find plugins .github/scripts -type f -name '*.sh' 2>/dev/null)
if [ ${#targets[@]} -eq 0 ]; then
  echo "no shell scripts found"
  exit 0
fi
printf '%s\n' "${targets[@]}"
shellcheck -x -S warning "${targets[@]}"
