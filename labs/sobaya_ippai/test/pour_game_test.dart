import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_ippai/pour_game.dart';

void step(PourGame game, double seconds, double tilt, {int hz = 120}) {
  for (var i = 0; i < (seconds * hz).round(); i++) {
    game.tick(1 / hz, input: tilt);
  }
}

PourGame playing() {
  final g = PourGame()..start();
  step(g, 1.7, 0);
  return g;
}

void main() {
  test('intro leads to an empty mug, empty timeout angers Sobaya', () {
    final g = playing();
    expect(g.phase, PourPhase.pouring);
    expect(g.fill, 0);
    step(g, 19, 0);
    expect(g.phase, PourPhase.result);
    expect(g.score, 0);
    expect(g.angry, true);
  });
  test('pour stops at nozzle but airborne beer still lands', () {
    final g = playing();
    step(g, 3, .65);
    final before = g.fill, air = g.airborne;
    expect(air, greaterThan(0));
    g.serve();
    step(g, 1, 0);
    expect(g.fill, closeTo(before + air, 1e-8));
    expect(g.phase, PourPhase.result);
  });
  test('overfilling is immediate OUT, score zero', () {
    final g = playing();
    step(g, 10, 1);
    expect(g.spilled, true);
    expect(g.score, 0);
    expect(g.phase, PourPhase.result);
  });
  test('in-flight beer can cause overflow after serving', () {
    final g = playing();
    while (g.fill < .985) {
      g.tick(1 / 120, input: 1);
    }
    expect(g.spilled, false);
    g.serve();
    step(g, 1, 0);
    expect(g.spilled, true);
  });
  test('fast pour generates more foam than gentle pour', () {
    final slow = playing(), fast = playing();
    step(slow, 5, .35);
    step(fast, 5, .9);
    expect(fast.foamRatio, greaterThan(slow.foamRatio + .2));
  });
  test('reachable 100 through actual tilt inputs, with no state injection', () {
    final g = playing();
    // Smoothly held calibrated tilt, stop accounting for liquid in flight.
    while (g.fill + g.airborne < .996 && g.phase == PourPhase.pouring) {
      g.tick(1 / 120, input: .694);
    }
    g.serve();
    step(g, 1, 0);
    expect(g.spilled, false);
    expect(g.score, 100);
    expect(g.foamRatio, closeTo(.30, .012));
  });
  test('foam-heavy full mug cannot score well', () {
    final g = playing();
    while (g.fill + g.airborne < .99) {
      g.tick(1 / 120, input: .96);
    }
    g.serve();
    step(g, 1, 0);
    expect(g.spilled, false);
    expect(g.score, lessThan(60));
  });
  test('30, 60 and 120Hz produce comparable outcomes', () {
    final results = <double>[];
    for (final hz in [30, 60, 120]) {
      final g = PourGame()..start();
      step(g, 2, 0, hz: hz);
      step(g, 8, .7, hz: hz);
      g.serve();
      step(g, 1, 0, hz: hz);
      results.add(g.fill);
    }
    expect(
      results.reduce((a, b) => a > b ? a : b) -
          results.reduce((a, b) => a < b ? a : b),
      lessThan(.004),
    );
  });
  test('reset clears pending beer and result state', () {
    final g = playing();
    step(g, 3, 1);
    g.start();
    expect(g.airborne, 0);
    expect(g.fill, 0);
    expect(g.spilled, false);
    expect(g.phase, PourPhase.approach);
  });
  test('invalid time and input cannot corrupt simulation', () {
    final g = playing();
    expect(() => g.tick(1), throwsArgumentError);
    expect(() => g.tick(1 / 120, input: double.nan), throwsArgumentError);
  });
}
