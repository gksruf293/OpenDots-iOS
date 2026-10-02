#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This build requires macOS. Use the GitHub Actions iOS native build workflow." >&2
  exit 1
fi
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate
xcodebuild -project OpenDots.xcodeproj -scheme OpenDots -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
