#!/usr/bin/env bash
# Runner for claude-safe.sh tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find bats
BATS_BIN=""
if command -v bats &>/dev/null; then
    BATS_BIN=bats
elif [ -x "/tmp/bats-core/bin/bats" ]; then
    BATS_BIN="/tmp/bats-core/bin/bats"
else
    echo "Installing bats-core to /tmp/bats-core..."
    rm -rf /tmp/bats-core
    git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-core 2>&1
    BATS_BIN="/tmp/bats-core/bin/bats"
fi

exec "$BATS_BIN" --recursive "$SCRIPT_DIR"
