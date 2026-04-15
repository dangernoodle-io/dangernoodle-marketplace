#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck source=tests/lib.sh
source tests/lib.sh
# shellcheck source=tests/test-install.sh
source tests/test-install.sh
# shellcheck source=tests/test-compile-db-refresh.sh
source tests/test-compile-db-refresh.sh

trap cleanup_all EXIT

test_install
test_compile_db_refresh
summary
