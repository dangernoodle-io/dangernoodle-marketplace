# shellcheck shell=bash
# shellcheck source=tests/lib.sh

test_install() {
  echo
  echo "install.sh"
  local SCRIPT="$PWD/scripts/install.sh"

  # Probe whether the script's absolute CANDIDATES exist on the host.
  # These are checked unconditionally regardless of PATH, so the
  # "missing clangd" branch can only be exercised if none of them exist.
  local c candidates_present=0
  for c in \
    /opt/homebrew/opt/llvm/bin/clangd \
    /usr/local/opt/llvm/bin/clangd \
    /usr/bin/clangd \
    /usr/local/bin/clangd; do
    [ -x "$c" ] && candidates_present=1
  done

  # Test 1: missing clangd → exit 1 with help hint
  if [ "$candidates_present" = "1" ]; then
    mark_skip "missing clangd exits 1 w/ help" "absolute clangd candidate present on host"
  else
    local data1 empty1 bash_path
    data1=$(mktemp -d); register_cleanup "$data1"
    empty1=$(mktemp -d); register_cleanup "$empty1"
    bash_path=$(command -v bash)
    check_stderr_contains \
      "missing clangd exits 1 w/ help" 1 "brew install llvm" \
      env -i HOME="$HOME" CLAUDE_PLUGIN_DATA="$data1" PATH="$empty1" \
        "$bash_path" "$SCRIPT"
  fi

  # Test 2: clangd available → symlink created under $CLAUDE_PLUGIN_DATA/bin
  local data2 stub2
  data2=$(mktemp -d); register_cleanup "$data2"
  stub2=$(mktemp -d); register_cleanup "$stub2"
  make_stub "$stub2" clangd 'exit 0'
  env CLAUDE_PLUGIN_DATA="$data2" PATH="$stub2/bin:$PATH" bash "$SCRIPT" >/dev/null 2>&1
  local rc2=$?
  if [ "$rc2" = "0" ] && [ -L "$data2/bin/clangd" ] && [ -x "$data2/bin/clangd" ]; then
    echo "  ok   — clangd found creates symlink"
    pass=$((pass + 1))
  else
    echo "  FAIL — clangd found creates symlink (rc=$rc2, link=$(readlink "$data2/bin/clangd" 2>/dev/null))"
    fail=$((fail + 1))
  fi

  # Test 3: re-run is idempotent
  env CLAUDE_PLUGIN_DATA="$data2" PATH="$stub2/bin:$PATH" bash "$SCRIPT" >/dev/null 2>&1
  local rc3=$?
  if [ "$rc3" = "0" ] && [ -L "$data2/bin/clangd" ] && [ -x "$data2/bin/clangd" ]; then
    echo "  ok   — re-run is idempotent"
    pass=$((pass + 1))
  else
    echo "  FAIL — re-run is idempotent (rc=$rc3)"
    fail=$((fail + 1))
  fi
}
