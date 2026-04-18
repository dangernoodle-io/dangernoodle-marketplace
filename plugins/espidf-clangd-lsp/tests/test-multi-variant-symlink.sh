# shellcheck shell=bash
# shellcheck source=tests/lib.sh

# make_multi_variant_sandbox <dir>
# Creates a PlatformIO sandbox with three variants; bitaxe-601 is the most recently touched.
make_multi_variant_sandbox() {
  local dir="$1"
  mkdir -p "$dir/.pio/build/bitaxe-601" "$dir/.pio/build/bitaxe-403" "$dir/.pio/build/tdongle-s3" "$dir/src"
  touch "$dir/platformio.ini" "$dir/src/main.c"
  # Give stable old mtimes to the older variants first.
  touch -t 202001010000 "$dir/.pio/build/bitaxe-403/compile_commands.json"
  touch -t 202001010001 "$dir/.pio/build/tdongle-s3/compile_commands.json"
  # bitaxe-601 touched last → newest.
  touch "$dir/.pio/build/bitaxe-601/compile_commands.json"
}

test_multi_variant_symlink() {
  echo
  echo "multi-variant symlink"
  local SCRIPT="$PWD/scripts/compile-db-refresh.sh"

  # Test MV-1: --force (no variant) → symlink resolves to most-recently-touched variant.
  local sbmv1 stubmv1
  sbmv1=$(mktemp -d); register_cleanup "$sbmv1"
  stubmv1=$(mktemp -d); register_cleanup "$stubmv1"
  make_multi_variant_sandbox "$sbmv1"
  make_stub "$stubmv1" pio 'exit 0'
  local rc_mv1=0
  env PATH="$stubmv1/bin:$PATH" bash "$SCRIPT" --force "$sbmv1" >/dev/null 2>&1 || rc_mv1=$?
  local link_mv1 resolved_mv1
  link_mv1="$sbmv1/compile_commands.json"
  if [ "$rc_mv1" = "0" ] && [ -L "$link_mv1" ]; then
    resolved_mv1="$(readlink "$link_mv1")"
    if [[ "$resolved_mv1" == *"bitaxe-601"* ]]; then
      echo "  ok   — --force no variant → symlink points to most-recent (bitaxe-601)"
      pass=$((pass + 1))
    else
      echo "  FAIL — --force no variant → symlink points to wrong variant (resolved='$resolved_mv1')"
      fail=$((fail + 1))
    fi
  else
    echo "  FAIL — --force no variant → symlink not created (rc=$rc_mv1, link exists=$([ -L "$link_mv1" ] && echo yes || echo no))"
    fail=$((fail + 1))
  fi

  # Test MV-2: --variant tdongle-s3 --force → symlink resolves to tdongle-s3.
  local sbmv2 stubmv2
  sbmv2=$(mktemp -d); register_cleanup "$sbmv2"
  stubmv2=$(mktemp -d); register_cleanup "$stubmv2"
  make_multi_variant_sandbox "$sbmv2"
  make_stub "$stubmv2" pio 'exit 0'
  local rc_mv2=0
  env PATH="$stubmv2/bin:$PATH" bash "$SCRIPT" --variant tdongle-s3 --force "$sbmv2" >/dev/null 2>&1 || rc_mv2=$?
  local link_mv2 resolved_mv2
  link_mv2="$sbmv2/compile_commands.json"
  if [ "$rc_mv2" = "0" ] && [ -L "$link_mv2" ]; then
    resolved_mv2="$(readlink "$link_mv2")"
    if [[ "$resolved_mv2" == *"tdongle-s3"* ]]; then
      echo "  ok   — --variant tdongle-s3 --force → symlink points to tdongle-s3"
      pass=$((pass + 1))
    else
      echo "  FAIL — --variant tdongle-s3 --force → symlink wrong (resolved='$resolved_mv2')"
      fail=$((fail + 1))
    fi
  else
    echo "  FAIL — --variant tdongle-s3 --force → symlink not created (rc=$rc_mv2, link exists=$([ -L "$link_mv2" ] && echo yes || echo no))"
    fail=$((fail + 1))
  fi

  # Test MV-3: --variant nonexistent --force → exits non-zero, no symlink.
  local sbmv3 stubmv3
  sbmv3=$(mktemp -d); register_cleanup "$sbmv3"
  stubmv3=$(mktemp -d); register_cleanup "$stubmv3"
  make_multi_variant_sandbox "$sbmv3"
  make_stub "$stubmv3" pio 'exit 0'
  local rc_mv3=0
  env PATH="$stubmv3/bin:$PATH" bash "$SCRIPT" --variant nonexistent --force "$sbmv3" >/dev/null 2>&1 || rc_mv3=$?
  local link_mv3
  link_mv3="$sbmv3/compile_commands.json"
  if [ "$rc_mv3" != "0" ] && [ ! -L "$link_mv3" ]; then
    echo "  ok   — --variant nonexistent --force → exits non-zero, no symlink"
    pass=$((pass + 1))
  else
    echo "  FAIL — --variant nonexistent --force → expected non-zero exit and no symlink (rc=$rc_mv3, link=$([ -L "$link_mv3" ] && echo exists || echo absent))"
    fail=$((fail + 1))
  fi

  # Test MV-4: --variant for esp-idf --force → exits non-zero with clear error.
  local sbmv4 stubmv4
  sbmv4=$(mktemp -d); register_cleanup "$sbmv4"
  stubmv4=$(mktemp -d); register_cleanup "$stubmv4"
  make_espidf_sandbox "$sbmv4" fresh
  make_stub "$stubmv4" "idf.py" 'exit 0'
  check_stderr_contains \
    "--variant on esp-idf --force → exits 1 with error" 1 "not supported for ESP-IDF" \
    env PATH="$stubmv4/bin:$PATH" bash "$SCRIPT" --variant someenv --force "$sbmv4"

  # Test MV-5: --variant missing argument → exits 2.
  local sbmv5
  sbmv5=$(mktemp -d); register_cleanup "$sbmv5"
  make_platformio_sandbox "$sbmv5" fresh
  check \
    "--variant missing arg → exits 2" 2 \
    bash "$SCRIPT" --variant
}
