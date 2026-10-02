import { calculate, OPERATORS, type Operator } from './operations';

export interface SolverTile { id: number; value: number }
export interface SolutionStep { first: number; second: number; operator: Operator; value: number; resultId: number }
export interface SearchOptions { maxOperations: number; nodeBudget: number; timeBudgetMs: number }

// Iterative depth search prefers short solutions. Failed value states are memoized;
// IDs are retained in the returned path so duplicate numbers and undo stay safe.
export function findSolution(tiles: SolverTile[], target: number, nextId: number, options: SearchOptions) {
  const deadline = performance.now() + options.timeBudgetMs;
  let nodes = 0;
  let limited = false;
  const failed = new Set<string>();
  function search(work: SolverTile[], depth: number, id: number): SolutionStep[] | null {
    if (work.some(tile => tile.value === target)) return [];
    if (depth === 0 || work.length < 2) return null;
    if (++nodes > options.nodeBudget || performance.now() >= deadline) { limited = true; return null; }
    const key = `${depth}:${work.map(t => t.value).sort((a, b) => a - b).join(',')}`;
    if (failed.has(key)) return null;
    const moves: SolutionStep[] = [];
    for (let i = 0; i < work.length; i++) for (let j = 0; j < work.length; j++) {
      if (i === j) continue;
      for (const operator of OPERATORS) {
        if ((operator === '+' || operator === '×') && j < i) continue;
        const result = calculate(work[i].value, operator, work[j].value);
        if (result.value === undefined || result.value === work[i].value || result.value === work[j].value) continue;
        moves.push({ first: work[i].id, second: work[j].id, operator, value: result.value, resultId: id });
      }
    }
    moves.sort((a, b) => Math.abs(a.value - target) - Math.abs(b.value - target));
    for (const move of moves) {
      const rest = work.filter(t => t.id !== move.first && t.id !== move.second);
      const tail = search([...rest, { id, value: move.value }], depth - 1, id + 1);
      if (tail) return [move, ...tail];
      if (limited) return null;
    }
    failed.add(key);
    return null;
  }
  for (let depth = 0; depth <= Math.min(options.maxOperations, tiles.length - 1); depth++) {
    const steps = search(tiles, depth, nextId);
    if (steps) return { steps, complete: true, nodes };
    if (limited) break;
  }
  return { steps: null, complete: !limited, nodes };
}
