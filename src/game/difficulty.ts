import { BALANCE } from './balance';

export type Difficulty = 'Easy' | 'Medium' | 'Hard';

export function difficultyForLevel(level: number): Difficulty {
  return level >= BALANCE.difficulty.hardLevel ? 'Hard' : level >= BALANCE.difficulty.mediumLevel ? 'Medium' : 'Easy';
}

// Session skill is separate from the score streak. A miss removes one step,
// rather than discarding all progress, and the cap keeps relief within reach.
export function nextDifficultyLevel(level: number, exact: boolean): number {
  return Math.max(0, Math.min(BALANCE.difficulty.maxLevel, level + (exact ? 1 : -1)));
}
