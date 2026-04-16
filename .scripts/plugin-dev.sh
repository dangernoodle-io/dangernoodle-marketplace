#!/usr/bin/env bash
# Plugin dev mode helper: symlink cache dirs to working-tree paths for live editing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${PLUGIN_DEV_CONFIG:-$SCRIPT_DIR/plugin-dev.json}"
CONFIG_BASE="$(cd "$(dirname "$CONFIG_FILE")/.." 2>/dev/null && pwd || echo "")"
DRY_RUN=false
QUIET=false
ALL=false
USE_COLOR=false

# Check if stdout is a tty and not quiet mode
[[ -t 1 && "$QUIET" == "false" ]] && USE_COLOR=true

# Color helpers
color_red() { $USE_COLOR && echo -ne '\033[0;31m' || true; }
color_green() { $USE_COLOR && echo -ne '\033[0;32m' || true; }
color_yellow() { $USE_COLOR && echo -ne '\033[0;33m' || true; }
color_reset() { $USE_COLOR && echo -ne '\033[0m' || true; }

log() {
  [[ "$QUIET" == "false" ]] && echo "$*" >&2 || true
}

die() {
  local msg="$*"
  color_red >&2
  echo "ERROR: $msg" >&2
  color_reset >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
Usage: plugin-dev.sh [OPTIONS] COMMAND [ARGS]

Commands:
  status [name]           List plugin versions (real/symlink/backup)
  link <name> [version]   Symlink version dir to local source
  unlink <name> [version] Remove symlink, restore backup
  relink <name>           Relink to highest version
  relink --all            Relink all plugins
  install-hook            Add SessionStart hook to settings.json
  uninstall-hook          Remove SessionStart hook from settings.json

Options:
  --dry-run               Print actions, make no changes
  --quiet                 Suppress info output (keep errors)
  --all                   For relink command

Examples:
  plugin-dev.sh status ouroboros-mcp
  plugin-dev.sh link ouroboros-mcp
  plugin-dev.sh unlink ouroboros-mcp 1.0.0
  plugin-dev.sh relink --all
  plugin-dev.sh install-hook
EOF
}

expand_path() {
  local p="$1"
  if [[ "$p" == ~* ]]; then
    echo "${p/#\~/$HOME}"
  else
    echo "$p"
  fi
}

resolve_version() {
  local plugin_name="$1"
  local explicit_version="${2:-}"
  local cache_dir="$CACHE_ROOT/$plugin_name"

  if [[ -n "$explicit_version" ]]; then
    echo "$explicit_version"
    return
  fi

  # Find highest semver version dir (skip *.backup)
  local highest=""
  if [[ -d "$cache_dir" ]]; then
    while IFS= read -r dir; do
      dir=$(basename "$dir")
      [[ "$dir" == *.backup ]] && continue
      if [[ -z "$highest" ]]; then
        highest="$dir"
      else
        # Simple semver sort: use sort -V
        if [[ "$(printf '%s\n' "$highest" "$dir" | sort -V | tail -1)" == "$dir" ]]; then
          highest="$dir"
        fi
      fi
    done < <(find "$cache_dir" -mindepth 1 -maxdepth 1 -type d -o -type l)
  fi

  if [[ -z "$highest" ]]; then
    die "no versions found for plugin '$plugin_name' in $cache_dir"
  fi

  echo "$highest"
}

cmd_status() {
  local plugin_filter="${1:-}"

  [[ ! -f "$CONFIG_FILE" ]] && die "config file not found: $CONFIG_FILE"

  local cache_root
  cache_root=$(jq -r '.cacheRoot' "$CONFIG_FILE")
  cache_root=$(expand_path "$cache_root")
  CACHE_ROOT="$cache_root"

  local plugins
  plugins=$(jq -r '.plugins | keys | .[]' "$CONFIG_FILE")

  for plugin_name in $plugins; do
    [[ -n "$plugin_filter" && "$plugin_name" != "$plugin_filter" ]] && continue

    log "Plugin: $plugin_name"

    local local_path
    local_path=$(jq -r ".plugins.\"$plugin_name\"" "$CONFIG_FILE")

    # Resolve relative to repo root
    if [[ "$local_path" != /* ]]; then
      local_path="$CONFIG_BASE/$local_path"
    fi

    if [[ -e "$local_path" ]]; then
      log "  Local path: $local_path (ok)"
    else
      log "  Local path: $local_path (path missing)"
    fi

    local cache_dir="$CACHE_ROOT/$plugin_name"
    if [[ ! -d "$cache_dir" ]]; then
      log "  Cache dir: not found"
      continue
    fi

    while IFS= read -r entry; do
      entry=$(basename "$entry")
      local full_path="$cache_dir/$entry"

      if [[ -L "$full_path" ]]; then
        local target
        target=$(readlink "$full_path")
        log "  $entry -> symlink -> $target"
      elif [[ "$entry" == *.backup ]]; then
        log "  $entry (backup)"
      else
        log "  $entry (real)"
      fi
    done < <(find "$cache_dir" -mindepth 1 -maxdepth 1 | sort)
  done
}

cmd_link() {
  local plugin_name="$1"
  local explicit_version="${2:-}"

  [[ ! -f "$CONFIG_FILE" ]] && die "config file not found: $CONFIG_FILE"

  local cache_root
  cache_root=$(jq -r '.cacheRoot' "$CONFIG_FILE")
  cache_root=$(expand_path "$cache_root")
  CACHE_ROOT="$cache_root"

  local local_path
  local_path=$(jq -r ".plugins.\"$plugin_name\"" "$CONFIG_FILE")
  [[ "$local_path" == "null" ]] && die "plugin '$plugin_name' not in config"

  # Resolve relative to repo root
  if [[ "$local_path" != /* ]]; then
    local_path="$CONFIG_BASE/$local_path"
  fi
  local_path=$(expand_path "$local_path")

  [[ ! -e "$local_path" ]] && die "local path does not exist: $local_path"
  [[ ! -f "$local_path/.claude-plugin/plugin.json" ]] && \
    die "local path missing .claude-plugin/plugin.json: $local_path"

  local version
  version=$(resolve_version "$plugin_name" "$explicit_version")

  local cache_dir="$CACHE_ROOT/$plugin_name"
  local version_dir="$cache_dir/$version"

  [[ ! -d "$cache_dir" ]] && die "cache dir not found: $cache_dir"

  if [[ -L "$version_dir" ]]; then
    die "version dir is already a symlink: $version_dir"
  fi

  [[ ! -e "$version_dir" ]] && die "version dir not found: $version_dir"

  log "Linking $plugin_name version $version to $local_path"

  if $DRY_RUN; then
    log "  [DRY-RUN] mv '$version_dir' '$version_dir.backup'"
    log "  [DRY-RUN] ln -s '$local_path' '$version_dir'"
  else
    mv "$version_dir" "$version_dir.backup"
    ln -s "$local_path" "$version_dir"
  fi
}

cmd_unlink() {
  local plugin_name="$1"
  local explicit_version="${2:-}"

  [[ ! -f "$CONFIG_FILE" ]] && die "config file not found: $CONFIG_FILE"

  local cache_root
  cache_root=$(jq -r '.cacheRoot' "$CONFIG_FILE")
  cache_root=$(expand_path "$cache_root")
  CACHE_ROOT="$cache_root"

  local version
  version=$(resolve_version "$plugin_name" "$explicit_version")

  local cache_dir="$CACHE_ROOT/$plugin_name"
  local version_dir="$cache_dir/$version"

  [[ ! -d "$cache_dir" ]] && die "cache dir not found: $cache_dir"

  if [[ ! -L "$version_dir" ]]; then
    log "version dir is not a symlink: $version_dir (no-op)"
    return
  fi

  log "Unlinking $plugin_name version $version"

  if $DRY_RUN; then
    log "  [DRY-RUN] rm '$version_dir'"
    [[ -d "$version_dir.backup" ]] && log "  [DRY-RUN] mv '$version_dir.backup' '$version_dir'"
  else
    rm "$version_dir"
    if [[ -d "$version_dir.backup" ]]; then
      mv "$version_dir.backup" "$version_dir"
    fi
  fi
}

cmd_relink() {
  [[ ! -f "$CONFIG_FILE" ]] && die "config file not found: $CONFIG_FILE"

  local cache_root
  cache_root=$(jq -r '.cacheRoot' "$CONFIG_FILE")
  cache_root=$(expand_path "$cache_root")
  CACHE_ROOT="$cache_root"

  local plugins
  if $ALL; then
    plugins=$(jq -r '.plugins | keys | .[]' "$CONFIG_FILE")
  else
    # First positional arg is the plugin name (already consumed)
    plugins="$1"
  fi

  for plugin_name in $plugins; do
    local cache_dir="$CACHE_ROOT/$plugin_name"
    [[ ! -d "$cache_dir" ]] && continue

    # Find and remove stale symlinks
    while IFS= read -r entry; do
      entry=$(basename "$entry")
      local full_path="$cache_dir/$entry"
      if [[ -L "$full_path" ]]; then
        # Check if target version still exists as a real dir
        local target
        target=$(readlink "$full_path")
        [[ ! -d "$target" ]] && {
          log "Removing stale symlink: $entry -> $target"
          $DRY_RUN || rm "$full_path"
        }
      fi
    done < <(find "$cache_dir" -mindepth 1 -maxdepth 1)

    # Relink to highest version
    local highest_version
    highest_version=$(resolve_version "$plugin_name" "" || true)
    [[ -z "$highest_version" ]] && continue

    local version_dir="$cache_dir/$highest_version"
    if [[ ! -L "$version_dir" ]]; then
      cmd_link "$plugin_name" "$highest_version"
    fi
  done
}

cmd_install_hook() {
  local settings_file="$HOME/.cloak/profiles/dangernoodle/settings.json"
  local script_path="$SCRIPT_DIR/plugin-dev.sh"
  local hook_cmd="$script_path relink --all --quiet"

  [[ ! -d "$(dirname "$settings_file")" ]] && die "settings dir not found: $(dirname "$settings_file")"

  if [[ ! -f "$settings_file" ]]; then
    log "Creating settings.json: $settings_file"
    if $DRY_RUN; then
      log "  [DRY-RUN] echo '{}' > $settings_file"
    else
      echo '{}' > "$settings_file"
    fi
  fi

  # Check if hook already exists
  if jq -e ".hooks.SessionStart[] | select(.command == \"$hook_cmd\")" "$settings_file" &>/dev/null; then
    log "Hook already installed"
    return
  fi

  log "Installing SessionStart hook: $hook_cmd"

  if $DRY_RUN; then
    log "  [DRY-RUN] add hook to settings.json"
  else
    jq \
      --arg cmd "$hook_cmd" \
      '(.hooks.SessionStart //= []) += [{command: $cmd}]' \
      "$settings_file" > "${settings_file}.tmp" && mv "${settings_file}.tmp" "$settings_file"
  fi
}

cmd_uninstall_hook() {
  local settings_file="$HOME/.cloak/profiles/dangernoodle/settings.json"
  local script_path="$SCRIPT_DIR/plugin-dev.sh"
  local hook_cmd="$script_path relink --all --quiet"

  [[ ! -f "$settings_file" ]] && {
    log "settings.json not found: $settings_file (no-op)"
    return
  }

  if ! jq -e ".hooks.SessionStart[] | select(.command == \"$hook_cmd\")" "$settings_file" &>/dev/null; then
    log "Hook not installed (no-op)"
    return
  fi

  log "Removing SessionStart hook: $hook_cmd"

  if $DRY_RUN; then
    log "  [DRY-RUN] remove hook from settings.json"
  else
    jq \
      --arg cmd "$hook_cmd" \
      '(.hooks.SessionStart //= []) |= map(select(.command != $cmd))' \
      "$settings_file" > "${settings_file}.tmp" && mv "${settings_file}.tmp" "$settings_file"
  fi
}

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --quiet)
      QUIET=true
      shift
      ;;
    --all)
      ALL=true
      shift
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      break
      ;;
  esac
done

[[ $# -eq 0 ]] && { usage; exit 1; }

COMMAND="$1"
shift

case "$COMMAND" in
  status)
    cmd_status "$@"
    ;;
  link)
    [[ $# -lt 1 ]] && die "link requires a plugin name"
    cmd_link "$@"
    ;;
  unlink)
    [[ $# -lt 1 ]] && die "unlink requires a plugin name"
    cmd_unlink "$@"
    ;;
  relink)
    if $ALL; then
      cmd_relink
    else
      [[ $# -lt 1 ]] && die "relink requires a plugin name or --all flag"
      cmd_relink "$1"
    fi
    ;;
  install-hook)
    cmd_install_hook
    ;;
  uninstall-hook)
    cmd_uninstall_hook
    ;;
  *)
    die "unknown command: $COMMAND"
    ;;
esac
