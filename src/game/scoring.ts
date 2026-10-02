import { BALANCE } from './balance';
export function multiplier(streak: number): number {
  return Math.min(BALANCE.streakCap, 1 + Math.max(0, streak - 1) * BALANCE.streakStep);
}
export function scoreRound(distance: number, seconds: number, operations: number, streak: number) {
  const exact = distance === 0;
  const base = exact ? BALANCE.exactPoints : BALANCE.proximity.find(tier => distance <= tier.distance)?.points ?? BALANCE.minimumPoints;
  const time = Math.floor(seconds) * BALANCE.timePointsPerSecond;
  const efficiency = exact && operations <= BALANCE.efficiencyMaxOperations ? BALANCE.efficiencyPoints : 0;
  const factor = exact ? multiplier(streak) : 1;
  return { base, time, efficiency, factor, total: Math.round((base + time + efficiency) * factor) };
}
