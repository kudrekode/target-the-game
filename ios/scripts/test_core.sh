#!/bin/bash
set -euo pipefail
ios_root="$(cd "$(dirname "$0")/.." && pwd)"
test_build="$(mktemp -d "${TMPDIR:-/tmp}/target-core.XXXXXX")"
trap 'rm -rf "$test_build"' EXIT
mkdir -p "$ios_root/.build/CoreModuleCache"
sources=()
while IFS= read -r source; do sources+=("$source"); done < <(find "$ios_root/Target/Models" "$ios_root/Target/Game" -name '*.swift' | sort)
cat > "$test_build/main.swift" <<'SWIFT'
import XCTest
import Foundation
let suite = TargetCoreTests.defaultTestSuite
suite.run()
guard let run = suite.testRun, run.executionCount > 0 else {
    fatalError("No core tests were discovered")
}
exit(run.hasSucceeded ? 0 : 1)
SWIFT
# Supplemental host checks only. This does not build or verify the iOS application.
developer_dir="$(xcode-select -p)"
test_frameworks="$developer_dir/Platforms/MacOSX.platform/Developer/Library/Frameworks"
test_libraries="$developer_dir/Platforms/MacOSX.platform/Developer/usr/lib"
test_private_frameworks="$developer_dir/Platforms/MacOSX.platform/Developer/Library/PrivateFrameworks"
xcrun swiftc -swift-version 6 -O -D CORE_TEST_RUNNER -module-cache-path "$ios_root/.build/CoreModuleCache" \
    -F "$test_frameworks" -Xlinker -rpath -Xlinker "$test_frameworks" \
    -I "$test_libraries" -L "$test_libraries" -lXCTestSwiftSupport -Xlinker -rpath -Xlinker "$test_libraries" \
    -Xlinker -rpath -Xlinker "$test_private_frameworks" \
    "${sources[@]}" "$ios_root/Target/Services/RoundClock.swift" "$ios_root/Target/Services/StatsStore.swift" \
    "$ios_root/Target/Tests/TargetCoreTests.swift" "$test_build/main.swift" -o "$test_build/TargetCoreTests"
"$test_build/TargetCoreTests"
