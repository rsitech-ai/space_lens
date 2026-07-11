#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

EXPECTED_XCODEGEN_VERSION="${SPACE_LENS_XCODEGEN_VERSION:-2.45.4}"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen is required. Install it with: brew install xcodegen" >&2
    exit 1
fi

ACTUAL_XCODEGEN_VERSION="$(xcodegen --version | awk '{print $2}')"
if [[ "$ACTUAL_XCODEGEN_VERSION" != "$EXPECTED_XCODEGEN_VERSION" ]]; then
    echo "SpaceLens release generation requires XcodeGen $EXPECTED_XCODEGEN_VERSION; found $ACTUAL_XCODEGEN_VERSION." >&2
    exit 1
fi

xcodegen generate
