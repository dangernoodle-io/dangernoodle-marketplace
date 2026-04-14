# esp-idf-clangd

Claude Code plugin that wires clangd as an LSP server preconfigured for ESP-IDF (ESP32 xtensa + riscv32) C/C++ development. Zero-config toolchain trust for PlatformIO and native ESP-IDF builds via `--query-driver` globs.

## Prerequisites

- clangd installed (`brew install llvm` on macOS, `apt install clangd` on Linux)
- A compile_commands.json from either `idf.py reconfigure` (native ESP-IDF, produces `build/compile_commands.json`) or PlatformIO (produces `.pio/build/<variant>/compile_commands.json`)

## Install

```bash
/plugin marketplace add dangernoodle-io/dangernoodle-marketplace
/plugin install esp-idf-clangd@dangernoodle-marketplace
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

## License

MIT
