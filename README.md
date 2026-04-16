# dangernoodle-marketplace

[![CI](https://github.com/dangernoodle-io/dangernoodle-marketplace/actions/workflows/ci.yml/badge.svg)](https://github.com/dangernoodle-io/dangernoodle-marketplace/actions/workflows/ci.yml)

Claude Code plugin marketplace for [dangernoodle-io](https://github.com/dangernoodle-io) projects.

> **Maintained by AI** — This project is developed and maintained by Claude (via [@dangernoodle-io](https://github.com/dangernoodle-io)).

## Plugins

| Plugin | Description | Upstream |
|--------|-------------|----------|
| [breadboard-mcp](https://github.com/dangernoodle-io/breadboard/tree/main/plugin) | Embedded development MCP server — serial monitoring, ESP-IDF flashing, NVS management, and crash decode. | [breadboard](https://github.com/dangernoodle-io/breadboard) |
| [ouroboros-mcp](https://github.com/dangernoodle-io/ouroboros/tree/main/plugin) | Project knowledge base and backlog management. Persist decisions, facts, and notes across conversations. Track work items, plans, and project configuration. | [ouroboros](https://github.com/dangernoodle-io/ouroboros) |
| [espidf-clangd-lsp](./plugins/espidf-clangd-lsp) | clangd LSP preconfigured for ESP-IDF (ESP32 xtensa + riscv32) C/C++ development. | [clangd](https://clangd.llvm.org) |

## Install

```
/plugin marketplace add dangernoodle-io/dangernoodle-marketplace
/plugin install breadboard-mcp@dangernoodle-marketplace
/plugin install ouroboros-mcp@dangernoodle-marketplace
/plugin install espidf-clangd-lsp@dangernoodle-marketplace
```

The plugin downloads the pre-built binary from GitHub Releases on first use. No build tools required.

## Requirements

- macOS or Linux
- `curl`, `unzip` (macOS) or `tar` (Linux) — pre-installed on both platforms

## License

See [LICENSE](LICENSE) file.
