import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/lab/simulation.dart';

void main() {
  test('sprint stops before a thin wall without tunnelling', () {
    final s = LabSimulation()..reset(LabMode.movement);
    for (var i = 0; i < 100; i++) {
      s.move(0, 1, .1, sprint: true);
    }
    expect(s.z, lessThanOrEqualTo(-1.64 + 1e-8));
    expect(s.z, greaterThan(-1.70));
    expect(s.collisionFrames, greaterThan(0));
    expect(arenaBlocks.any((b) => s.overlaps(s.x, s.z, b)), false);
  });
  test('diagonal input does not increase speed', () {
    final a = LabSimulation()..reset(LabMode.movement),
        b = LabSimulation()..reset(LabMode.movement);
    a.move(1, 0, .1);
    b.move(1, 1, .1);
    expect(math.sqrt(b.x * b.x + math.pow(b.z + 5, 2)), closeTo(a.x, 1e-9));
  });
  test('slides along wall then clears its edge', () {
    final s = LabSimulation()..reset(LabMode.movement);
    for (var i = 0; i < 100; i++) {
      s.move(0, 1, 1 / 60, sprint: true);
    }
    final stopped = s.z;
    for (var i = 0; i < 20; i++) {
      s.move(1, 1, 1 / 60);
    }
    expect(s.x, greaterThan(.5));
    expect(s.z, closeTo(stopped, .03));
    for (var i = 0; i < 60; i++) {
      s.move(1, 1, 1 / 60);
    }
    expect(s.z, greaterThan(stopped));
    expect(arenaBlocks.any((b) => s.overlaps(s.x, s.z, b)), false);
  });
  test('camera boom stops at wall and stays full length in free space', () {
    final s = LabSimulation()..reset(LabMode.movement);
    expect(s.cameraFraction(0, 1, -3, 0, 1, 2), lessThan(.4));
    expect(s.cameraFraction(0, 1, -3, 0, 1, -6), 1);
  });
  test('scene reset clears position and collision history', () {
    final s = LabSimulation()..reset(LabMode.movement);
    s.move(1, 0, .1);
    s.reset(LabMode.model);
    expect(s.x, 0);
    expect(s.z, 0);
    expect(s.distanceTravelled, 0);
  });
  test('empty timings stay unknown, nonfinite samples are rejected', () {
    final f = FrameSamples();
    expect(f.uiP95, isNull);
    f.add(double.nan, 1);
    expect(f.count, 0);
    for (var i = 1; i <= 100; i++) {
      f.add(i.toDouble(), i / 2);
    }
    expect(f.uiP95, 95);
    expect(f.rasterP95, 47.5);
    f.reset();
    expect(f.count, 0);
    expect(f.uiP95, isNull);
  });
}
