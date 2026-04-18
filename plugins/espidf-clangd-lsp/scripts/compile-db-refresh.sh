#!/usr/bin/env bash
set -euo pipefail

FORCE=0
TARGET_DIR=""
VARIANT=""
_EXPECT_VARIANT=0
for arg in "$@"; do
  if [ "$_EXPECT_VARIANT" = "1" ]; then
    VARIANT="$arg"
    _EXPECT_VARIANT=0
    continue
  fi
  case "$arg" in
    --force) FORCE=1 ;;
    --variant) _EXPECT_VARIANT=1 ;;
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

if [ "$_EXPECT_VARIANT" = "1" ]; then
  echo "espidf-clangd-lsp: --variant requires an argument" >&2
  exit 2
fi

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

# --variant is only meaningful for PlatformIO; reject for esp-idf in --force mode.
if [ -n "$VARIANT" ] && [ "$BUILD_SYSTEM" = "esp-idf" ]; then
  if [ "$FORCE" = "1" ]; then
    echo "espidf-clangd-lsp: --variant is not supported for ESP-IDF projects" >&2
    exit 1
  fi
  VARIANT=""
fi

HASH="$(printf '%s' "$PROJECT_ROOT" | shasum | cut -c1-12)"
COOLDOWN="/tmp/.espidf-clangd-refresh-${HASH}"
LOGFILE="/tmp/.espidf-clangd-refresh-${HASH}.log"

# pick_variant: resolves the active variant path after a successful PlatformIO refresh.
# Prints the full path to the chosen compile_commands.json.
pick_variant() {
  if [ -n "$VARIANT" ]; then
    echo "$PROJECT_ROOT/.pio/build/${VARIANT}/compile_commands.json"
  else
    ls -t "$PROJECT_ROOT"/.pio/build/*/compile_commands.json 2>/dev/null | head -1 || true
  fi
}

# symlink_variant: creates/updates the project-root symlink after a successful refresh.
# $1 = log prefix ("espidf-clangd-lsp:" or "[espidf-clangd-lsp]")
symlink_variant() {
  local prefix="$1"
  local chosen
  chosen="$(pick_variant)"
  if [ -z "$chosen" ]; then
    return
  fi
  local env_name
  env_name="$(basename "$(dirname "$chosen")")"
  # Make the symlink target relative so it survives directory moves.
  local rel_target=".pio/build/${env_name}/compile_commands.json"
  ln -sfn "$rel_target" "$PROJECT_ROOT/compile_commands.json"
  echo "${prefix} active variant → ${env_name}"
}

run_refresh_foreground() {
  echo "espidf-clangd-lsp: refreshing compile_commands.json (${BUILD_SYSTEM})"
  if $REFRESH_CMD; then
    if [ "$BUILD_SYSTEM" = "platformio" ]; then
      # Validate explicit variant before symlinking.
      if [ -n "$VARIANT" ]; then
        local variant_db="$PROJECT_ROOT/.pio/build/${VARIANT}/compile_commands.json"
        if [ ! -f "$variant_db" ]; then
          echo "espidf-clangd-lsp: variant ${VARIANT} has no compile DB at .pio/build/${VARIANT}/compile_commands.json" >&2
          exit 1
        fi
      fi
      local chosen
      chosen="$(pick_variant)"
      echo "espidf-clangd-lsp: refresh complete → ${chosen}"
      symlink_variant "espidf-clangd-lsp:"
    else
      echo "espidf-clangd-lsp: refresh complete → ${TARGET}"
    fi
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

# Capture variables needed inside the subshell before forking.
_BG_BUILD_SYSTEM="$BUILD_SYSTEM"
_BG_PROJECT_ROOT="$PROJECT_ROOT"
_BG_VARIANT="$VARIANT"

(
  nohup bash -c "$REFRESH_CMD" >"$LOGFILE" 2>&1 </dev/null
  _rc=$?
  if [ "$_rc" = "0" ] && [ "$_BG_BUILD_SYSTEM" = "platformio" ]; then
    if [ -n "$_BG_VARIANT" ]; then
      _chosen="$_BG_PROJECT_ROOT/.pio/build/${_BG_VARIANT}/compile_commands.json"
      if [ ! -f "$_chosen" ]; then
        echo "[espidf-clangd-lsp] variant ${_BG_VARIANT} has no compile DB — skipping symlink" >>"$LOGFILE"
        exit 0
      fi
      _env_name="$_BG_VARIANT"
    else
      _chosen="$(ls -t "$_BG_PROJECT_ROOT"/.pio/build/*/compile_commands.json 2>/dev/null | head -1 || true)"
      [ -z "$_chosen" ] && exit 0
      _env_name="$(basename "$(dirname "$_chosen")")"
    fi
    ln -sfn ".pio/build/${_env_name}/compile_commands.json" "$_BG_PROJECT_ROOT/compile_commands.json"
    echo "[espidf-clangd-lsp] active variant → ${_env_name}" >>"$LOGFILE"
  fi
) &
disown 2>/dev/null || true

echo "[espidf-clangd-lsp] refreshing compile_commands.json in background (${BUILD_SYSTEM})"
exit 0
