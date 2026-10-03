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

Generation builds a legal solution first and derives its target from the final expression. Easy uses 1–3 operations, Medium 3–4, and Hard 4–5. Medium starts at streak 2 and Hard at streak 5; these thresholds and search budgets are in `balance.ts`. Medium and Hard reject shorter shortcuts when possible. A rare generation-budget fallback can be easier, but retains an exact solution.

Hints first use the verified generation path, including intermediate moves that temporarily increase distance. After a different player move or undo, a memoized, bounded search looks for a new exact path. When none is found within the budget, the hint suggests undoing rather than claiming an exact solution. Quiet synthesized sounds use Web Audio after the first interaction; no audio files or packages are required. Reduced-motion preferences disable the visual effects.

## Check gameplay

```sh
npm test
```

The test independently replays 3,000 generated solution paths (1,000 per band), checks pools and target bounds, samples shorter shortcuts, and verifies intermediate hints and undo IDs. The quality-pass sample achieved 100% exact solvability across all three bands. This describes fresh rounds; player choices can make the remaining tiles unsolvable.

## Presentation feedback

`src/services/feedbackService.ts` exposes lightweight feedback events for tile/operator selection, combinations, merges, invalid moves, hint, undo, urgency, and round outcomes. `setHapticHandler(handler)` lets a future native bridge receive `lightTap`, `mergeImpact`, `invalidImpact`, and `successImpact`; browsers do not vibrate. Sound is synthesized locally with Web Audio.

The board preserves six visual slots through operations and undo. The portrait layouts were checked at 390×844 and 320×568, including exact, off-by-1, wider-miss, and timeout results. CSS and Web Animations respect reduced-motion preferences.
