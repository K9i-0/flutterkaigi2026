import assert from "node:assert/strict";
import test from "node:test";
import {
  FINAL_RUSH_START,
  RUN_DURATION,
  buildCourse,
  rankFor,
  speedAt,
} from "../src/rules.js";

test("course generation is deterministic and always leaves a safe lane", () => {
  const first = buildCourse(141);
  const second = buildCourse(141);
  assert.deepEqual(first, second);

  for (const row of first) {
    const blockers = row.cells.filter((cell) => cell === "crate" || cell === "barrel");
    assert.ok(blockers.length < 3, `all lanes blocked at ${row.distance}`);
  }
});

test("final rush contains beer and no obstacles", () => {
  const rushRows = buildCourse(42).filter((row) => row.distance >= FINAL_RUSH_START);
  assert.ok(rushRows.length >= 8);
  for (const row of rushRows) {
    assert.ok(row.cells.includes("beer"));
    assert.equal(row.cells.some((cell) => cell === "crate" || cell === "barrel"), false);
  }
});

test("speed and rank thresholds match the design contract", () => {
  assert.ok(speedAt(0) < speedAt(RUN_DURATION));
  assert.equal(rankFor(31), "C");
  assert.equal(rankFor(32), "B");
  assert.equal(rankFor(52), "A");
  assert.equal(rankFor(72), "S");
});
