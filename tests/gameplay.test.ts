import assert from 'node:assert/strict';
import { generateRound, difficultyForStreak } from '../src/game/generator';
import { createRound, combine, undo } from '../src/game/gameState';
import { getHint } from '../src/game/hints';
import { findSolution } from '../src/game/solver';
import { BALANCE } from '../src/game/balance';

// Deterministic sample, independently replaying every certified solution.
let seed = 82719;
Math.random = () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; };
assert.equal(difficultyForStreak(0), 'Easy');
assert.equal(difficultyForStreak(2), 'Medium');
assert.equal(difficultyForStreak(5), 'Hard');
const report = [];
for (const [band, streak] of [['Easy', 0], ['Medium', 2], ['Hard', 5]] as const) {
  let exact = 0, shorter = 0, checked = 0, bandFallbacks = 0;
  const times: number[] = [], depths: number[] = [];
  for (let i = 0; i < 1000; i++) {
    const before = performance.now();
    const generated = generateRound(streak);
    times.push(performance.now() - before);
    assert.equal(generated.numbers.length, 6);
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
    if (generated.difficulty !== band) bandFallbacks++;
    if (i < 100 && band !== 'Easy') {
      const result = findSolution(generated.numbers.map((value,id)=>({value,id})), generated.target, 6, {maxOperations: band === 'Hard' ? 3 : 2, nodeBudget: 1000000, timeBudgetMs: 1000});
      if (result.complete) { checked++; if(result.steps) shorter++; }
    }
  }
  times.sort((a,b)=>a-b);
  report.push({ band, rounds:1000, exact, exactRate:exact / 10 + '%', meanMs:+(times.reduce((a,b)=>a+b,0)/1000).toFixed(2), p95Ms:+times[950].toFixed(2), maxMs:+times[999].toFixed(2), meanSolutionOperations:+(depths.reduce((a,b)=>a+b,0)/1000).toFixed(2), shorter, shortcutSample:checked, bandFallbacks });
  assert.equal(exact,1000);
}
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
console.log('PASS: certified exact paths, legal arithmetic, target/pool constraints, difficulty progression, intermediate hints, fresh IDs after undo, unsolvable-state hint.');
