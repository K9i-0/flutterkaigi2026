import type { CourseCell, CourseRole, CourseRow, Lane, Rank } from "./types.js";

export const LANE_X = [-2.35, 0, 2.35] as const;
export const BASE_SPEED = 11.8;
export const BEERS_PER_SPEED_UP = 10;
export const SPEED_STEP = 0.08;
export const MAX_BEER_SPEED_MULTIPLIER = 1.28;
export const COLLISION_SPEED_MULTIPLIER = 0.72;
export const COLLISION_DURATION = 2;
export const SUPPORT_SPEED_MULTIPLIER = 1.18;
export const NEAR_MISS_SPEED_MULTIPLIER = 1.1;
export const FINAL_RUSH_START = 408;
export const FINISH_DISTANCE = 458;
export const WANTED_ZONE_START = 318;
export const WANTED_ZONE_END = 365;
export const ROUTE_REWARD_SPACING = 2.25;
export const ROUTE_GATE_DISTANCES = [50, 88, 126, 164, 202, 240, 278, 318, 374] as const;

const HINT_OFFSETS = [-13, -9, -5] as const;
const REGULAR_REWARD_COUNT = 8;

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

function laneCells(lane: Lane, cell: Exclude<CourseCell, null>): [CourseCell, CourseCell, CourseCell] {
  const cells: [CourseCell, CourseCell, CourseCell] = [null, null, null];
  cells[lane + 1] = cell;
  return cells;
}

function gateCells(
  lane: Lane,
  reward: "beer" | "goldBeer",
  variant: number,
): [CourseCell, CourseCell, CourseCell] {
  const cells: [CourseCell, CourseCell, CourseCell] = ["crate", "barrel", "crate"];
  cells[lane + 1] = reward;
  const otherLane = (lane + 2 + (variant % 2)) % 3;
  if (otherLane !== lane + 1) cells[otherLane] = variant % 2 === 0 ? "barrel" : "crate";
  return cells;
}

function addRoute(
  rows: CourseRow[],
  routeId: number,
  gateDistance: number,
  safeLane: Lane,
  role: "gate" | "wantedGate",
): void {
  const hintCell = role === "wantedGate" ? "goldBeer" : "beer";
  for (const offset of HINT_OFFSETS) {
    rows.push({
      distance: gateDistance + offset,
      cells: laneCells(safeLane, hintCell),
      routeId,
      safeLane,
      role: "hint",
    });
  }

  rows.push({
    distance: gateDistance,
    cells: gateCells(safeLane, hintCell, routeId),
    routeId,
    safeLane,
    role,
  });

  if (role === "wantedGate") {
    for (let index = 1; index <= 12; index += 1) {
      const reward = index % 3 === 0 ? "goldBeer" : "beer";
      rows.push({
        distance: gateDistance + index * 3,
        cells: laneCells(safeLane, reward),
        routeId,
        safeLane,
        role: "wantedStream",
      });
    }
    return;
  }

  for (let index = 1; index <= REGULAR_REWARD_COUNT; index += 1) {
    rows.push({
      distance: gateDistance + index * ROUTE_REWARD_SPACING,
      cells: laneCells(safeLane, "beer"),
      routeId,
      safeLane,
      role: "stream",
    });
  }
}

export function buildCourse(seed: number): CourseRow[] {
  const rows: CourseRow[] = [
    { distance: 14, cells: [null, "beer", null], role: "tutorial" },
    { distance: 20, cells: [null, "beer", null], role: "tutorial" },
    { distance: 26, cells: ["beer", "beer", "beer"], role: "tutorial" },
  ];
  const random = mulberry32(seed);
  let previousLane: Lane = 0;

  ROUTE_GATE_DISTANCES.forEach((gateDistance, routeId) => {
    let lane = (Math.floor(random() * 3) - 1) as Lane;
    if (routeId === 0 && lane === previousLane) lane = 1;
    const isWanted = gateDistance === WANTED_ZONE_START;
    addRoute(rows, routeId, gateDistance, lane, isWanted ? "wantedGate" : "gate");
    previousLane = lane;
  });

  for (
    let rushDistance = FINAL_RUSH_START;
    rushDistance <= FINISH_DISTANCE - 3;
    rushDistance += 2.2
  ) {
    rows.push({
      distance: rushDistance,
      cells: ["beer", "beer", "beer"],
      role: "rush",
    });
  }

  return rows.sort((a, b) => a.distance - b.distance);
}

export function isRouteGate(role: CourseRole | undefined): boolean {
  return role === "gate" || role === "wantedGate";
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
