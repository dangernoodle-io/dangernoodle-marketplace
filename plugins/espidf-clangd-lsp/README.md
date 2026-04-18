# espidf-clangd-lsp

Claude Code plugin that wires clangd as an LSP server preconfigured for ESP-IDF (ESP32 xtensa + riscv32) C/C++ development. Zero-config toolchain trust for PlatformIO and native ESP-IDF builds via `--query-driver` globs.

## Prerequisites

- clangd installed (`brew install llvm` on macOS, `apt install clangd` on Linux)
- A compile_commands.json from either `idf.py reconfigure` (native ESP-IDF, produces `build/compile_commands.json`) or PlatformIO (produces `.pio/build/<variant>/compile_commands.json`)

## Install

```bash
/plugin marketplace add dangernoodle-io/dangernoodle-marketplace
/plugin install espidf-clangd-lsp@dangernoodle-marketplace
/reload-plugins
```

## Project setup

Create `.clangd` at your project root with the appropriate compilation database path:

```yaml
CompileFlags:
  CompilationDatabase: build
```

For PlatformIO projects, use:

```yaml
CompileFlags:
  CompilationDatabase: .pio/build/<variant>
```

## How it works

- SessionStart hook detects system clangd and symlinks it into `${CLAUDE_PLUGIN_DATA}/bin/clangd` (symlink preserves clangd's builtin-header resolution)
- `--query-driver` glob authorizes ESP32 toolchains (xtensa, riscv32, arm-none-eabi)
- `--background-index` enables workspace-wide symbol search

## Auto-refresh `compile_commands.json`

A Stop hook checks whether sources or build config are newer than the generated `compile_commands.json` and, if stale, kicks off a background refresh — `idf.py reconfigure` for native ESP-IDF, `pio run -t compiledb` for PlatformIO. 30-second cooldown, silent no-op on non-ESP projects.

Force a refresh manually with the `/refresh-compile-db` skill (runs synchronously, skips cooldown/staleness checks).

## Multi-variant PlatformIO projects

For projects with multiple PlatformIO environments (e.g. `bitaxe-601`, `bitaxe-403`, `tdongle-s3`), the plugin automatically symlinks the active variant's `compile_commands.json` to the project root after each refresh. clangd auto-discovers the root-level file, so no `.clangd` configuration is needed to point at a specific variant.

**Default behavior:** the most-recently-built variant is selected automatically. The Stop-hook background refresh tracks this on every build.

**Switching variants explicitly:** use the `/set-active-board <env>` skill, or call the script directly:

```bash
bash <plugin-root>/scripts/compile-db-refresh.sh --variant tdongle-s3 --force
```

**`.clangd` simplification:** multi-variant projects no longer need a `CompilationDatabase:` line. The root symlink is enough:

```yaml
# .clangd — no CompilationDatabase needed for multi-variant PlatformIO
CompileFlags:
  Add: []
```

If you previously had `CompilationDatabase: .pio/build/<variant>` in `.clangd`, you can remove that line.

**`.gitignore`:** add `compile_commands.json` to your project's `.gitignore` so the generated root symlink is not tracked:

```
compile_commands.json
```

Native ESP-IDF projects are unaffected — their `build/compile_commands.json` is already at a path clangd can walk to from the project root. The `--variant` flag is not supported for ESP-IDF projects.

## License

MIT
