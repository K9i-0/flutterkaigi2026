import assert from "node:assert/strict";
import test from "node:test";
import {
  BASE_SPEED,
  COLLISION_SPEED_MULTIPLIER,
  FINAL_RUSH_START,
  WANTED_ZONE_END,
  WANTED_ZONE_START,
  beerSpeedMultiplier,
  buildCourse,
  formatTime,
  hasFinished,
  rankFor,
  runSpeed,
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

test("wanted zone contains risky gold beer routes and still leaves a safe lane", () => {
  const wantedRows = buildCourse(42).filter(
    (row) => row.distance >= WANTED_ZONE_START && row.distance <= WANTED_ZONE_END,
  );
  assert.ok(wantedRows.length >= 8);
  assert.ok(wantedRows.every((row) => row.cells.includes("goldBeer")));
  assert.ok(wantedRows.every(
    (row) => row.cells.filter((cell) => cell === "crate" || cell === "barrel").length < 3,
  ));
});

test("beer tiers accelerate the runner and collisions apply a two-second slowdown", () => {
  assert.equal(beerSpeedMultiplier(0), 1);
  assert.equal(beerSpeedMultiplier(9), 1);
  assert.equal(beerSpeedMultiplier(10), 1.08);
  assert.equal(beerSpeedMultiplier(30), 1.24);
  assert.equal(beerSpeedMultiplier(40), 1.32);
  assert.equal(beerSpeedMultiplier(999), 1.32);
  assert.equal(runSpeed(0, false, false, false), BASE_SPEED);
  assert.equal(
    runSpeed(0, true, false, false),
    BASE_SPEED * COLLISION_SPEED_MULTIPLIER,
  );
});

test("goal and time formatting use fixed-distance time attack rules", () => {
  assert.equal(hasFinished(457.99), false);
  assert.equal(hasFinished(458), true);
  assert.equal(formatTime(0), "00:00.00");
  assert.equal(formatTime(39.456), "00:39.46");
  assert.equal(formatTime(65.2), "01:05.20");
});

test("rank thresholds match the serving design contract", () => {
  assert.equal(rankFor(31), "C");
  assert.equal(rankFor(32), "B");
  assert.equal(rankFor(52), "A");
  assert.equal(rankFor(72), "S");
});
