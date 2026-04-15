---
name: refresh-compile-db
description: Force-refresh compile_commands.json for an ESP-IDF or PlatformIO project. Optional project path/name arg.
context: fork
model: haiku
---

1. Resolve target dir from the argument: absolute path, cwd-relative path, or bare name matched case-insensitive against cwd siblings. No match → ask. No arg → use cwd.
2. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-db-refresh.sh --force <dir>` (omit `<dir>` when using cwd).
3. Report the script output verbatim.
4. Non-zero exit: surface the error and stop. Do not invoke the build tool directly.
