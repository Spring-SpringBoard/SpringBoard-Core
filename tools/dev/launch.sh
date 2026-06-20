#!/usr/bin/env bash
# Build-and-run wrapper for an interactive SBC editor session.
#
# All launch logic (engine dir from .env, isolated write dir, games symlink,
# persistent fontcache, dev config, native-plugin env) lives once in
# tools/smoke/run_sbc.py — this just invokes its manual launcher so the dev run
# and the test harness can't drift apart.
set -euo pipefail
exec python3 "$(dirname "${BASH_SOURCE[0]}")/../smoke/run_sbc.py" --manual
