import { calculate, type Operator } from './operations';
import { generateRound, type Difficulty } from './generator';
import type { SolutionStep } from './solver';
import { BALANCE } from './balance';
export interface Tile { id: number; value: number }
export interface Round { target: number; tiles: Tile[]; history: Tile[][]; operations: number; undoCount: number; deadline: number; nextId: number; difficulty: Difficulty; solution: SolutionStep[] }
export function createRound(level = 0): Round {
  const { target, numbers, difficulty, solution } = generateRound(level);
  return { target, difficulty, solution, tiles: numbers.map((value, id) => ({ id, value })), history: [], operations: 0, undoCount: 0, deadline: performance.now() + BALANCE.seconds * 1000, nextId: numbers.length };
}
export function remaining(round: Round): number { return Math.max(0, (round.deadline - performance.now()) / 1000); }
export function closest(round: Round): Tile {
  return round.tiles.reduce((best, tile) => Math.abs(tile.value - round.target) < Math.abs(best.value - round.target) ? tile : best);
}
export function combine(round: Round, first: number, op: Operator, second: number) {
  const a = round.tiles.find(t => t.id === first);
  const b = round.tiles.find(t => t.id === second);
  if (!a || !b || a.id === b.id) return { error: 'Select two different numbers' };
  const result = calculate(a.value, op, b.value);
  if (result.error || result.value === undefined) return result;
  round.history.push(round.tiles.map(t => ({ ...t })));
  const tile = { id: round.nextId++, value: result.value };
  const firstIndex = round.tiles.findIndex(t => t.id === first);
  round.tiles = round.tiles.filter(t => t.id !== second).map(t => t.id === first ? tile : t);
  round.operations++;
  return { value: result.value, tile, firstIndex };
}
export function undo(round: Round): boolean {
  const previous = round.history.pop();
  if (!previous) return false;
  round.tiles = previous;
  round.operations--;
  round.undoCount++;
  return true;
}
