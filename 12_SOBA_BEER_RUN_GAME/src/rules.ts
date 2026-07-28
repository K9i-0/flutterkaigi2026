import type { CourseCell, CourseRow, Rank } from "./types.js";

export const LANE_X = [-2.35, 0, 2.35] as const;
export const BASE_SPEED = 9.2;
export const BEERS_PER_SPEED_UP = 10;
export const SPEED_STEP = 0.08;
export const MAX_BEER_SPEED_MULTIPLIER = 1.4;
export const COLLISION_SPEED_MULTIPLIER = 0.72;
export const COLLISION_DURATION = 2;
export const SUPPORT_SPEED_MULTIPLIER = 1.18;
export const NEAR_MISS_SPEED_MULTIPLIER = 1.1;
export const FEVER_DURATION = 4;
export const FINAL_RUSH_START = 408;
export const FINISH_DISTANCE = 458;
export const WANTED_ZONE_START = 318;
export const WANTED_ZONE_END = 365;

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
  let rows: CourseRow[] = [
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

  rows = rows.filter(
    (row) => row.distance < WANTED_ZONE_START - 7 || row.distance > WANTED_ZONE_END + 5,
  );

  const wantedPatterns: ReadonlyArray<readonly [CourseCell, CourseCell, CourseCell]> = [
    ["goldBeer", "crate", "beer"],
    ["crate", "beer", "goldBeer"],
    ["goldBeer", "barrel", null],
    ["beer", "crate", "goldBeer"],
    ["barrel", "goldBeer", "beer"],
    ["goldBeer", null, "crate"],
    ["crate", "beer", "goldBeer"],
    ["goldBeer", "barrel", "beer"],
    [null, "goldBeer", "crate"],
  ];
  wantedPatterns.forEach((cells, index) => {
    rows.push({ distance: WANTED_ZONE_START + index * 5.2, cells });
  });

  for (let rushDistance = FINAL_RUSH_START; rushDistance <= FINISH_DISTANCE - 5; rushDistance += 4.2) {
    rows.push({
      distance: rushDistance,
      cells: rushDistance % 8.4 < 2 ? ["beer", "beer", "beer"] : ["beer", null, "beer"],
    });
  }

  return rows.sort((a, b) => a.distance - b.distance);
}

export function beerSpeedMultiplier(collectedBeers: number): number {
  const tiers = Math.floor(Math.max(0, collectedBeers) / BEERS_PER_SPEED_UP);
  return Math.min(MAX_BEER_SPEED_MULTIPLIER, 1 + tiers * SPEED_STEP);
}

export function runSpeed(
  collectedBeers: number,
  isSlowed: boolean,
  hasSupportBoost: boolean,
  hasNearMissBoost: boolean,
): number {
  const beerMultiplier = beerSpeedMultiplier(collectedBeers);
  const slowdown = isSlowed ? COLLISION_SPEED_MULTIPLIER : 1;
  const support = hasSupportBoost ? SUPPORT_SPEED_MULTIPLIER : 1;
  const nearMiss = hasNearMissBoost ? NEAR_MISS_SPEED_MULTIPLIER : 1;
  return BASE_SPEED * beerMultiplier * slowdown * support * nearMiss;
}

export function hasFinished(distance: number): boolean {
  return distance >= FINISH_DISTANCE;
}

export function formatTime(seconds: number): string {
  const safeSeconds = Math.max(0, seconds);
  const minutes = Math.floor(safeSeconds / 60);
  const remainder = safeSeconds - minutes * 60;
  return `${String(minutes).padStart(2, "0")}:${remainder.toFixed(2).padStart(5, "0")}`;
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
