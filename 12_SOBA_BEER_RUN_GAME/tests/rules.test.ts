import assert from "node:assert/strict";
import test from "node:test";
import {
  BASE_SPEED,
  COLLISION_SPEED_MULTIPLIER,
  FINAL_RUSH_START,
  MAX_BEER_SPEED_MULTIPLIER,
  ROUTE_GATE_DISTANCES,
  ROUTE_REWARD_SPACING,
  WANTED_ZONE_START,
  beerSpeedMultiplier,
  buildCourse,
  formatTime,
  hasFinished,
  isRouteGate,
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

test("each decision gate telegraphs one correct lane with a long beer stream", () => {
  const course = buildCourse(42);
  const gates = course.filter((row) => isRouteGate(row.role));
  assert.equal(gates.length, ROUTE_GATE_DISTANCES.length);

  gates.forEach((gate, index) => {
    assert.equal(gate.distance, ROUTE_GATE_DISTANCES[index]);
    assert.equal(gate.cells.filter((cell) => cell === "crate" || cell === "barrel").length, 2);
    assert.notEqual(gate.safeLane, undefined);
    const safeIndex = (gate.safeLane ?? 0) + 1;
    assert.ok(gate.cells[safeIndex] === "beer" || gate.cells[safeIndex] === "goldBeer");

    const streams = course.filter(
      (row) => row.routeId === gate.routeId && (row.role === "stream" || row.role === "wantedStream"),
    );
    assert.ok(streams.length >= 8);
    assert.ok(streams.every((row) => row.safeLane === gate.safeLane));
    assert.ok(streams.every((row) => row.cells[safeIndex] === "beer" || row.cells[safeIndex] === "goldBeer"));
    assert.ok(streams.every(
      (row) => row.cells.filter((cell) => cell === "beer" || cell === "goldBeer").length === 1,
    ));
  });
});

test("regular beer streams feel rapid without increasing decision frequency", () => {
  const course = buildCourse(99);
  const gates = course.filter((row) => row.role === "gate");
  for (let index = 1; index < gates.length; index += 1) {
    assert.ok(gates[index].distance - gates[index - 1].distance >= 38);
  }

  const firstRoute = course.filter((row) => row.routeId === 0 && row.role === "stream");
  for (let index = 1; index < firstRoute.length; index += 1) {
    assert.ok(
      Math.abs(firstRoute[index].distance - firstRoute[index - 1].distance - ROUTE_REWARD_SPACING)
        < 0.001,
    );
  }

  const maxSpeed = BASE_SPEED * MAX_BEER_SPEED_MULTIPLIER;
  const fastestDecisionInterval = 38 / maxSpeed;
  const fastestPickupInterval = ROUTE_REWARD_SPACING / maxSpeed;
  assert.ok(fastestDecisionInterval >= 2.5);
  assert.ok(fastestPickupInterval >= 0.14 && fastestPickupInterval <= 0.2);
});

test("wanted route is one sustained lane with several gold beers", () => {
  const course = buildCourse(7);
  const gate = course.find((row) => row.distance === WANTED_ZONE_START);
  assert.equal(gate?.role, "wantedGate");
  const stream = course.filter((row) => row.role === "wantedStream");
  assert.ok(stream.length >= 12);
  assert.ok(stream.every((row) => row.safeLane === gate?.safeLane));
  assert.ok(stream.filter((row) => row.cells.includes("goldBeer")).length >= 4);
});

test("final rush is a dense three-lane beer celebration", () => {
  const rushRows = buildCourse(42).filter((row) => row.distance >= FINAL_RUSH_START);
  assert.ok(rushRows.length >= 20);
  for (const row of rushRows) {
    assert.deepEqual(row.cells, ["beer", "beer", "beer"]);
  }
});

test("beer tiers accelerate the faster runner and collisions still slow it down", () => {
  assert.equal(BASE_SPEED, 11.8);
  assert.equal(beerSpeedMultiplier(0), 1);
  assert.equal(beerSpeedMultiplier(9), 1);
  assert.equal(beerSpeedMultiplier(10), 1.08);
  assert.equal(beerSpeedMultiplier(30), 1.24);
  assert.equal(beerSpeedMultiplier(40), 1.28);
  assert.equal(beerSpeedMultiplier(999), 1.28);
  assert.equal(runSpeed(0, false, false, false), BASE_SPEED);
  assert.equal(
    runSpeed(0, true, false, false),
    BASE_SPEED * COLLISION_SPEED_MULTIPLIER,
  );
});

test("goal, time, and rank rules remain stable", () => {
  assert.equal(hasFinished(457.99), false);
  assert.equal(hasFinished(458), true);
  assert.equal(formatTime(39.456), "00:39.46");
  assert.equal(rankFor(31), "C");
  assert.equal(rankFor(32), "B");
  assert.equal(rankFor(52), "A");
  assert.equal(rankFor(72), "S");
});
