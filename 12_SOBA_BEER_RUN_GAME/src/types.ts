export type Lane = -1 | 0 | 1;
export type CourseCell = "beer" | "crate" | "barrel" | null;
export type Phase = "title" | "playing" | "paused" | "result";
export type Rank = "C" | "B" | "A" | "S";

export interface CourseRow {
  distance: number;
  cells: readonly [CourseCell, CourseCell, CourseCell];
}

export interface RunResult {
  served: number;
  bestChain: number;
  juggleCount: number;
  hits: number;
  rank: Rank;
  newBest: boolean;
}
