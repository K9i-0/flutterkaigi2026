import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_beer_rain/catch_game.dart';
import 'package:sobaya_beer_rain/tilt_input.dart';

void main() {
  test(
    'lane ignores depth input and keeps controls stable while looking around',
    () {
      final g = CatchGame()..lane = true;
      g.start();
      expect(g.drops.every((d) => d.z == 0), true);
      expect(g.drops.any((d) => d.facing < 0), true);
      expect(g.drops.any((d) => d.facing > 0), true);
      for (var i = 0; i < 20; i++) {
        g.rotate(1);
      }
      expect(g.targetYaw, closeTo(math.pi / 3, 1e-9));
      g.phase = Phase.playing;
      for (var i = 0; i < 60; i++) {
        g.tick(1 / 60, inputX: .5, inputY: 1);
      }
      expect(g.x, lessThan(0));
      expect(g.z, 0);
      expect(g.vz, 0);
      final facings = g.drops.map((d) => d.facing).toList();
      for (var i = 0; i < 20; i++) {
        g.rotate(-1);
      }
      expect(g.targetYaw, closeTo(-math.pi / 3, 1e-9));
      expect(g.drops.map((d) => d.facing), facings);
    },
  );
  test('lane catches only on its track through a complete round', () {
    final g = CatchGame()..lane = true;
    g.start();
    for (var i = 0; i < 1400; i++) {
      final p = g.demoInput();
      g.tick(1 / 60, inputX: p.x, inputY: p.y);
      expect(g.z, 0);
    }
    expect(g.phase, Phase.result);
    expect(g.caught, greaterThan(5));
    expect(g.caught + g.missed, 12);
  });
  test('camera-relative movement round trips at all camera angles', () {
    for (var i = -8; i <= 8; i++) {
      final yaw = i * math.pi / 4;
      final w = CatchGame.toWorld(.3, -.8, yaw);
      final s = CatchGame.toScreen(w.x, w.z, yaw);
      expect(s.x, closeTo(.3, 1e-10));
      expect(s.y, closeTo(-.8, 1e-10));
    }
    final w = CatchGame.toWorld(1, 0, math.pi / 2);
    expect(w.x, closeTo(0, 1e-10));
    expect(w.z, closeTo(1, 1e-10));
  });
  test('beer combo, happoshu penalty and one-shot catch resolution', () {
    final g = CatchGame()..start();
    g.phase = Phase.playing;
    g.drops
      ..clear()
      ..addAll([
        Drop(0, CanKind.superTry, 0, 1, -3.1),
        Drop(1, CanKind.light, 0, 1, -3.1),
      ]);
    g.tick(1 / 60);
    expect(g.score, 225);
    g.tick(1 / 60);
    expect(g.score, 225);
    g.drops.add(Drop(2, CanKind.happoshu, 0, 1, -3.1));
    g.tick(1 / 60);
    expect(g.score, 25);
    expect(g.combo, 0);
    expect(g.bad, 1);
  });
  test('stage limits and completed rounds stop movement', () {
    final g = CatchGame()..start();
    for (var i = 0; i < 1500; i++) {
      g.tick(1 / 60, inputX: 1, inputY: 1);
      expect(g.x.abs(), lessThanOrEqualTo(CatchGame.halfX));
      expect(g.z.abs(), lessThanOrEqualTo(CatchGame.halfZ));
    }
    expect(g.phase, Phase.result);
    final x = g.x;
    g.tick(.1, inputX: -1);
    expect(g.x, x);
  });
  test('recording controller plays full round through normal inputs', () {
    final g = CatchGame()..start();
    for (var i = 0; i < 1400; i++) {
      final input = g.demoInput();
      g.tick(1 / 60, inputX: input.x, inputY: input.y);
    }
    expect(g.phase, Phase.result);
    expect(g.caught, greaterThanOrEqualTo(6));
    expect(g.bad, greaterThanOrEqualTo(1));
    expect(g.caught + g.missed, 12);
    expect(g.events.length, g.caught + g.bad);
  });
  test('sensor calibrates, rejects bad samples and expires stale data', () {
    var now = DateTime(2026);
    final t = TiltInput(now: () => now);
    t.sample(0, 0, 9.8);
    expect(t.available, true);
    expect(t.x, 0);
    now = now.add(const Duration(milliseconds: 100));
    t.sample(0, 3, 9.3);
    expect(t.x, greaterThan(0));
    t.calibrate();
    expect(t.x, 0);
    t.sample(double.nan, 0, 0);
    expect(t.gx.isFinite, true);
    now = now.add(const Duration(seconds: 1));
    expect(t.available, false);
    expect(t.x, 0);
  });
}
