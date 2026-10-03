# Target for iPhone

A native SwiftUI number puzzle, with the TypeScript game kept as the behavioural reference. No WebView, packages, accounts, backend, analytics endpoint, or ad SDK.

## Open and run

1. Open `Target.xcodeproj` in **Xcode 26.3** (or a newer 26.x release).
2. In Xcode → Settings → Components, finish installing the **iOS 26 platform and simulator runtime**. Xcode 26.3 supplies the iOS 26.2 SDK; the deployment target is **iOS 26.0**.
3. Select the shared **Target** scheme and an iPhone running iOS 26. Press **⌘R** to play and **⌘U** to test.

Simulator builds disable signing and require no developer account. For a physical iPhone, select your signing team and a unique bundle identifier. The app supports portrait iPhones only.

From the repository root, after installing the platform/runtime:

```sh
bash ios/scripts/verify_ios.sh
# Or use an available simulator UUID:
bash ios/scripts/verify_ios.sh 'platform=iOS Simulator,id=YOUR-SIMULATOR-UUID'
```

The script checks Xcode 26.3+ within the 26.x series and the iOS 26 SDK before building and running XCTest. It never changes the deployment target.

For supplemental pure Swift tests on macOS, without an iOS simulator:

```sh
bash ios/scripts/test_core.sh
```

That runner compiles the same `TargetCoreTests.swift` against the game/model sources and native stats store. It does **not** verify the SwiftUI app, assets, signing, iOS execution, or simulator lifecycle.

## Native structure

| Directory | Responsibility |
| --- | --- |
| `Target/App` | SwiftUI app entry and one observable, main-actor view model |
| `Target/Models` | Round, tile identities/slots, arithmetic operations, result, saved stats |
| `Target/Game` | Balance, solution-first generator, bounded solver, hints, game state, scoring, streaks |
| `Target/Services` | Continuous clock, UserDefaults, UIKit feedback, optional local audio |
| `Target/Views` | Home, Game, Round Result, Stats |
| `Target/Design` | Shared spacing, radii, type, palette, timing, key/button styles, shake |
| `Target/Resources` | Launch colour, original geometric icon, privacy manifest, placeholder WAV sounds |
| `Target/Tests` | XCTest rules, generation, solver/hints, undo, deadlines, scores, persistence |

Game logic contains no SwiftUI or UIKit imports. State uses value types and injected elapsed time; UI animation never changes arithmetic. Hints search an immutable snapshot away from the main thread and discard stale responses. Every result records stats once, including an exact result committed immediately before its visual celebration.

## Behaviour audit

The working browser implementation takes precedence over the older `spec.md`:

| Topic | Original spec | Browser reference and native behaviour |
| --- | --- | --- |
| Solvability | Plausible rounds; exact optional | Derive every target from a certified legal expression |
| Difficulty | No bands specified | Easy 1–3 moves; Medium 3–4 from streak 2; Hard 4–5 from streak 5 |
| Difficulty guarantee | Unspecified | Reject short shortcuts within a budget; certified fallback may be easier |
| Hints | A move improving immediate distance | Verified exact path, including necessary moves away from target; bounded search after deviations/undo |
| Closest | Closest current tile | Current available tiles, never a consumed historical value |
| Score | Suggested tiers/bonuses | 1000 exact; 500/300/150/75 at distances 5/10/25/50; 25 otherwise; floor(seconds) × 10 on every result; exact +50 at ≤5 moves |
| Streak | Configurable cap | Exact increases session streak, misses reset it; exact multiplier rises 0.1 per streak after the first, capped at 2 |
| Best score | Unspecified scope | Best individual round |
| Undo and hints | Immediate simulated rewards | Same availability; one free undo and all subsequent undos succeed without any ad flow |
| Timing | 60 seconds | 60 seconds, evaluated against an elapsed-time deadline, including inactive/background time |

Four small numbers (1–10) and two distinct large numbers (25/50/75/100), six fixed slots, positive subtraction, exact integer division, safe integer bounds, monotonic result IDs, undo history, scoring, and session streak retention through Home/Stats all match the browser. The generated-round test independently replays 1,000 certificates per difficulty band instead of trusting the solver's claim.

## Deliberate native differences

The visual design is an ivory calculator surface with ink typography, orange selected keys, and green exact/result keys. It uses native spring merges, shake rejection, SF Symbols, haptics, and a brief radial exact celebration. Difficulty appears as a three-bar intensity mark. The browser's reward labels and immediate callback stub are removed; hint and undo remain immediately available. Sounds are quiet bundled synthesized placeholders; they respect silent mode and stop on inactivity. Reduced Motion removes movement effects, and scrollable layouts accommodate smaller phones and larger text.

Stats belong to this app's UserDefaults and are not imported from browser localStorage. A process restart starts at Home with saved aggregate stats and a fresh session streak; an interrupted round is not restored. No cloud save is added. The ContinuousClock timer ignores changes to the wall clock and includes device sleep.

The privacy manifest declares only app-local UserDefaults access using Apple's [required-reason API documentation](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype). Resources can be reproduced with `python3 ios/scripts/make_resources.py`; no generation tool is required to build.

## Verification

See `VERIFICATION.md` for the checks completed in this checkout and the remaining platform-dependent checks. A compiler-only check is not a successful Xcode project build or an iPhone launch.
