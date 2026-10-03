# Verification — 3 October 2026

## Completed

- Entire repository's specification, README, TypeScript game/UI/services, and browser test sources inspected. The behaviour audit is in `README.md` beside this file.
- **25 XCTest tests passed**, zero failures, using `bash ios/scripts/test_core.sh` with Xcode 26.3's host Swift compiler. Test execution took about 24 seconds. This runner uses the same unit-test source as the iOS target.
- **3,000 generated certificates independently replayed successfully**: Easy 1,000/1,000, Medium 1,000/1,000, Hard 1,000/1,000. No emergency Easy fallback occurred. Mean certified depths were 1.746, 3.598, and 4.689 moves respectively.
- A small independent shortcut sample found shorter paths in 0/10 Medium and 5/10 Hard rounds. This reflects the browser's bounded difficulty heuristic, not a solvability failure. Exact solvability is guaranteed by construction; difficulty does not guarantee a minimum shortest path.
- All 22 app Swift sources passed Swift 6 type-checking against the **iOS 26.2 simulator SDK**, targeting **iOS 26.0**. The compiler emitted a testable `Target.swiftmodule` successfully.
- The iOS XCTest source passed type-checking against that compiled module and the iOS XCTest framework.
- Xcode project/Info/privacy plist syntax, shared scheme/workspace XML, asset JSON, project references, inclusion of every Swift source, sound WAV structure, shell script syntax, and whitespace checks passed. The original app icon was visually inspected.

## Environment blocker

At the start, the selected installation was Xcode 16.2 with iOS 18.2 SDKs. During implementation the selected developer directory changed to `/Users/jamescrick/Downloads/Xcode.app/Contents/Developer`, reporting **Xcode 26.3, build 17C529**. The iOS 26.2 SDK files are present, but the required platform/runtime installation is incomplete.

`xcodebuild` was attempted using the Target scheme and `CODE_SIGNING_ALLOWED=NO`. After retrying outside the sandbox, a generic simulator build failed before source compilation because Xcode had no eligible destination and reported:

> iOS 26.2 is not installed. Please download and install the platform from Xcode > Settings > Components.

The simulator inventory contains only usable iOS 18.2 devices. The project has **not** been lowered to run on them.

Compiler-level checks use the real iOS 26 SDK and passed, but they do not replace a complete Xcode build, asset processing/linking, iOS XCTest execution, or a simulator/device launch. **The native application is not fully verified.**

## Remaining checks

1. Finish installing the iOS 26 platform and a matching simulator runtime in Xcode 26.3 → Settings → Components.
2. Open `Target.xcodeproj`, choose the Target scheme and an iOS 26 iPhone simulator, run ⌘R and ⌘U; alternatively use `bash ios/scripts/verify_ios.sh` from the repository root.
3. Resolve any project-build, asset-catalog, linking, or iOS-only runtime/test failures discovered by those checks.
4. Check all four screens at small and large iPhone sizes and with larger text, VoiceOver, and Reduced Motion. Confirm selection, invalid shake, tile convergence/reappearance, exact particles, near-miss hierarchy, final-10/final-3 timer states, and fast next-round play.
5. On an iPhone, check haptics, silent-switch behaviour, and sounds. Start a round, background/lock for more than 60 seconds, resume and confirm immediate timeout and exactly one stats record. Verify inactivity during a merge/exact celebration, undo near expiry, and stats surviving process restarts.

## Limits retained from the prototype

- A player's moves can leave an unsolvable board; a fresh round's certificate does not promise solvability after arbitrary choices. Hints honestly suggest undo when no exact path is found within budget.
- Difficulty is an internal heuristic with bounded shortcut rejection and a certified easier fallback.
- Sounds are lightweight placeholders. Device haptics and audio have not been physically assessed.
- Aggregate stats persist locally; in-flight rounds and session streaks do not survive process termination. Browser stats are not migrated.
