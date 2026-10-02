import { BALANCE } from './balance';
import { calculate, OPERATORS } from './operations';
import { findSolution, type SolutionStep } from './solver';
export type Difficulty = 'Easy' | 'Medium' | 'Hard';
export interface GeneratedRound { target: number; numbers: number[]; difficulty: Difficulty; solution: SolutionStep[] }
const randomInt = (min: number, max: number) => min + Math.floor(Math.random() * (max - min + 1));
export function difficultyForStreak(streak: number): Difficulty {
  return streak >= BALANCE.difficulty.hardStreak ? 'Hard' : streak >= BALANCE.difficulty.mediumStreak ? 'Medium' : 'Easy';
}
function generateNumbers(): number[] {
  const numbers = Array.from({ length: BALANCE.smallCount }, () => randomInt(BALANCE.smallMin, BALANCE.smallMax));
  const pool = [...BALANCE.largePool];
  for (let i = 0; i < BALANCE.largeCount; i++) {
    const index = randomInt(0, pool.length - 1);
    numbers.push(pool[index]);
    if (!BALANCE.allowDuplicateLarge) pool.splice(index, 1);
  }
  return numbers;
}
export function generateRound(streak = 0): GeneratedRound {
  const difficulty = difficultyForStreak(streak);
  const band = BALANCE.difficulty[difficulty];
  const deadline = performance.now() + BALANCE.generationTimeBudgetMs;
  let fallback: GeneratedRound | undefined;
  for (let attempt = 0; attempt < BALANCE.generationAttempts; attempt++) {
    const numbers = generateNumbers();
    const work = numbers.map((value, id) => ({ value, id }));
    const steps: SolutionStep[] = [];
    const count = randomInt(band.minOperations, band.maxOperations);
    for (let i = 0; i < count; i++) {
      const aIndex = randomInt(0, work.length - 1);
      const bIndex = (aIndex + randomInt(1, work.length - 1)) % work.length;
      const a = work[aIndex], b = work[bIndex];
      // Pick from legal moves rather than wasting attempts on invalid arithmetic.
      const moves = OPERATORS.flatMap(operator => {
        const result = calculate(a.value, operator, b.value);
        return result.value !== undefined && result.value !== a.value && result.value !== b.value
          ? [{ first: a.id, second: b.id, operator, value: result.value, resultId: numbers.length + i }] : [];
      });
      if (!moves.length) break;
      const move = moves[randomInt(0, moves.length - 1)];
      steps.push(move);
      work.splice(Math.max(aIndex, bIndex), 1); work.splice(Math.min(aIndex, bIndex), 1);
      work.push({ id: move.resultId, value: move.value });
    }
    const final = steps.at(-1);
    if (!final || steps.length !== count || final.value < BALANCE.targetMin || final.value > BALANCE.targetMax || numbers.includes(final.value)) continue;
    // Discard independent detours: only operations used by the final expression count.
    const used = new Set([final.resultId]);
    for (const step of [...steps].reverse()) if (used.has(step.resultId)) { used.add(step.first); used.add(step.second); }
    if (steps.some(step => !used.has(step.resultId))) continue;
    const candidate = { target: final.value, numbers, difficulty, solution: steps };
    fallback ??= candidate;
    if (difficulty === 'Easy') return candidate;
    const shallow = findSolution(numbers.map((value, id) => ({ value, id })), final.value, numbers.length, {
      maxOperations: band.minOperations - 1, nodeBudget: BALANCE.generationSearchNodes, timeBudgetMs: BALANCE.generationSearchMs,
    });
    if (shallow.complete && !shallow.steps) return candidate;
    if (performance.now() >= deadline) break;
  }
  // A rare budget fallback remains certified solvable; difficulty is a heuristic.
  if (fallback) return fallback;
  // Guaranteed quick, legal construction for the default pools, even with unlucky randomness.
  const numbers = [2, 3, 7, 8, 25, 75];
  return { numbers, target: 200, difficulty: 'Easy', solution: [{ first: 4, second: 3, operator: '×', value: 200, resultId: 6 }] };
}
