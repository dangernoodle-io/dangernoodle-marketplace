# shellcheck shell=bash
# Shared helpers for espidf-clangd-lsp test files.

pass=0
fail=0
skip=0
CLEANUP_DIRS=()

register_cleanup() {
  CLEANUP_DIRS+=("$1")
}

cleanup_all() {
  local d
  for d in "${CLEANUP_DIRS[@]}"; do
    [ -n "$d" ] && rm -rf "$d"
  done
  rm -f /tmp/.espidf-clangd-refresh-* 2>/dev/null || true
}

check() {
  local desc="$1" expected="$2"
  shift 2
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  if [ "$actual" = "$expected" ]; then
    echo "  ok   — $desc"
    pass=$((pass + 1))
  else
    echo "  FAIL — $desc (expected exit $expected, got $actual)"
    fail=$((fail + 1))
  fi
}

check_stderr_contains() {
  local desc="$1" expected_rc="$2" needle="$3"
  shift 3
  local actual_rc=0 stderr
  stderr=$("$@" 2>&1 >/dev/null) || actual_rc=$?
  if [ "$actual_rc" = "$expected_rc" ] && [[ "$stderr" == *"$needle"* ]]; then
    echo "  ok   — $desc"
    pass=$((pass + 1))
  else
    echo "  FAIL — $desc (rc=$actual_rc expected=$expected_rc, stderr='$stderr')"
    fail=$((fail + 1))
  fi
}

check_stdout_contains() {
  local desc="$1" expected_rc="$2" needle="$3"
  shift 3
  local actual_rc=0 stdout
  stdout=$("$@" 2>/dev/null) || actual_rc=$?
  if [ "$actual_rc" = "$expected_rc" ] && [[ "$stdout" == *"$needle"* ]]; then
    echo "  ok   — $desc"
    pass=$((pass + 1))
  else
    echo "  FAIL — $desc (rc=$actual_rc expected=$expected_rc, stdout='$stdout')"
    fail=$((fail + 1))
  fi
}

check_silent() {
  local desc="$1" expected_rc="$2"
  shift 2
  local actual_rc=0 combined
  combined=$("$@" 2>&1) || actual_rc=$?
  if [ "$actual_rc" = "$expected_rc" ] && [ -z "$combined" ]; then
    echo "  ok   — $desc"
    pass=$((pass + 1))
  else
    echo "  FAIL — $desc (rc=$actual_rc expected=$expected_rc, output='$combined')"
    fail=$((fail + 1))
  fi
}

mark_skip() {
  local desc="$1" reason="$2"
  echo "  skip — $desc ($reason)"
  skip=$((skip + 1))
}

# make_stub <dir> <name> <body-after-shebang>
make_stub() {
  local dir="$1" name="$2" body="$3"
  mkdir -p "$dir/bin"
  {
    echo '#!/usr/bin/env bash'
    echo "$body"
  } >"$dir/bin/$name"
  chmod +x "$dir/bin/$name"
}

# make_platformio_sandbox <dir> [fresh|stale]
make_platformio_sandbox() {
  local dir="$1" staleness="${2:-fresh}"
  mkdir -p "$dir/.pio/build/testenv" "$dir/src"
  touch "$dir/platformio.ini" "$dir/src/main.c"
  if [ "$staleness" = "stale" ]; then
    touch "$dir/.pio/build/testenv/compile_commands.json"
    touch -t 202001010000 "$dir/.pio/build/testenv/compile_commands.json"
  else
    # touch target last so it is newest
    touch "$dir/.pio/build/testenv/compile_commands.json"
  fi
}

# make_espidf_sandbox <dir> [fresh|stale]
make_espidf_sandbox() {
  local dir="$1" staleness="${2:-fresh}"
  mkdir -p "$dir/build" "$dir/main"
  touch "$dir/CMakeLists.txt" "$dir/sdkconfig" "$dir/main/main.c"
  if [ "$staleness" = "stale" ]; then
    touch "$dir/build/compile_commands.json"
    touch -t 202001010000 "$dir/build/compile_commands.json"
  else
    touch "$dir/build/compile_commands.json"
  fi
}

summary() {
  echo
  if [ "$skip" -gt 0 ]; then
    echo "results: $pass passed, $fail failed, $skip skipped"
  else
    echo "results: $pass passed, $fail failed"
  fi
  [ "$fail" = "0" ]
}
