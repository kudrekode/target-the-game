import { BALANCE } from '../game/balance';
type Sound = 'tap' | 'merge' | 'invalid' | 'exact' | 'warning' | 'end';
let context: AudioContext | undefined;
export function unlockSound() {
  try {
    context ??= new AudioContext();
    if (context.state === 'suspended') void context.resume().catch(() => {});
  } catch { /* Audio is optional when unsupported or blocked. */ }
}
export function playSound(sound: Sound) {
  if (!context || context.state !== 'running' || document.hidden) return;
  const patterns: Record<Sound, number[]> = { tap: [620], merge: [330, 660], invalid: [150, 110], exact: [523, 659, 784, 1047], warning: [440], end: [294, 220] };
  const notes = patterns[sound];
  const start = context.currentTime;
  notes.forEach((frequency, i) => {
    const oscillator = context!.createOscillator();
    const gain = context!.createGain();
    const at = start + i * (sound === 'exact' ? .085 : .045);
    const duration = sound === 'exact' ? .24 : sound === 'warning' ? .045 : .08;
    oscillator.type = 'sine'; oscillator.frequency.value = frequency;
    gain.gain.setValueAtTime(0, at);
    gain.gain.linearRampToValueAtTime(BALANCE.soundVolume * (sound === 'warning' ? .45 : 1), at + .008);
    gain.gain.exponentialRampToValueAtTime(.0001, at + duration);
    oscillator.connect(gain); gain.connect(context!.destination);
    oscillator.start(at); oscillator.stop(at + duration + .01);
    oscillator.onended = () => { oscillator.disconnect(); gain.disconnect(); };
  });
}
