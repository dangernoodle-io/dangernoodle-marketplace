#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="${CLAUDE_PLUGIN_DATA}/bin"
LINK="${BIN_DIR}/clangd"
VERSION_FILE="${CLAUDE_PLUGIN_DATA}/.clangd-source"

# Well-known clangd locations, in preference order.
CANDIDATES=(
  "/opt/homebrew/opt/llvm/bin/clangd"
  "/usr/local/opt/llvm/bin/clangd"
  "/usr/bin/clangd"
  "/usr/local/bin/clangd"
)

FOUND=""
for c in "${CANDIDATES[@]}"; do
  if [ -x "$c" ]; then FOUND="$c"; break; fi
done

if [ -z "$FOUND" ] && command -v clangd >/dev/null 2>&1; then
  FOUND="$(command -v clangd)"
fi

if [ -z "$FOUND" ]; then
  echo "esp-idf-clangd: clangd not found." >&2
  echo "  Install it via your package manager:" >&2
  echo "    macOS:  brew install llvm" >&2
  echo "    Linux:  apt install clangd     (or your distro equivalent)" >&2
  exit 1
fi

if [ -L "$LINK" ] && [ "$(readlink "$LINK")" = "$FOUND" ] && [ -x "$LINK" ]; then
  exit 0
fi

mkdir -p "$BIN_DIR"
ln -sf "$FOUND" "$LINK"
printf '%s' "$FOUND" > "$VERSION_FILE"
echo "esp-idf-clangd: linked ${LINK} -> ${FOUND}"
