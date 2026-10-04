import assert from 'node:assert/strict';
import { generateRound, fallbackRound } from '../src/game/generator';
import { difficultyForLevel, nextDifficultyLevel } from '../src/game/difficulty';
import { createRound, combine, undo } from '../src/game/gameState';
import { getHint } from '../src/game/hints';
import { canReachWithin, findSolution } from '../src/game/solver';
import { BALANCE } from '../src/game/balance';

// Deterministic sample, independently replaying every certified solution.
let seed = 82719;
Math.random = () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; };
assert.equal(difficultyForLevel(0), 'Easy');
assert.equal(difficultyForLevel(2), 'Easy');
assert.equal(difficultyForLevel(3), 'Medium');
assert.equal(difficultyForLevel(5), 'Medium');
assert.equal(difficultyForLevel(6), 'Hard');
let level = 0;
const progression = [];
for (let i = 0; i < 10; i++) {
  progression.push(BALANCE.difficulty[difficultyForLevel(level)].operations);
  level = nextDifficultyLevel(level, true);
}
assert.deepEqual(progression, [2, 2, 2, 3, 3, 3, 4, 4, 4, 4]);
assert.equal(level, 8);
level = nextDifficultyLevel(level, false);
assert.equal(difficultyForLevel(level), 'Hard'); // One miss does not reset skill.
level = nextDifficultyLevel(nextDifficultyLevel(level, false), false);
assert.equal(difficultyForLevel(level), 'Medium');
assert.equal(difficultyForLevel(nextDifficultyLevel(level, true)), 'Hard');
assert.equal(nextDifficultyLevel(0, false), 0);
for (let level = 0; level <= BALANCE.difficulty.maxLevel; level++) {
  const before = BALANCE.difficulty[difficultyForLevel(level)].operations;
  const afterMiss = BALANCE.difficulty[difficultyForLevel(nextDifficultyLevel(level, false))].operations;
  const afterExact = BALANCE.difficulty[difficultyForLevel(nextDifficultyLevel(level, true))].operations;
  assert.ok(before - afterMiss >= 0 && before - afterMiss <= 1);
  assert.ok(afterExact - before >= 0 && afterExact - before <= 1);
}
assert.equal(canReachWithin([2, 2, 25], 100, 1), false);
assert.equal(canReachWithin([2, 2, 25], 100, 2), true);
assert.equal(canReachWithin([25, 5, 7, 5], 1500, 2), false);
assert.equal(canReachWithin([25, 5, 7, 5], 1500, 3), true); // Two independent branches.
assert.equal(canReachWithin([100, 4], 25, 1), true);
assert.equal(canReachWithin([8, 3], 2, 1), false); // No rounded division.
const report = [];
for (const [band, level] of [['Easy', 0], ['Medium', 3], ['Hard', 6]] as const) {
  let exact = 0, shorter = 0, checked = 0, fallbacks = 0;
  const times: number[] = [], depths: number[] = [];
  for (let i = 0; i < 1000; i++) {
    const before = performance.now();
    const generated = generateRound(level);
    times.push(performance.now() - before);
    assert.equal(generated.numbers.length, 6);
    assert.ok(generated.numbers.slice(0, 4).every(n => n >= BALANCE.smallMin && n <= BALANCE.smallMax));
    assert.ok(generated.numbers.slice(4).every(n => BALANCE.largePool.includes(n)));
    assert.equal(new Set(generated.numbers.slice(4)).size, 2);
    assert.ok(generated.target >= BALANCE.targetMin && generated.target <= BALANCE.targetMax);
    const work = new Map(generated.numbers.map((value, id) => [id, value]));
    for (const step of generated.solution) {
      assert.notEqual(step.first, step.second);
      const a = work.get(step.first), b = work.get(step.second);
      assert.notEqual(a, undefined); assert.notEqual(b, undefined);
      const value = step.operator === '+' ? a! + b! : step.operator === '-' ? a! - b! : step.operator === '×' ? a! * b! : a! / b!;
      assert.ok(Number.isSafeInteger(value) && value > 0);
      assert.equal(value, step.value);
      work.delete(step.first); work.delete(step.second); work.set(step.resultId, value);
    }
    if ([...work.values()].includes(generated.target)) exact++;
    depths.push(generated.solution.length);
    assert.equal(generated.difficulty, band);
    assert.equal(generated.solution.length, BALANCE.difficulty[band].operations);
    const fallback = fallbackRound(band);
    if (generated.target === fallback.target && generated.numbers.every((n, i) => n === fallback.numbers[i])) fallbacks++;
    if (i < 100) {
      const result = findSolution(generated.numbers.map((value,id)=>({value,id})), generated.target, 6, {maxOperations: BALANCE.difficulty[band].operations - 1, nodeBudget: 1000000, timeBudgetMs: 1000});
      assert.ok(result.complete, 'Independent shortcut audit must finish');
      assert.equal(result.steps, null, `${band} must reject shorter solutions`);
      if (result.complete) { checked++; if(result.steps) shorter++; }
    }
  }
  times.sort((a,b)=>a-b);
  report.push({ band, rounds:1000, exact, exactRate:exact / 10 + '%', meanMs:+(times.reduce((a,b)=>a+b,0)/1000).toFixed(2), p95Ms:+times[950].toFixed(2), maxMs:+times[999].toFixed(2), meanSolutionOperations:+(depths.reduce((a,b)=>a+b,0)/1000).toFixed(2), shorter, shortcutSample:checked, fallbacks });
  assert.equal(exact,1000);
}
// Force both the time and attempt limit paths: no uncertified candidate or
// easier emergency board may escape under budget pressure or unlucky entropy.
const attempts = BALANCE.generationAttempts, timeBudget = BALANCE.generationTimeBudgetMs;
for (const [band, level] of [['Easy', 0], ['Medium', 3], ['Hard', 6]] as const) {
  const fallback = fallbackRound(band);
  BALANCE.generationTimeBudgetMs = 0;
  assert.deepEqual(generateRound(level), fallback);
  BALANCE.generationTimeBudgetMs = timeBudget;
  BALANCE.generationAttempts = 0;
  assert.deepEqual(generateRound(level), fallback);
  BALANCE.generationAttempts = attempts;
  const audit = findSolution(fallback.numbers.map((value, id) => ({ value, id })), fallback.target, 6,
    { maxOperations: BALANCE.difficulty[band].operations, nodeBudget: 1000000, timeBudgetMs: 1000 });
  assert.ok(audit.complete);
  assert.equal(audit.steps?.length, BALANCE.difficulty[band].operations);
  const round = createRound(level);
  round.target = fallback.target; round.tiles = fallback.numbers.map((value, id) => ({ value, id })); round.solution = fallback.solution;
  for (const step of fallback.solution) assert.equal(combine(round, step.first, step.operator, step.second).value, step.value);
  assert.equal(round.tiles.find(tile => tile.value === round.target)?.value, fallback.target);
}
const seededRandom = Math.random;
Math.random = () => 0;
for (const [band, level] of [['Easy', 0], ['Medium', 3], ['Hard', 6]] as const) {
  assert.deepEqual(generateRound(level), fallbackRound(band));
}
Math.random = seededRandom;
// Intermediate steps must be recommended even when farther from the target.
const r = createRound();
r.target=347;r.tiles=[{id:0,value:50},{id:1,value:7},{id:2,value:3}];r.nextId=3;
r.solution=[{first:0,second:1,operator:'×',value:350,resultId:3},{first:3,second:2,operator:'-',value:347,resultId:4}];
assert.match(getHint(r),/50 × 7/);
combine(r,0,'×',1);assert.match(getHint(r),/350 - 3/);
undo(r);combine(r,0,'×',1);assert.match(getHint(r),/350 - 3/); // fresh IDs after undo
r.target=200;r.tiles=[{id:0,value:25},{id:1,value:7},{id:2,value:1}];r.nextId=3;r.solution=[];
assert.match(getHint(r),/7 \+ 1|1 \+ 7/); // distance gets worse before reaching 25 × 8
combine(r,1,'+',2);assert.match(getHint(r),/25 × 8|8 × 25/);
r.target=999;r.tiles=[{id:0,value:2},{id:1,value:3}];r.solution=[];
assert.match(getHint(r),/No exact path/);
console.log(JSON.stringify(report,null,2));
console.log('PASS: exact paths, pools, strict difficulty bands, gradual progression/relief, budget fallbacks, intermediate hints, undo IDs, unsolvable-state hint.');
