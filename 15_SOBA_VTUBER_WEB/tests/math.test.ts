import assert from "node:assert/strict";
import test from "node:test";
import { clamp, mapRange, smoothingFactor } from "../src/math.js";
import {
  PoseCalibrator,
  PoseSmoother,
  cheersMotionAt,
  demoPoseAt,
  neutralPose,
} from "../src/pose.js";
import { blinkScoreToEyeOpen } from "../src/tracking-math.js";

test("clamp and mapRange constrain rig inputs", () => {
  assert.equal(clamp(4), 1);
  assert.equal(clamp(-4), -1);
  assert.equal(mapRange(0.5, 0, 1, 0, 10), 5);
});

test("half-life smoothing reaches halfway after one half-life", () => {
  assert.ok(Math.abs(smoothingFactor(100, 100) - 0.5) < 0.00001);
  const smoother = new PoseSmoother(100);
  const result = smoother.update({ ...neutralPose(), yaw: 1, presence: 1 }, 100);
  assert.ok(Math.abs(result.yaw - 0.5) < 0.00001);
});

test("calibration removes neutral head offsets without changing expressions", () => {
  const calibrator = new PoseCalibrator();
  calibrator.calibrate({ ...neutralPose(), yaw: 0.25, pitch: -0.2 });
  const result = calibrator.apply({
    ...neutralPose(),
    yaw: 0.25,
    pitch: -0.2,
    eyeOpenL: 0.3,
    mouthOpen: 0.8,
  });
  assert.equal(result.yaw, 0);
  assert.equal(result.pitch, 0);
  assert.equal(result.eyeOpenL, 0.3);
  assert.equal(result.mouthOpen, 0.8);
});

test("demo pose is bounded and always present", () => {
  for (let index = 0; index < 200; index += 1) {
    const pose = demoPoseAt(index / 20);
    for (const value of Object.values(pose) as number[]) assert.ok(value >= -1 && value <= 1);
    assert.equal(pose.presence, 1);
  }
});

test("blink requires a high confidence score", () => {
  assert.equal(blinkScoreToEyeOpen(0.7), 1);
  assert.equal(blinkScoreToEyeOpen(0.88), 1);
  assert.ok(blinkScoreToEyeOpen(0.9) > 0.85);
  assert.ok(blinkScoreToEyeOpen(0.95) < 0.3);
  assert.equal(blinkScoreToEyeOpen(0.98), 0);
  assert.equal(blinkScoreToEyeOpen(1), 0);
});

test("cheers raises, clinks, and returns the mug", () => {
  assert.equal(cheersMotionAt(-1).active, false);
  assert.ok(cheersMotionAt(500).lift > 0.9);
  assert.ok(Math.abs(cheersMotionAt(860).clink) > 0.01);
  assert.ok(cheersMotionAt(1700).lift < 0.7);
  assert.equal(cheersMotionAt(2000).active, false);
});
