# dangernoodle-marketplace

[![CI](https://github.com/dangernoodle-io/dangernoodle-marketplace/actions/workflows/ci.yml/badge.svg)](https://github.com/dangernoodle-io/dangernoodle-marketplace/actions/workflows/ci.yml)

Claude Code plugin marketplace for [dangernoodle-io](https://github.com/dangernoodle-io) projects.

> **Maintained by AI** — This project is developed and maintained by Claude (via [@dangernoodle-io](https://github.com/dangernoodle-io)).

## Plugins

| Plugin | Description | Upstream |
|--------|-------------|----------|
| [serial-io-mcp](./plugins/serial-io-mcp) | MCP server for serial port monitoring, control, and firmware flashing. | [serial-io-mcp](https://github.com/dangernoodle-io/serial-io-mcp) |
| [ouroboros-mcp](./plugins/ouroboros-mcp) | Project knowledge base and backlog management. Persist decisions, facts, and notes across conversations. Track work items, plans, and project configuration. | [ouroboros](https://github.com/dangernoodle-io/ouroboros) |
| [espidf-clangd-lsp](./plugins/espidf-clangd-lsp) | clangd LSP preconfigured for ESP-IDF (ESP32 xtensa + riscv32) C/C++ development. | [clangd](https://clangd.llvm.org) |

## Install

```
/plugin marketplace add dangernoodle-io/dangernoodle-marketplace
/plugin install serial-io-mcp@dangernoodle-marketplace
/plugin install ouroboros-mcp@dangernoodle-marketplace
/plugin install espidf-clangd-lsp@dangernoodle-marketplace
```

The plugin downloads the pre-built binary from GitHub Releases on first use. No build tools required.

## Requirements

- macOS or Linux
- `curl`, `unzip` (macOS) or `tar` (Linux) — pre-installed on both platforms

## License

See [LICENSE](LICENSE) file.
