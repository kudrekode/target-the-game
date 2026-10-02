import { calculate } from './operations';
import type { Round } from './gameState';
import { BALANCE } from './balance';
import { findSolution } from './solver';

export function getHint(round: Round): string {
  // Resume the generated path whenever its remaining inputs are available.
  // Verify values as well as IDs; after undo, fresh IDs use the search below.
  const work = round.tiles.map(t => ({ ...t }));
  const completed = round.solution.reduce((last, step, index) =>
    work.some(t => t.id === step.resultId && t.value === step.value) ? index : last, -1);
  let steps = round.solution.slice(completed + 1);
  const verified = steps.length > 0 && steps.every(step => {
    const a = work.find(t => t.id === step.first), b = work.find(t => t.id === step.second);
    if (!a || !b || calculate(a.value, step.operator, b.value).value !== step.value) return false;
    work.splice(work.indexOf(a), 1); work.splice(work.indexOf(b), 1);
    work.push({ id: step.resultId, value: step.value });
    return true;
  }) && work.some(t => t.value === round.target);
  if (!verified) {
    steps = findSolution(round.tiles, round.target, round.nextId, {
      maxOperations: round.tiles.length - 1, nodeBudget: BALANCE.hintNodeBudget, timeBudgetMs: BALANCE.hintTimeBudgetMs,
    }).steps ?? [];
  }
  if (steps.length) {
    const step = steps[0];
    const a = round.tiles.find(t => t.id === step.first)!, b = round.tiles.find(t => t.id === step.second)!;
    return `Try ${a.value} ${step.operator} ${b.value}${steps.length > 1 ? ' — build toward an exact solution' : ' — exact!'}`;
  }
  // No false promise of an exact solution after a player has used needed tiles.
  return round.tiles.some(t => t.value === round.target) ? 'You’ve reached the target!' : 'No exact path found here. Try undoing a move.';
}
