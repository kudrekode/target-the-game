export interface Stats { totalScore: number; bestScore: number; exactSolutions: number; bestStreak: number; roundsPlayed: number }
const empty = (): Stats => ({ totalScore: 0, bestScore: 0, exactSolutions: 0, bestStreak: 0, roundsPlayed: 0 });
export function loadStats(): Stats {
  try {
    const data = JSON.parse(localStorage.getItem('target.stats.v1') ?? '{}');
    const stats = empty();
    for (const key of Object.keys(stats) as (keyof Stats)[]) {
      if (Number.isSafeInteger(data[key]) && data[key] >= 0) stats[key] = data[key];
    }
    return stats;
  } catch { return empty(); }
}
export function saveStats(stats: Stats): boolean {
  try { localStorage.setItem('target.stats.v1', JSON.stringify(stats)); return true; } catch { return false; }
}
