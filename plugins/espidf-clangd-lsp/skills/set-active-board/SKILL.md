---
name: set-active-board
description: Switch the active PlatformIO variant for clangd. Refreshes the variant's compile DB and symlinks it at the project root so clangd picks it up.
context: fork
model: haiku
---

1. The argument is the PlatformIO environment name (e.g. `bitaxe-601`, `tdongle-s3`). If no argument is given, ask the user which variant to activate.
2. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-db-refresh.sh --variant "$1" --force`.
3. Report the script output verbatim.
4. Non-zero exit: surface the error and stop. Do not invoke the build tool directly.
