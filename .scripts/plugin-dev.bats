#!/usr/bin/env bats
# Smoke tests for plugin-dev.sh

setup() {
  # Create a temp cache root for testing
  export TEST_CACHE_ROOT="$(mktemp -d)"
  export TEST_REPO_ROOT="$(mktemp -d)"

  # Create a fake config file
  export TEST_CONFIG="$TEST_REPO_ROOT/.scripts/plugin-dev.json"
  mkdir -p "$TEST_REPO_ROOT/.scripts"

  # Create fake plugin with .claude-plugin/plugin.json
  mkdir -p "$TEST_REPO_ROOT/plugins/test-plugin/.claude-plugin"
  echo '{"name": "test-plugin"}' > "$TEST_REPO_ROOT/plugins/test-plugin/.claude-plugin/plugin.json"

  # Create test config pointing to temp cache root
  cat > "$TEST_CONFIG" <<EOF
{
  "cacheRoot": "$TEST_CACHE_ROOT",
  "plugins": {
    "test-plugin": "./plugins/test-plugin"
  }
}
EOF

  # Set env var to use test config
  export PLUGIN_DEV_CONFIG="$TEST_CONFIG"

  # Create initial cache structure with a version dir
  mkdir -p "$TEST_CACHE_ROOT/test-plugin/1.0.0"

  # Script path
  export SCRIPT_PATH="$BATS_TEST_DIRNAME/plugin-dev.sh"
}

teardown() {
  rm -rf "$TEST_CACHE_ROOT" "$TEST_REPO_ROOT"
}

@test "status reports all real dirs" {
  run "$SCRIPT_PATH" status test-plugin

  [ "$status" -eq 0 ]
  [[ "$output" == *"test-plugin"* ]]
  [[ "$output" == *"1.0.0 (real)"* ]]
}

@test "link replaces version dir with symlink and creates backup" {
  run "$SCRIPT_PATH" link test-plugin 1.0.0

  [ "$status" -eq 0 ]

  # Verify symlink was created
  [ -L "$TEST_CACHE_ROOT/test-plugin/1.0.0" ]

  # Verify backup exists
  [ -d "$TEST_CACHE_ROOT/test-plugin/1.0.0.backup" ]

  # Verify symlink points to local path
  local target
  target=$(readlink "$TEST_CACHE_ROOT/test-plugin/1.0.0")
  [[ "$target" == *"plugins/test-plugin"* ]]
}

@test "unlink restores backup and removes symlink" {
  # First link
  "$SCRIPT_PATH" link test-plugin 1.0.0

  # Then unlink
  run "$SCRIPT_PATH" unlink test-plugin 1.0.0

  [ "$status" -eq 0 ]

  # Verify symlink is gone
  [ ! -L "$TEST_CACHE_ROOT/test-plugin/1.0.0" ]

  # Verify backup is restored
  [ -d "$TEST_CACHE_ROOT/test-plugin/1.0.0" ]
  [ ! -d "$TEST_CACHE_ROOT/test-plugin/1.0.0.backup" ]
}

@test "link refuses to operate on already-linked dir" {
  # First link
  "$SCRIPT_PATH" link test-plugin 1.0.0

  # Try to link again
  run "$SCRIPT_PATH" link test-plugin 1.0.0

  [ "$status" -ne 0 ]
  [[ "$output" == *"already a symlink"* ]]
}

@test "status tolerates missing local path and exits 0" {
  # Create config with non-existent path
  local bad_config="$TEST_REPO_ROOT/.scripts/bad-config.json"
  cat > "$bad_config" <<EOF
{
  "cacheRoot": "$TEST_CACHE_ROOT",
  "plugins": {
    "test-plugin": "./plugins/nonexistent"
  }
}
EOF

  PLUGIN_DEV_CONFIG="$bad_config" run "$SCRIPT_PATH" status test-plugin

  [ "$status" -eq 0 ]
  [[ "$output" == *"path missing"* ]]
}
