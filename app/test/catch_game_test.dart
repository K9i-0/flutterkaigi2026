import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:yumemi_recruit_exam/catch_game.dart';
import 'package:yumemi_recruit_exam/tilt_input.dart';

void main() {
  test(
    'lane ignores depth input and keeps controls stable while looking around',
    () {
      final g = CatchGame();
      g.start();
      expect(g.drops.any((d) => d.facing < 0), true);
      expect(g.drops.any((d) => d.facing > 0), true);
      g.rotate(1);
      g.rotate(1);
      expect(g.targetYaw, closeTo(math.pi / 3, 1e-9));
      g.phase = Phase.playing;
      for (var i = 0; i < 60; i++) {
        g.tick(1 / 60, inputX: .5, inputY: 1);
      }
      expect(g.x, lessThan(0));
      final facings = g.drops.map((d) => d.facing).toList();
      // A full orbit has no stop and wraps back into (-pi, pi].
      for (var i = 0; i < 4; i++) {
        g.rotate(1);
      }
      expect(g.targetYaw, closeTo(math.pi, 1e-9));
      g.rotate(1);
      expect(g.targetYaw, closeTo(-5 * math.pi / 6, 1e-9));
      for (var i = 0; i < 7; i++) {
        g.rotate(1);
      }
      expect(g.targetYaw, closeTo(math.pi / 3, 1e-9));
      for (var i = 0; i < 12; i++) {
        g.rotate(-1);
      }
      expect(g.targetYaw, closeTo(math.pi / 3, 1e-9));
      expect(g.drops.map((d) => d.facing), facings);
    },
  );
  test('lane controls follow the screen from behind the beam', () {
    final g = CatchGame();
    g.start();
    for (var i = 0; i < 6; i++) {
      g.rotate(1);
    }
    g.phase = Phase.playing;
    for (var i = 0; i < 90; i++) {
      g.tick(1 / 60, inputX: .5);
    }
    expect(g.yaw, closeTo(math.pi, .02));
    expect(g.x, greaterThan(0));
  });
  test('lane catches only on its track through a complete round', () {
    final g = CatchGame();
    g.start();
    for (var i = 0; i < 1400; i++) {
      final p = g.demoInput();
      g.tick(1 / 60, inputX: p.x, inputY: p.y);
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
        Drop(0, CanKind.superTry, 0, -3.1),
        Drop(1, CanKind.light, 0, -3.1),
      ]);
    g.tick(1 / 60);
    expect(g.score, 225);
    g.tick(1 / 60);
    expect(g.score, 225);
    g.drops.add(Drop(2, CanKind.happoshu, 0, -3.1));
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
  test('a catch records where it landed and only a restart clears it', () {
    final g = CatchGame()..start();
    expect(g.fxX, isNull);
    g.phase = Phase.playing;
    g.drops
      ..clear()
      ..add(Drop(0, CanKind.superTry, .2, -3.1));
    g.tick(1 / 60);
    expect(g.fxX, .2);
    expect(g.fxBad, false);
    expect(g.caught, 1);

    g.drops.add(Drop(1, CanKind.happoshu, -.4, -3.1));
    g.x = -.4;
    g.tick(1 / 60);
    expect(g.fxX, -.4);
    expect(g.fxBad, true);
    expect(g.bad, 1);
    expect(g.score, 100 - g.balance['penalty'].round());

    g.x = 0;
    g.drops.add(Drop(2, CanKind.light, 3, -3.1));
    g.tick(1 / 60);
    expect(g.missed, 1);
    expect(g.fxX, -.4);
    expect(g.eventId, 2);

    g.start();
    expect(g.fxX, isNull);
    expect(g.fxBad, false);

    final practice = CatchGame()
      ..practice = true
      ..start();
    practice.phase = Phase.playing;
    practice.drops
      ..clear()
      ..add(Drop(0, CanKind.yumemin, .1, -3.1));
    practice.tick(1 / 60);
    expect(practice.score, 0);
    expect(practice.fxX, .1);
    expect(practice.fxBad, false);
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
