#!/bin/bash
set -euo pipefail
ios_root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(xcodebuild -version | awk '/^Xcode / {print $2}')"
major="${version%%.*}"
minor="${version#*.}"
minor="${minor%%.*}"
if [[ "$major" != 26 ]] || (( minor < 3 )); then
    echo "Xcode 26.3 or newer 26.x is required; selected version is $version. No iOS build attempted." >&2
    exit 2
fi
sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)"
if [[ "${sdk_version%%.*}" != 26 ]]; then
    echo "The iOS 26 simulator SDK is required; selected SDK is $sdk_version." >&2
    exit 2
fi
# Pass a simulator destination returned by: xcrun simctl list devices available
destination="${1:-platform=iOS Simulator,name=iPhone 17}"
xcodebuild -project "$ios_root/Target.xcodeproj" -scheme Target -configuration Debug \
    -sdk iphonesimulator -destination "$destination" -derivedDataPath "$ios_root/.build/DerivedData" \
    CODE_SIGNING_ALLOWED=NO build test
