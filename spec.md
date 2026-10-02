# Target — MVP Game Spec

## 1. Goal

Build a portrait mobile puzzle game called **Target**.

The player is given:
- a target number
- a small set of number tiles

They combine numbers using:
- addition
- subtraction
- multiplication
- division

The objective is to reach the target exactly, or get as close as possible before time runs out.

The game should feel:
- instantly understandable
- fast
- satisfying
- replayable
- mentally engaging
- suitable for 30-second to 3-minute sessions

This is an MVP/prototype.

Do NOT overengineer.

---

# 2. Technical Target

For the first version:

- Browser game
- TypeScript
- Vite
- HTML/CSS
- No backend
- No login
- No database
- No external APIs
- No real ads
- No payments
- Minimal dependencies

Must run with:

npm install
npm run dev

Design for portrait mobile first.

---

# 3. Core Concept

At the start of each round:

Show a TARGET number.

Example:

TARGET: 347

Then show six number tiles.

Example:

25
50
3
6
7
8

The player selects two number tiles and an operator.

Example:

25 × 8 = 200

Those two tiles disappear.

A new tile appears:

200

The player continues combining numbers until:

- they reach the target exactly
- only one number remains
- time expires

---

# 4. Operators

Allowed:

+
-
×
÷

Rules:

## Addition
Always allowed.

## Multiplication
Always allowed.

## Subtraction
Only allow positive results.

Example:

8 - 3 = 5

Do not allow:

3 - 8 = -5

## Division
Only allow exact integer division.

Example:

8 ÷ 4 = 2

Do not allow:

8 ÷ 3

No decimals in MVP.

---

# 5. Round Setup

Each round starts with:

- one target
- six number tiles
- countdown timer

Default timer:

60 seconds

Target range:

100–999

Initial tile pool:

Small numbers:
1–10

Large numbers:
25
50
75
100

Typical round:

- 4 small numbers
- 2 large numbers

Randomise each round.

Ensure generated rounds are at least plausibly playable.

Exact solvability is not required for every round in MVP.

---

# 6. Controls

Portrait mobile.

Interaction:

1. Tap first number.
2. Tap operator.
3. Tap second number.
4. Immediately show result.
5. Replace selected numbers with result tile.

Alternative valid sequence:

number
number
operator

is NOT required.

Keep one interaction model only.

Desktop:
mouse clicks.

---

# 7. Tile Behaviour

Each tile should display one integer.

Selected tile should visibly highlight.

When an operation is valid:

- selected tiles animate together
- result tile appears
- short satisfying pulse
- score updates

When invalid:

- shake selected tiles
- show small message

Examples:

"Must divide evenly"

or

"Result must be positive"

---

# 8. Winning

If player produces a number equal to the target:

Show:

EXACT!

Stop timer.

Award bonus score.

Display:

- target
- time remaining
- number of operations
- score

Then:

NEXT ROUND

---

# 9. Non-Exact Ending

If timer expires or only one tile remains:

Calculate difference:

difference = abs(finalClosestValue - target)

Display:

TARGET: 347
CLOSEST: 344
OFF BY: 3

Score based on closeness.

Then allow:

NEXT ROUND

---

# 10. Closest Number

At all times track the tile currently closest to the target.

If multiple tiles are equally close, either is acceptable.

Show optional small UI:

Closest: 312

This helps the player understand progress.

---

# 11. Scoring

Keep scoring simple.

Suggested:

Exact target:
1000 points

Within 5:
500 points

Within 10:
300 points

Within 25:
150 points

Within 50:
75 points

Otherwise:
25 points

Bonuses:

Time bonus:
+10 points per second remaining

Efficiency bonus:
+50 if exact result reached in 5 operations or fewer

Make all values configurable.

---

# 12. Combo / Streak

Track exact-target streak.

Example:

STREAK: 3

Each consecutive exact result increases multiplier:

1 exact = ×1
2 exact = ×1.1
3 exact = ×1.2
4 exact = ×1.3

Cap at reasonable value.

Missing the target resets streak.

Keep formula configurable.

---

# 13. Game Modes

For MVP implement only:

## Classic
60-second rounds.

Do NOT add:
- daily challenge
- endless mode
- multiplayer
- leaderboards
- AI opponents

These can come later.

---

# 14. Hint System

Add a simple simulated rewarded-ad hook.

Button:

HINT

Behaviour:

Call:

RewardedAdService.showRewardedAd(callback)

For MVP it succeeds immediately.

Then reveal one valid operation that moves toward the target.

Hint does NOT need to show the full solution.

Example:

"Try 50 × 6"

Do not integrate a real ad SDK.

---

# 15. Undo

Allow one free undo per round.

After that:

UNDO button can use simulated rewarded ad.

For MVP:

- first undo free
- additional undo calls simulated rewarded ad

Undo should restore previous tile state.

Keep full round history simple.

---

# 16. Progression

Persist:

- total score
- best score
- exact solutions
- best exact streak
- rounds played

No upgrade economy yet.

The game should stand on the puzzle itself.

---

# 17. Visual Style

Portrait.

Style target:

- clean
- bold
- high contrast
- tactile
- calculator-like
- arcade/puzzle feel

Avoid:
- corporate dashboard style
- realistic graphics
- complicated backgrounds
- tiny controls

Tiles should be large and satisfying to press.

The target number should dominate the screen.

---

# 18. Animation Priorities

Prioritise:

1. tile selection
2. tile combination
3. result appearing
4. exact-target celebration
5. timer urgency

When timer reaches 10 seconds:

- timer becomes visually urgent
- subtle pulse allowed

Do not use excessive animation.

---

# 19. Sound

Optional placeholders.

Useful events:

- tile tap
- operation
- invalid operation
- exact target
- timer warning
- round end

Do not spend significant time sourcing audio.

---

# 20. Screens

Only create:

## Home
TARGET

PLAY
STATS

## Game
Target
Timer
Score
Number tiles
Operators
Hint
Undo

## Round Result
Target
Closest/result
Difference
Score
Streak
Next Round

## Stats
Rounds played
Exact solutions
Best streak
Best score

No additional screens.

---

# 21. Saving

Use localStorage.

Persist:

- total score
- best score
- rounds played
- exact solutions
- best streak

No account system.

---

# 22. Analytics

No external analytics.

Create:

trackEvent(name, properties)

For now console.log.

Track:

round_started
operation_used
invalid_operation
target_exact
round_failed
hint_used
undo_used

---

# 23. Suggested Code Structure

src/
  game/
    gameState.ts
    generator.ts
    scoring.ts
    operations.ts
    hints.ts
    balance.ts
  services/
    saveService.ts
    adService.ts
    analyticsService.ts
  ui/

Avoid:

- Redux
- backend
- complex solver architecture
- unnecessary state libraries
- excessive abstractions

---

# 24. Round Generator

Keep number generation straightforward.

Default:

- choose four numbers from 1–10
- choose two numbers from 25, 50, 75, 100
- target between 100 and 999

Avoid duplicate large numbers unless intentionally allowed.

Do not spend large amounts of implementation time guaranteeing mathematically solvable targets.

---

# 25. Hint Solver

Hint system may use a lightweight recursive search over available numbers.

Requirements:

- find a valid operation that improves distance to target
- avoid expensive exhaustive search if unnecessary
- six numbers only, so simple recursion is acceptable

Do not build an elaborate AI system.

---

# 26. Important Product Principle

The player should understand the game within 5 seconds:

"Combine numbers to hit the target."

There should be almost no explanation required.

The enjoyment should come from:

- spotting combinations
- racing the timer
- getting exact solutions
- building streaks

---

# 27. Definition of MVP Complete

MVP is complete when:

- game launches
- targets generate
- six number tiles generate
- player can select numbers/operators
- valid maths works
- invalid maths is rejected
- result tiles replace used tiles
- timer works
- exact target detection works
- closest result works
- scoring works
- streak works
- hint works
- undo works
- stats save locally
- game is comfortable at portrait phone dimensions
- no major runtime/build errors

Stop when these requirements are met.

Do not add additional systems without asking.