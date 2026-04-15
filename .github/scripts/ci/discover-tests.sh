#!/usr/bin/env bash
set -euo pipefail

plugins=$(find plugins -maxdepth 3 -type f -path '*/tests/run.sh' \
  | awk -F/ '{print $2}' \
  | sort -u \
  | jq -R -s -c 'split("\n") | map(select(length > 0))')
echo "plugins=$plugins"
