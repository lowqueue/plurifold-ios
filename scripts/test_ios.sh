#!/bin/bash
set -euo pipefail

# Use an installed iPhone simulator instead of hard-coding a model/runtime that
# may disappear when Codemagic updates its Xcode image.
mkdir -p build/test-results
xcrun simctl list devices available --json > build/test-results/devices.json
PLURIFOLD_SIMULATOR_ID=$(python3 - <<'PY'
import json
from pathlib import Path
devices = json.loads(Path('build/test-results/devices.json').read_text())['devices']
for runtime, entries in sorted(devices.items(), reverse=True):
    if '.iOS-' not in runtime:
        continue
    for device in entries:
        if device.get('isAvailable') and device.get('name', '').startswith('iPhone'):
            print(device['udid'])
            raise SystemExit(0)
raise SystemExit('No available iPhone simulator was found on the build machine.')
PY
)
xcodebuild test \
  -project Plurifold.xcodeproj \
  -scheme Plurifold \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$PLURIFOLD_SIMULATOR_ID" \
  -destination-timeout 120 \
  -parallel-testing-enabled NO \
  -derivedDataPath build/test-derived \
  -resultBundlePath build/test-results/Plurifold.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee build/test-results/xcodebuild-test.log
