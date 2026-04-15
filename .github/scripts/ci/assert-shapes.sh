#!/usr/bin/env bash
set -euo pipefail

jq -e '.name | type == "string" and (. | length > 0)' .claude-plugin/marketplace.json >/dev/null
jq -e '.plugins | type == "array" and (length > 0)' .claude-plugin/marketplace.json >/dev/null

for f in plugins/*/.claude-plugin/plugin.json; do
  jq -e '.name | type == "string" and (. | length > 0)' "$f" >/dev/null \
    || { echo "::error file=$f::missing/empty .name"; exit 1; }
  jq -e '.version | type == "string" and (. | length > 0)' "$f" >/dev/null \
    || { echo "::error file=$f::missing/empty .version"; exit 1; }
done

for f in plugins/*/hooks/hooks.json; do
  [ -f "$f" ] || continue
  jq -e '.hooks | type == "object"' "$f" >/dev/null \
    || { echo "::error file=$f::missing .hooks object"; exit 1; }
done
