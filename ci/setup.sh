#!/usr/bin/env bash
set -euo pipefail
command -v swift >/dev/null || { echo 'Install Swift >=5.9 using swift-actions/setup-swift before this script.' >&2; exit 1; }
swift --version
