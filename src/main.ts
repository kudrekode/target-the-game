import './ui/style.css';
import { BALANCE } from './game/balance';
import { closest, combine, createRound, remaining, undo, type Round } from './game/gameState';
import { OPERATORS, type Operator } from './game/operations';
import { getHint } from './game/hints';
import { multiplier, scoreRound } from './game/scoring';
import { RewardedAdService } from './services/adService';
import { trackEvent } from './services/analyticsService';
import { loadStats, saveStats } from './services/saveService';
import { feedback, unlockFeedback } from './services/feedbackService';

const app = document.querySelector<HTMLDivElement>('#app')!;
let stats = loadStats();
let round: Round;
let screen: 'home' | 'game' | 'result' | 'stats' = 'home';
let first: number | null = null;
let operator: Operator | null = null;
let streak = 0;
let busy = false;
let ticker: ReturnType<typeof setInterval> | undefined;
let roundVersion = 0;
let noticeTimer: ReturnType<typeof setTimeout> | undefined;
let lastWarningSecond = 11;
let tileSlots = new Map<number, number>();
let previousDistance = Infinity;
const fmt = (n: number) => n.toLocaleString();
const brand = '<div class="wordmark">TARGET<span class="brand-dot"></span></div>';
const homeButton = '<button class="icon-button" data-action="home" aria-label="Home">⌂</button>';

function home() {
  screen = 'home';
  clearInterval(ticker);
  app.innerHTML = `<main class="shell home"><div class="home-emblem" aria-hidden="true"><span>+</span><span>−</span><span>×</span><span>÷</span></div><h1>TAR<span class="title-cross">G</span>ET<span class="title-dot">.</span></h1><div class="home-motif" aria-hidden="true"><span>25</span><span>×</span><span>8</span><strong>200</strong></div><section class="home-actions"><button class="primary" data-action="play">PLAY <span>↗</span></button><button class="secondary" data-action="stats">STATS</button></section></main>`;
  window.scrollTo(0, 0);
}
function start() {
  clearInterval(ticker);
  clearTimeout(noticeTimer);
  roundVersion++;
  round = createRound(streak);
  lastWarningSecond = 11;
  tileSlots = new Map(round.tiles.map((tile, index) => [tile.id, index]));
  previousDistance = Infinity;
  first = null; operator = null; busy = false; screen = 'game';
  trackEvent('round_started', { target: round.target, numbers: round.tiles.map(t => t.value), difficulty: round.difficulty });
  app.innerHTML = `<main class="shell game"><header>${brand}<div class="round-meta"><span class="difficulty ${round.difficulty.toLowerCase()}">${round.difficulty}</span><span>STREAK <b id="streak">${streak}</b></span></div></header><section class="target-panel"><p class="eyebrow">YOUR TARGET</p><h1>${round.target}</h1><div class="target-footer"><span id="closest"></span><span class="score-label">SCORE <b id="score">0</b></span></div></section><section class="timer" aria-label="Time remaining"><div class="timer-caption"><span>TIME LEFT</span><strong id="time">${BALANCE.seconds}<small>s</small></strong></div><div class="timer-track"><div id="timer-fill"></div></div></section><div id="expression" class="expression" aria-live="polite"></div><section id="tiles" class="tiles" aria-label="Number tiles"></section><section class="operators" aria-label="Operators">${OPERATORS.map(op => `<button data-op="${op}" aria-label="${op === '+' ? 'Add' : op === '-' ? 'Subtract' : op === '×' ? 'Multiply' : 'Divide'}">${op === '-' ? '−' : op}</button>`).join('')}</section><p id="notice" class="notice" role="status">Number → operator → number.</p><footer class="tools"><button class="secondary" data-action="undo" id="undo">↶ <span>UNDO <small>1 FREE</small></span></button><button class="secondary" data-action="hint">✧ <span>HINT <small>REWARD</small></span></button></footer></main>`;
  renderBoard();
  window.scrollTo(0, 0);
  tick();
  ticker = setInterval(tick, 100);
}
function renderBoard(newId?: number) {
  const nearest = closest(round);
  document.querySelector('#tiles')!.innerHTML = Array.from({ length: 6 }, (_, slot) => {
    const t = round.tiles.find(tile => tileSlots.get(tile.id) === slot);
    return t ? `<button class="tile ${t.id === first ? 'selected' : ''} ${t.id === newId ? 'new' : ''}" data-tile="${t.id}" aria-pressed="${t.id === first}" aria-label="Number ${t.value}" style="--digits:${String(t.value).length}">${t.value}</button>` : '<div class="tile-slot" aria-hidden="true"></div>';
  }).join('');
  const distance = Math.abs(nearest.value - round.target);
  const targetPanel = document.querySelector<HTMLElement>('.target-panel')!;
  targetPanel.dataset.proximity = distance <= 5 ? 'near' : distance <= 25 ? 'warm' : 'far';
  targetPanel.style.setProperty('--progress', String(1 - Math.min(distance / round.target, 1)));
  if (distance < previousDistance && previousDistance !== Infinity && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
    targetPanel.querySelector('h1')!.animate([{ filter:'brightness(1)' },{ filter:'brightness(1.5)', offset:.35 },{ filter:'brightness(1)' }], { duration:330 });
  }
  previousDistance = distance;
  document.querySelector('#closest')!.textContent = `Closest ${fmt(nearest.value)} · off ${fmt(Math.abs(nearest.value - round.target))}`;
  document.querySelector('#score')!.textContent = fmt(scoreRound(Math.abs(nearest.value - round.target), 0, round.operations, streak + 1).base);
  const undoButton = document.querySelector<HTMLButtonElement>('#undo')!;
  undoButton.disabled = round.history.length === 0 || busy;
  undoButton.innerHTML = `↶ <span>UNDO <small>${round.undoCount === 0 ? '1 FREE' : 'REWARD'}</small></span>`;
  renderSelection();
}
function renderSelection() {
  document.querySelectorAll<HTMLButtonElement>('[data-tile]').forEach(el => {
    const selected = Number(el.dataset.tile) === first;
    el.classList.toggle('selected', selected); el.setAttribute('aria-pressed', String(selected)); el.disabled = busy;
  });
  document.querySelectorAll<HTMLButtonElement>('[data-op]').forEach(el => {
    el.classList.toggle('selected', el.dataset.op === operator);
    el.setAttribute('aria-pressed', String(el.dataset.op === operator)); el.disabled = first === null || busy;
  });
  const value = round.tiles.find(t => t.id === first)?.value;
  document.querySelector('#expression')!.innerHTML = value === undefined ? '<span>BUILD YOUR WAY TO THE TARGET</span>' : `<b>${fmt(value)}</b><b>${operator ?? '?'}</b><span>${operator ? 'Choose a number' : 'Choose an operator'}</span>`;
}
function notice(message: string) {
  clearTimeout(noticeTimer);
  document.querySelector('#notice')!.textContent = message;
  noticeTimer = setTimeout(() => { if (screen === 'game') document.querySelector('#notice')!.textContent = 'Number → operator → number.'; }, 3500);
}
function tick() {
  if (screen !== 'game') return;
  const seconds = remaining(round);
  document.querySelector('#time')!.innerHTML = `${Math.ceil(seconds)}<small>s</small>`;
  document.querySelector<HTMLElement>('#timer-fill')!.style.width = `${seconds / BALANCE.seconds * 100}%`;
  document.querySelector('.timer')!.classList.toggle('urgent', seconds <= 10);
  document.querySelector('.game')!.classList.toggle('time-pressure', seconds <= 10);
  document.querySelector('.timer')!.classList.toggle('critical', seconds <= 3);
  const wholeSeconds = Math.ceil(seconds);
  if (wholeSeconds > 0 && wholeSeconds <= 10 && wholeSeconds < lastWarningSecond) {
    lastWarningSecond = wholeSeconds;
    feedback(wholeSeconds <= 3 ? 'timerCritical' : 'timerWarning');
  }
  if (seconds === 0 && !busy) finish();
}
async function selectTile(id: number) {
  if (busy || screen !== 'game') return;
  if (remaining(round) === 0) { finish(); return; }
  if (first === id) { first = null; operator = null; renderSelection(); return; }
  if (first === null || operator === null) { first = id; renderSelection(); return; }
  const a = round.tiles.find(t => t.id === first)!;
  const b = round.tiles.find(t => t.id === id)!;
  const usedOperator = operator;
  const nodes = [document.querySelector<HTMLElement>(`[data-tile="${first}"]`)!, document.querySelector<HTMLElement>(`[data-tile="${id}"]`)!];
  const result = combine(round, first, operator, id);
  if ('error' in result || result.value === undefined) {
    feedback('invalidImpact');
    trackEvent('invalid_operation', { a: a.value, operator, b: b.value });
    nodes.forEach(el => { el.classList.remove('shake'); void el.offsetWidth; el.classList.add('shake'); });
    notice('error' in result ? result.error : 'Invalid operation'); return;
  }
  feedback('validCombination');
  tileSlots.set(result.tile.id, tileSlots.get(a.id)!);
  trackEvent('operation_used', { a: a.value, operator, b: b.value, result: result.value });
  busy = true;
  const version = roundVersion;
  const secondsAtMove = remaining(round);
  if (result.value === round.target) clearInterval(ticker);
  renderSelection();
  document.querySelector<HTMLButtonElement>('#undo')!.disabled = true;
  document.querySelector('#expression')!.innerHTML = `<b>${a.value} ${usedOperator} ${b.value} = <em>${fmt(result.value)}</em></b>`;
  const rects = nodes.map(el => el.getBoundingClientRect());
  const centerX = (rects[0].left + rects[0].width / 2 + rects[1].left + rects[1].width / 2) / 2;
  const centerY = (rects[0].top + rects[0].height / 2 + rects[1].top + rects[1].height / 2) / 2;
  nodes.forEach(el => el.classList.add('merging'));
  await Promise.allSettled(nodes.map((el, i) => el.animate([
    { transform: 'translate(0, 0) scale(1)', opacity: 1 },
    { transform: 'translate(0, 0) scale(1.06)', opacity: 1, offset: .15 },
    { transform: `translate(${centerX - rects[i].left - rects[i].width / 2}px, ${centerY - rects[i].top - rects[i].height / 2}px) scale(.55)`, opacity: 0 },
  ], { duration: matchMedia('(prefers-reduced-motion: reduce)').matches ? 0 : BALANCE.mergeMs, easing: 'cubic-bezier(.4,0,.2,1)', fill: 'forwards' }).finished));
  if (version !== roundVersion || screen !== 'game') return;
  busy = false; first = result.tile.id; operator = null;
  renderBoard('tile' in result ? result.tile.id : undefined);
  feedback('mergeImpact');
  const newTile = document.querySelector<HTMLElement>('.tile.new');
  if (newTile && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
    const after = newTile.getBoundingClientRect();
    newTile.animate([
      { transform: `translate(${centerX - after.left - after.width / 2}px, ${centerY - after.top - after.height / 2}px) scale(.55)`, opacity: .3 },
      { transform: 'translate(0,0) scale(1.08)', opacity: 1, offset: .75 },
      { transform: 'translate(0,0) scale(1)', opacity: 1 },
    ], { duration: 180, easing: 'ease-out' });
  }
  if (result.value === round.target) {
    busy = true; renderSelection();
    document.querySelector('.target-panel')!.classList.add('target-hit');
    newTile?.classList.add('winning-tile');
    if (!matchMedia('(prefers-reduced-motion: reduce)').matches) await new Promise(resolve => setTimeout(resolve, 180));
    if (version === roundVersion && screen === 'game') finish(secondsAtMove);
  }
  else if (round.tiles.length === 1 || remaining(round) === 0) finish();
  else notice(`${a.value} ${usedOperator} ${b.value} = ${fmt(result.value)}`);
}
function finish(seconds = remaining(round)) {
  if (screen !== 'game') return;
  clearInterval(ticker); clearTimeout(noticeTimer);
  const value = closest(round).value;
  const distance = Math.abs(value - round.target);
  const exact = distance === 0;
  const near = !exact && distance <= 10;
  const resultTitle = exact ? 'EXACT!' : distance === 1 ? 'ONE AWAY!' : near ? 'SO CLOSE!' : 'ROUND OVER';
  feedback(exact ? 'successImpact' : near ? 'closeResult' : 'roundFailure');
  streak = exact ? streak + 1 : 0;
  const score = scoreRound(distance, seconds, round.operations, streak);
  stats.roundsPlayed++; stats.totalScore += score.total;
  stats.bestScore = Math.max(stats.bestScore, score.total);
  stats.exactSolutions += Number(exact); stats.bestStreak = Math.max(stats.bestStreak, streak);
  const saved = saveStats(stats);
  trackEvent(exact ? 'target_exact' : 'round_failed', { target: round.target, closest: value, difference: distance, score: score.total });
  screen = 'result';
  app.innerHTML = `<main class="shell result ${exact ? 'exact' : near ? 'near' : 'miss'}"><header>${brand}${homeButton}</header><section class="result-main"><div class="result-symbol">${exact ? '⊕' : '≈'}</div><p class="eyebrow">${exact ? 'RIGHT ON THE NUMBER' : seconds === 0 ? 'TIME’S UP' : 'ALL TILES COMBINED'}</p><h1>${resultTitle}</h1><div class="result-values"><div><span>TARGET</span><strong>${round.target}</strong></div><div><span>${exact ? 'YOUR RESULT' : 'CLOSEST'}</span><strong>${fmt(value)}</strong></div></div><div class="difference">${exact ? '<span class="perfect-mark">✓ PERFECT MATCH</span>' : `<span>OFF BY</span><b>${fmt(distance)}</b>`}</div><div class="earned"><span>ROUND SCORE</span><strong>+${fmt(score.total)}</strong></div><div class="score-breakdown"><span>Closeness <b>${score.base}</b></span><span>Time bonus <b>+${score.time}</b></span>${score.efficiency ? `<span>Efficiency <b>+${score.efficiency}</b></span>` : ''}${score.factor > 1 ? `<span>Streak multiplier <b>×${score.factor.toFixed(1)}</b></span>` : ''}</div><div class="result-details"><span><b>${Math.floor(seconds)}s</b> REMAINING</span><span><b>${round.operations}</b> OPERATIONS</span><span class="streak-result"><b>${streak}${streak > 1 ? `<small> ×${multiplier(streak).toFixed(1)}</small>` : ''}</b> STREAK</span></div></section><button class="primary" data-action="play">NEXT ROUND <span>↗</span></button>${saved ? '' : '<p class="notice">Stats could not be saved in this browser.</p>'}</main>`;
  window.scrollTo(0, 0);
  if (exact) {
    const burst = document.createElement('div');
    burst.className = 'exact-burst'; burst.setAttribute('aria-hidden', 'true');
    burst.innerHTML = Array.from({ length: 16 }, (_, i) => `<i style="--angle:${i * 22.5}deg;--delay:${i % 3 * 30}ms"></i>`).join('');
    document.querySelector('.result-symbol')!.append(burst);
  }
}
function showStats() {
  screen = 'stats';
  app.innerHTML = `<main class="shell stats"><header>${brand}${homeButton}</header><section><p class="eyebrow">EVERY ROUND COUNTS</p><h1>Your numbers.</h1><div class="stat-total"><span>TOTAL SCORE</span><strong>${fmt(stats.totalScore)}</strong></div><div class="stat-grid">${[['Rounds played', stats.roundsPlayed], ['Exact solutions', stats.exactSolutions], ['Best streak', stats.bestStreak], ['Best score', stats.bestScore]].map(([label, value]) => `<div><strong>${fmt(Number(value))}</strong><span>${label}</span></div>`).join('')}</div><p class="footnote">SAVED ON THIS DEVICE</p></section><button class="primary" data-action="play">PLAY <span>↗</span></button></main>`;
}
app.addEventListener('click', event => {
  const button = (event.target as HTMLElement).closest<HTMLButtonElement>('button');
  if (!button || button.disabled) return;
  unlockFeedback();
  if (button.dataset.tile !== undefined) feedback('tileSelected');
  if (button.dataset.op) feedback('operatorSelected');
  const action = button.dataset.action;
  if (action === 'home') { if (screen === 'game') return; home(); }
  if (action === 'play') start();
  if (action === 'stats') showStats();
  if (screen !== 'game' || busy) return;
  if (remaining(round) === 0) { finish(); return; }
  if (button.dataset.tile !== undefined) void selectTile(Number(button.dataset.tile));
  if (button.dataset.op && first !== null) { operator = button.dataset.op as Operator; renderSelection(); }
  if (action === 'hint') RewardedAdService.showRewardedAd(() => { trackEvent('hint_used'); feedback('hint'); notice(getHint(round)); });
  if (action === 'undo') {
    const restore = () => { if (undo(round)) { first = null; operator = null; feedback('undo'); trackEvent('undo_used', { rewarded: round.undoCount > 1 }); renderBoard(); notice('Last combination undone.'); } };
    if (round.undoCount === 0) restore(); else RewardedAdService.showRewardedAd(restore);
  }
});
document.addEventListener('visibilitychange', () => { if (!document.hidden) tick(); });
home();
