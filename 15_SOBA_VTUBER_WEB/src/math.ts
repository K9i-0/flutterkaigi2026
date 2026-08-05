export const clamp = (value: number, min = -1, max = 1): number =>
  Math.min(max, Math.max(min, value));

export const lerp = (from: number, to: number, amount: number): number =>
  from + (to - from) * amount;

export const smoothingFactor = (deltaMs: number, halfLifeMs: number): number => {
  if (halfLifeMs <= 0) return 1;
  return 1 - Math.pow(0.5, Math.max(0, deltaMs) / halfLifeMs);
};

export const radians = (degrees: number): number => (degrees * Math.PI) / 180;

export const mapRange = (
  value: number,
  inputMin: number,
  inputMax: number,
  outputMin: number,
  outputMax: number,
): number => {
  if (inputMin === inputMax) return outputMin;
  const ratio = (value - inputMin) / (inputMax - inputMin);
  return outputMin + ratio * (outputMax - outputMin);
};
