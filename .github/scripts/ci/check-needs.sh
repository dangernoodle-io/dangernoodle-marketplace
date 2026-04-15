#!/usr/bin/env bash
set -euo pipefail

: "${NEEDS:?NEEDS env var required}"

echo "$NEEDS" | jq .
if echo "$NEEDS" | jq -e 'to_entries | map(select(.value.result == "failure" or .value.result == "cancelled")) | length > 0' >/dev/null; then
  echo "::error::one or more required jobs failed or were cancelled"
  exit 1
fi
