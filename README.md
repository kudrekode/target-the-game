# Target

The native iPhone app is in [`ios/`](ios/README.md). Open `ios/Target.xcodeproj` with Xcode 26.3 and install the iOS 26 platform/runtime. The browser implementation below remains the gameplay reference.

A portrait-first Classic number puzzle built with TypeScript, Vite, and plain HTML/CSS. The project specification is in `spec.md`.

## Run

```sh
npm install
npm run dev
```

Open the local URL printed by Vite. Click or tap a number, an operator, then another number. Subtraction must be positive and division must produce an integer.

```sh
npm run build
npm run preview
```

## Tune

`src/game/balance.ts` contains timer duration, target range, tile pools/counts, generation attempts, hint search limits, scoring tiers, bonuses, and streak settings. Game logic lives in `src/game`, browser presentation in `src/main.ts` and `src/ui/style.css`, and storage/reward/event hooks in `src/services`.

Hints and additional undos use an immediate simulated reward. Stats save to this browser's localStorage. `bestScore` records the best individual round. The active streak continues between rounds during a play session. Timer continues while the tab is in the background.

Generation builds a legal solution first and derives its target from the final expression. Easy requires exactly 2 operations, Medium 3, and Hard 4 in the shortest solution. An exhaustive check of disjoint tile subsets rejects all shorter paths, including branched expressions and duplicate tiles. Generation has a 30 ms soft budget; a shortcut check already in progress finishes before returning. If time or attempts run out, a preverified fallback preserves the requested band and exact solvability.

Difficulty uses a separate session level (0–8). Exact results add one level; misses remove one. Medium starts at level 3 and Hard at level 6, so uninterrupted wins progress through three Easy rounds, three Medium rounds, then Hard. A miss reduces difficulty by at most one band instead of resetting to Easy. The scoring streak still resets on a miss. Session level survives Home/Stats navigation and resets when the app reloads; thresholds and operation counts are in `balance.ts`.

Hints first use the verified generation path, including intermediate moves that temporarily increase distance. After a different player move or undo, a memoized, bounded search looks for a new exact path. When none is found within the budget, the hint suggests undoing rather than claiming an exact solution. Quiet synthesized sounds use Web Audio after the first interaction; no audio files or packages are required. Reduced-motion preferences disable the visual effects.

## Check gameplay

```sh
npm test
```

The test independently replays 3,000 generated solution paths (1,000 per band), checks pools and target bounds, and audits 100 rounds per band with a separate search algorithm that must complete and find no shorter solution. It also checks gradual progression/relief, exhausted time/attempt budgets, pathological randomness, fallback minimum depths, intermediate hints, and undo IDs. Fresh rounds are exactly solvable; player choices can make the remaining tiles unsolvable.

The 4 October 2026 difficulty audit reproduced the unevenness: Easy certificates varied from 1–3 moves, the old Hard shortcut sample found easier paths in 57/100 rounds, and any miss reset difficulty to Easy. After the fix, all 3,000 browser certificates replayed exactly at 2/3/4 moves and the independent shortcut sample found 0/100 shortcuts in each band. The native implementation uses the same progression, checks, and fallback certificates.

## Presentation feedback

`src/services/feedbackService.ts` exposes lightweight feedback events for tile/operator selection, combinations, merges, invalid moves, hint, undo, urgency, and round outcomes. `setHapticHandler(handler)` lets a future native bridge receive `lightTap`, `mergeImpact`, `invalidImpact`, and `successImpact`; browsers do not vibrate. Sound is synthesized locally with Web Audio.

The board preserves six visual slots through operations and undo. The portrait layouts were checked at 390×844 and 320×568, including exact, off-by-1, wider-miss, and timeout results. CSS and Web Animations respect reduced-motion preferences.
