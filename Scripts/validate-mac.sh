#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcodebuild -version
swift test
swiftc Core/*.swift Shared/SharedStore.swift Shared/PDFExtractor.swift Scripts/check-pdf.swift -o build/pdf-check
build/pdf-check
device_id="$(xcrun simctl list devices available --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for xs in d["devices"].values() for x in xs if x.get("isAvailable") and "iPhone" in x["name"]))')"
xcodebuild -project WordReview.xcodeproj -scheme WordReview -configuration Debug \
  -destination "platform=iOS Simulator,id=$device_id" -derivedDataPath build/DerivedData \
  -resultBundlePath "build/Tests-$(date +%s).xcresult" CODE_SIGNING_ALLOWED=NO test
xcodebuild -project WordReview.xcodeproj -scheme WordReview -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build/Device CODE_SIGNING_ALLOWED=NO build
echo 'Compilation and tests passed. The device .app is unsigned and cannot be installed as-is.'
