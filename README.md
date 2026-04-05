# dangernoodle-marketplace

Claude Code plugin marketplace for [dangernoodle-io](https://github.com/dangernoodle-io) projects.

## Plugins

| Plugin | Description |
|--------|-------------|
| [serial-io-mcp](https://github.com/dangernoodle-io/serial-io-mcp) | MCP server for serial port monitoring, control, and firmware flashing |

## Install

```
/plugin marketplace add dangernoodle-io/dangernoodle-marketplace
/plugin install serial-io-mcp@dangernoodle-marketplace
```

The plugin downloads the pre-built binary from GitHub Releases on first use. No build tools required.

## Requirements

- macOS or Linux
- `curl`, `unzip` (macOS) or `tar` (Linux) — pre-installed on both platforms

## License

See [LICENSE](LICENSE) file.
