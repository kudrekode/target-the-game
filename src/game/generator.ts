import { BALANCE } from './balance';
import { calculate, OPERATORS } from './operations';
import { canReachWithin, type SolutionStep } from './solver';
import { difficultyForLevel, type Difficulty } from './difficulty';
export type { Difficulty } from './difficulty';
export interface GeneratedRound { target: number; numbers: number[]; difficulty: Difficulty; solution: SolutionStep[] }
const randomInt = (min: number, max: number) => min + Math.floor(Math.random() * (max - min + 1));
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
export function generateRound(level = 0): GeneratedRound {
  const difficulty = difficultyForLevel(level);
  const band = BALANCE.difficulty[difficulty];
  const deadline = performance.now() + BALANCE.generationTimeBudgetMs;
  for (let attempt = 0; attempt < BALANCE.generationAttempts; attempt++) {
    if (performance.now() >= deadline) break;
    const numbers = generateNumbers();
    const work = numbers.map((value, id) => ({ value, id }));
    const steps: SolutionStep[] = [];
    const count = band.operations;
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
    if (!canReachWithin(numbers, final.value, count - 1)) return candidate;
  }
  return fallbackRound(difficulty);
}

// These emergency certificates are independently checked by the regression
// suite for exact minimum depth. Budget pressure must never change the band.
export function fallbackRound(difficulty: Difficulty): GeneratedRound {
  const rounds: Record<Difficulty, Omit<GeneratedRound, 'difficulty'>> = {
    Easy: { target: 189, numbers: [6, 4, 4, 9, 50, 25], solution: [
      { first: 5, second: 1, operator: '-', value: 21, resultId: 6 },
      { first: 3, second: 6, operator: '×', value: 189, resultId: 7 },
    ] },
    Medium: { target: 215, numbers: [1, 3, 9, 8, 50, 25], solution: [
      { first: 3, second: 1, operator: '×', value: 24, resultId: 6 },
      { first: 2, second: 6, operator: '×', value: 216, resultId: 7 },
      { first: 7, second: 0, operator: '-', value: 215, resultId: 8 },
    ] },
    Hard: { target: 557, numbers: [5, 4, 9, 8, 75, 50], solution: [
      { first: 5, second: 2, operator: '×', value: 450, resultId: 6 },
      { first: 1, second: 3, operator: '×', value: 32, resultId: 7 },
      { first: 7, second: 6, operator: '+', value: 482, resultId: 8 },
      { first: 8, second: 4, operator: '+', value: 557, resultId: 9 },
    ] },
  };
  return { ...rounds[difficulty], difficulty };
}
