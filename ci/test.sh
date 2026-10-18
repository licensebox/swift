#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ci/env.sh
swift build -Xcc -I"$LICENSEBOX_INCLUDE_DIR" -Xlinker -L"$LICENSEBOX_LIB_DIR"
swift test -Xcc -I"$LICENSEBOX_INCLUDE_DIR" -Xlinker -L"$LICENSEBOX_LIB_DIR"
cp .build/debug/licensebox-adapter build/adapter
swift package dump-package > build/package.json
tar -czf build/licensebox-swift-0.1.0.tar.gz Package.swift LICENSE Sources Tests
