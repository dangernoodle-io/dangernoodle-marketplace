# shellcheck shell=bash
# shellcheck source=tests/lib.sh

test_compile_db_refresh() {
  echo
  echo "compile-db-refresh.sh"
  local SCRIPT="$PWD/scripts/compile-db-refresh.sh"

  # Existing arg-parsing suite uses a single non-ESP sandbox.
  local sb_args
  sb_args=$(mktemp -d); register_cleanup "$sb_args"
  check              "unknown flag exits 2"              2 bash "$SCRIPT" --bogus
  check              "nonexistent path exits 1"          1 bash "$SCRIPT" --force /nope/does/not/exist
  check_stderr_contains \
                     "--force non-ESP exits 1 w/ msg"    1 "not an ESP-IDF or PlatformIO project" \
                                                           bash "$SCRIPT" --force "$sb_args"
  check              "extra positional exits 2"          2 bash "$SCRIPT" --force "$sb_args" extra
  check              "default non-ESP exits 0 silently"  0 bash -c "cd '$sb_args' && bash '$SCRIPT'"

  # Test 6: PlatformIO stale → background refresh message + cooldown file
  local sb6 stub6
  sb6=$(mktemp -d); register_cleanup "$sb6"
  stub6=$(mktemp -d); register_cleanup "$stub6"
  make_platformio_sandbox "$sb6" stale
  make_stub "$stub6" pio 'sleep 0.1; exit 0'
  check_stdout_contains \
    "platformio stale → background refresh" 0 "in background (platformio)" \
    env PATH="$stub6/bin:$PATH" bash -c "cd '$sb6' && bash '$SCRIPT'"

  # Cooldown file should exist after test 6 (same hash basis = sb6 path)
  local hash6
  hash6=$(printf '%s' "$sb6" | shasum | cut -c1-12)
  if [ -f "/tmp/.espidf-clangd-refresh-${hash6}" ]; then
    echo "  ok   — cooldown file created after background refresh"
    pass=$((pass + 1))
  else
    echo "  FAIL — cooldown file created after background refresh (not found)"
    fail=$((fail + 1))
  fi

  # Test 7: PlatformIO fresh → silent no-op
  local sb7 stub7
  sb7=$(mktemp -d); register_cleanup "$sb7"
  stub7=$(mktemp -d); register_cleanup "$stub7"
  make_platformio_sandbox "$sb7" fresh
  make_stub "$stub7" pio 'exit 0'
  check_silent \
    "platformio fresh → silent no-op" 0 \
    env PATH="$stub7/bin:$PATH" bash -c "cd '$sb7' && bash '$SCRIPT'"

  # Test 8: cooldown blocks rapid re-run
  local sb8 stub8
  sb8=$(mktemp -d); register_cleanup "$sb8"
  stub8=$(mktemp -d); register_cleanup "$stub8"
  make_platformio_sandbox "$sb8" stale
  make_stub "$stub8" pio 'sleep 0.1; exit 0'
  env PATH="$stub8/bin:$PATH" bash -c "cd '$sb8' && bash '$SCRIPT'" >/dev/null 2>&1
  check_silent \
    "cooldown blocks second run" 0 \
    env PATH="$stub8/bin:$PATH" bash -c "cd '$sb8' && bash '$SCRIPT'"

  # Test 9: ESP-IDF stale → background refresh
  local sb9 stub9
  sb9=$(mktemp -d); register_cleanup "$sb9"
  stub9=$(mktemp -d); register_cleanup "$stub9"
  make_espidf_sandbox "$sb9" stale
  make_stub "$stub9" idf.py 'exit 0'
  check_stdout_contains \
    "esp-idf stale → background refresh" 0 "in background (esp-idf)" \
    env PATH="$stub9/bin:$PATH" bash -c "cd '$sb9' && bash '$SCRIPT'"

  # Test 10: --force with missing build tool exits 1
  local sb10
  sb10=$(mktemp -d); register_cleanup "$sb10"
  make_platformio_sandbox "$sb10" stale
  check_stderr_contains \
    "--force missing pio exits 1" 1 "pio not found in PATH" \
    env PATH="/usr/bin:/bin" bash "$SCRIPT" --force "$sb10"

  # Test 11: --force synchronous success
  local sb11 stub11
  sb11=$(mktemp -d); register_cleanup "$sb11"
  stub11=$(mktemp -d); register_cleanup "$stub11"
  make_platformio_sandbox "$sb11" stale
  make_stub "$stub11" pio 'echo "test build output"; exit 0'
  local out11 rc11=0
  out11=$(env PATH="$stub11/bin:$PATH" bash "$SCRIPT" --force "$sb11" 2>&1) || rc11=$?
  if [ "$rc11" = "0" ] \
     && [[ "$out11" == *"refreshing compile_commands.json (platformio)"* ]] \
     && [[ "$out11" == *"refresh complete"* ]]; then
    echo "  ok   — --force synchronous success"
    pass=$((pass + 1))
  else
    echo "  FAIL — --force synchronous success (rc=$rc11, out='$out11')"
    fail=$((fail + 1))
  fi
}
