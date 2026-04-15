#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

SCRIPT="$PWD/scripts/compile-db-refresh.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

pass=0
fail=0

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

echo "compile-db-refresh.sh"
check              "unknown flag exits 2"              2 bash "$SCRIPT" --bogus
check              "nonexistent path exits 1"          1 bash "$SCRIPT" --force /nope/does/not/exist
check_stderr_contains \
                   "--force non-ESP exits 1 w/ msg"    1 "not an ESP-IDF or PlatformIO project" \
                                                         bash "$SCRIPT" --force "$SANDBOX"
check              "extra positional exits 2"          2 bash "$SCRIPT" --force "$SANDBOX" extra
check              "default non-ESP exits 0 silently"  0 bash -c "cd '$SANDBOX' && bash '$SCRIPT'"

echo
echo "results: $pass passed, $fail failed"
[ "$fail" = "0" ]
