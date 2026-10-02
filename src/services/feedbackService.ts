import { playSound, unlockSound, type Sound } from './soundService';
export type FeedbackEvent = 'tileSelected' | 'operatorSelected' | 'validCombination' | 'mergeImpact' | 'invalidImpact' | 'hint' | 'undo' | 'timerWarning' | 'timerCritical' | 'successImpact' | 'closeResult' | 'roundFailure';
export type HapticEvent = 'lightTap' | 'mergeImpact' | 'invalidImpact' | 'successImpact';
let hapticHandler: ((event: HapticEvent) => void) | undefined;
// Native clients can install their haptic bridge; browsers intentionally do nothing.
export function setHapticHandler(handler?: (event: HapticEvent) => void) { hapticHandler = handler; }
export function unlockFeedback() { unlockSound(); }
export function feedback(event: FeedbackEvent) {
  const sound: Record<FeedbackEvent, Sound> = {
    tileSelected: 'tile', operatorSelected: 'operator', validCombination: 'combine', mergeImpact: 'merge', invalidImpact: 'invalid', hint: 'hint', undo: 'undo', timerWarning: 'warning', timerCritical: 'critical', successImpact: 'exact', closeResult: 'close', roundFailure: 'end',
  };
  playSound(sound[event]);
  const haptic: Partial<Record<FeedbackEvent, HapticEvent>> = { tileSelected:'lightTap', operatorSelected:'lightTap', mergeImpact:'mergeImpact', invalidImpact:'invalidImpact', successImpact:'successImpact', closeResult:'lightTap', undo:'lightTap', hint:'lightTap' };
  if (haptic[event]) hapticHandler?.(haptic[event]!);
}
