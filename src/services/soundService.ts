import { BALANCE } from '../game/balance';
export type Sound = 'tile' | 'operator' | 'combine' | 'merge' | 'invalid' | 'hint' | 'undo' | 'warning' | 'critical' | 'exact' | 'close' | 'end';
let context: AudioContext | undefined;
let lastSoundAt = -Infinity;
export function unlockSound() {
  try { context ??= new AudioContext(); if (context.state === 'suspended') void context.resume().catch(() => {}); } catch { /* Optional audio. */ }
}
export function playSound(sound: Sound) {
  if (!context || context.state !== 'running' || document.hidden) return;
  const now = context.currentTime;
  if ((sound === 'tile' || sound === 'operator') && now - lastSoundAt < .035) return;
  lastSoundAt = now;
  const patterns: Record<Sound, number[]> = {
    tile:[740], operator:[490], combine:[280,420], merge:[180,720], invalid:[130,100], hint:[660,880], undo:[520,390], warning:[580], critical:[680], exact:[523,659,784,1047], close:[523,659,784], end:[260,220],
  };
  patterns[sound].forEach((frequency,i) => {
    const oscillator=context!.createOscillator(), gain=context!.createGain();
    const bright=sound==='exact'||sound==='close';
    const tick=sound==='warning'||sound==='critical';
    const at=now+i*(bright ? .065 : .032);
    const duration=bright ? .2 : tick ? .025 : sound === 'merge' ? .09 : .055;
    oscillator.type=sound==='merge'&&i===0?'triangle':'sine';
    oscillator.frequency.setValueAtTime(frequency,at);
    if (sound==='merge'&&i===0) oscillator.frequency.exponentialRampToValueAtTime(90,at+duration);
    const volume=BALANCE.soundVolume*(tick ? .3 : sound === 'combine' ? .35 : .75);
    gain.gain.setValueAtTime(0,at);gain.gain.linearRampToValueAtTime(volume,at+.004);gain.gain.exponentialRampToValueAtTime(.0001,at+duration);
    oscillator.connect(gain);gain.connect(context!.destination);oscillator.start(at);oscillator.stop(at+duration+.01);
    oscillator.onended=()=>{oscillator.disconnect();gain.disconnect();};
  });
}
