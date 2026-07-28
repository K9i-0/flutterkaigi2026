import type { CourseCell, CourseRow, Rank } from "./types.js";

export const RUN_DURATION = 45;
export const LANE_X = [-2.35, 0, 2.35] as const;
export const START_SPEED = 8.2;
export const END_SPEED = 12;
export const FINAL_RUSH_START = 408;
export const FINISH_DISTANCE = 458;

const REGULAR_PATTERNS: ReadonlyArray<
  ReadonlyArray<readonly [CourseCell, CourseCell, CourseCell]>
> = [
  [
    ["beer", "beer", "crate"],
    ["crate", "beer", "beer"],
    ["beer", null, "beer"],
  ],
  [
    ["beer", "barrel", "beer"],
    ["beer", "crate", null],
    [null, "beer", "beer"],
  ],
  [
    ["crate", "beer", "crate"],
    ["beer", "beer", null],
    ["beer", null, "beer"],
  ],
  [
    ["beer", "crate", "beer"],
    ["barrel", "beer", null],
    ["beer", "beer", "crate"],
  ],
  [
    ["beer", "beer", "beer"],
    ["crate", null, "beer"],
    ["beer", "crate", "beer"],
  ],
] as const;

function mulberry32(seed: number) {
  let value = seed >>> 0;
  return () => {
    value += 0x6d2b79f5;
    let result = value;
    result = Math.imul(result ^ (result >>> 15), result | 1);
    result ^= result + Math.imul(result ^ (result >>> 7), result | 61);
    return ((result ^ (result >>> 14)) >>> 0) / 4294967296;
  };
}

export function buildCourse(seed: number): CourseRow[] {
  const rows: CourseRow[] = [
    { distance: 14, cells: [null, "beer", null] },
    { distance: 21, cells: ["beer", null, null] },
    { distance: 28, cells: [null, null, "beer"] },
    { distance: 35, cells: ["beer", "beer", "beer"] },
  ];
  const random = mulberry32(seed);
  let distance = 45;

  while (distance < FINAL_RUSH_START - 10) {
    const pattern = REGULAR_PATTERNS[Math.floor(random() * REGULAR_PATTERNS.length)];
    for (const cells of pattern) {
      rows.push({ distance, cells });
      distance += 5.2 + random() * 1.1;
    }
    distance += 1.7 + random() * 1.8;
  }

  for (let rushDistance = FINAL_RUSH_START; rushDistance <= FINISH_DISTANCE - 5; rushDistance += 4.2) {
    rows.push({
      distance: rushDistance,
      cells: rushDistance % 8.4 < 2 ? ["beer", "beer", "beer"] : ["beer", null, "beer"],
    });
  }

  return rows;
}

export function speedAt(elapsed: number): number {
  const progress = Math.min(1, Math.max(0, elapsed / RUN_DURATION));
  return START_SPEED + (END_SPEED - START_SPEED) * progress;
}

export function rankFor(served: number): Rank {
  if (served >= 72) return "S";
  if (served >= 52) return "A";
  if (served >= 32) return "B";
  return "C";
}

export function rankLabel(rank: Rank): string {
  switch (rank) {
    case "S":
      return "大変驚いております";
    case "A":
      return "立ち飲み処 大繁盛";
    case "B":
      return "常連で満席";
    case "C":
      return "ちょい飲み";
  }
}
