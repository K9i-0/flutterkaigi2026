import { clamp } from "./math.js";

export const BLINK_START_SCORE = 0.88;
export const BLINK_CLOSED_SCORE = 0.98;

/** Keep naturally narrow eyes open until MediaPipe is highly confident. */
export const blinkScoreToEyeOpen = (
  blinkScore: number,
  startScore = BLINK_START_SCORE,
  closedScore = BLINK_CLOSED_SCORE,
): number => {
  if (closedScore <= startScore) return blinkScore >= closedScore ? 0 : 1;
  const progress = clamp((blinkScore - startScore) / (closedScore - startScore), 0, 1);
  const smoothClosure = progress * progress * (3 - 2 * progress);
  return 1 - smoothClosure;
};
