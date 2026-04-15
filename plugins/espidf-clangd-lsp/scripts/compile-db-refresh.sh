#!/usr/bin/env bash
set -euo pipefail

FORCE=0
TARGET_DIR=""
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    -*) echo "espidf-clangd-lsp: unknown flag: $arg" >&2; exit 2 ;;
    *)
      if [ -n "$TARGET_DIR" ]; then
        echo "espidf-clangd-lsp: unexpected extra argument: $arg" >&2
        exit 2
      fi
      TARGET_DIR="$arg"
      ;;
  esac
done

if [ -n "$TARGET_DIR" ]; then
  if [ ! -d "$TARGET_DIR" ]; then
    echo "espidf-clangd-lsp: not a directory: $TARGET_DIR" >&2
    exit 1
  fi
  cd "$TARGET_DIR" || exit 1
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT" || exit 0

BUILD_SYSTEM=""
TARGET=""
REFRESH_CMD=""
REFRESH_TOOL=""

if [ -f "$PROJECT_ROOT/platformio.ini" ]; then
  BUILD_SYSTEM="platformio"
  REFRESH_TOOL="pio"
  REFRESH_CMD="pio run -t compiledb"
  TARGET="$(ls -t "$PROJECT_ROOT"/.pio/build/*/compile_commands.json 2>/dev/null | head -1 || true)"
elif [ -f "$PROJECT_ROOT/sdkconfig" ] && [ -f "$PROJECT_ROOT/CMakeLists.txt" ]; then
  BUILD_SYSTEM="esp-idf"
  REFRESH_TOOL="idf.py"
  REFRESH_CMD="idf.py reconfigure"
  TARGET="$PROJECT_ROOT/build/compile_commands.json"
else
  if [ "$FORCE" = "1" ]; then
    echo "espidf-clangd-lsp: not an ESP-IDF or PlatformIO project" >&2
    exit 1
  fi
  exit 0
fi

HASH="$(printf '%s' "$PROJECT_ROOT" | shasum | cut -c1-12)"
COOLDOWN="/tmp/.espidf-clangd-refresh-${HASH}"
LOGFILE="/tmp/.espidf-clangd-refresh-${HASH}.log"

run_refresh_foreground() {
  echo "espidf-clangd-lsp: refreshing compile_commands.json (${BUILD_SYSTEM})"
  if $REFRESH_CMD; then
    local result_target="$TARGET"
    if [ "$BUILD_SYSTEM" = "platformio" ]; then
      result_target="$(ls -t "$PROJECT_ROOT"/.pio/build/*/compile_commands.json 2>/dev/null | head -1 || echo "$TARGET")"
    fi
    echo "espidf-clangd-lsp: refresh complete → ${result_target}"
  else
    local rc=$?
    echo "espidf-clangd-lsp: refresh failed (exit ${rc})" >&2
    exit "$rc"
  fi
}

if [ "$FORCE" = "1" ]; then
  if ! command -v "$REFRESH_TOOL" >/dev/null 2>&1; then
    echo "espidf-clangd-lsp: ${REFRESH_TOOL} not found in PATH" >&2
    exit 1
  fi
  run_refresh_foreground
  exit 0
fi

# Default (Stop-hook) mode: cooldown + staleness + background detach.

if [ -f "$COOLDOWN" ]; then
  now=$(date +%s)
  if [ "$(uname -s)" = "Darwin" ]; then
    mtime=$(stat -f %m "$COOLDOWN" 2>/dev/null || echo 0)
  else
    mtime=$(stat -c %Y "$COOLDOWN" 2>/dev/null || echo 0)
  fi
  if [ $((now - mtime)) -lt 30 ]; then
    exit 0
  fi
fi

STALE=0
if [ -z "$TARGET" ] || [ ! -f "$TARGET" ]; then
  STALE=1
else
  newer=$(find "$PROJECT_ROOT" \
    \( -path '*/build' -o -path '*/.pio' -o -path '*/.git' -o -path '*/node_modules' \) -prune -o \
    -type f \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.cxx' \
            -o -name '*.h' -o -name '*.hpp' -o -name '*.hxx' \
            -o -name 'CMakeLists.txt' -o -name 'platformio.ini' \) \
    -newer "$TARGET" -print 2>/dev/null | head -1)
  if [ -n "$newer" ]; then
    STALE=1
  fi
fi

if [ "$STALE" = "0" ]; then
  exit 0
fi

if ! command -v "$REFRESH_TOOL" >/dev/null 2>&1; then
  echo "[espidf-clangd-lsp] ${REFRESH_TOOL} not found — skipping refresh"
  exit 0
fi

touch "$COOLDOWN"

( nohup bash -c "$REFRESH_CMD" >"$LOGFILE" 2>&1 </dev/null & )
disown 2>/dev/null || true

echo "[espidf-clangd-lsp] refreshing compile_commands.json in background (${BUILD_SYSTEM})"
exit 0
