import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:yumemi_recruit_exam/balance.dart';
import 'package:yumemi_recruit_exam/catch_game.dart';

void main() {
  test('reject invalid and unknown settings atomically', () {
    for (final input in <Map<String, dynamic>>[
      {'fallSeconds': 0},
      {'acceleration': double.nan},
      {'unknown': 1},
      {'badRatio': 'many'},
      {'facingMin': 100, 'facingMax': 20},
    ]) {
      expect(() => Balance.fromMap(input), throwsFormatException);
    }
    final b = Balance.defaults();
    expect(() => b.values['moveSpeed'] = 99, throwsUnsupportedError);
  });
  test('spawn count, fall time, mixture and scoring follow settings', () {
    final g = CatchGame();
    g.balance = Balance.fromMap({
      'roundSeconds': 10,
      'spawnInterval': .5,
      'fallSeconds': 2,
      'badRatio': 1,
      'penalty': 25,
    });
    g.start(seed: 42);
    expect(g.drops.length, 15);
    expect(g.drops.every((d) => d.kind.isBad), true);
    expect(g.drops.first.landing, 2);
    g.phase = Phase.playing;
    g.x = g.drops.first.x;
    for (var i = 0; i < 121; i++) {
      g.tick(1 / 60);
    }
    expect(g.bad, 1);
    // An all-bad round has nothing to catch; the score floors at zero.
    expect(g.goodTotal, 0);
    expect(g.score, 0);
  });
  test('same seed and settings reproduce layout; all-beer ratio works', () {
    final a = CatchGame();
    final b = CatchGame();
    a.balance = b.balance = Balance.fromMap({'badRatio': 0});
    a.start(seed: 987);
    b.start(seed: 987);
    expect(
      a.drops.map((d) => (d.x, d.facing, d.kind)),
      b.drops.map((d) => (d.x, d.facing, d.kind)),
    );
    expect(a.drops.any((d) => d.kind.isBad), false);
  });
  test('retired keys in saved JSON are ignored', () {
    final b = Balance.fromMap({
      'catchRadius': .9,
      'moveSpeed': 2,
      'beerPoints': 100,
      'comboBonus': 25,
      'badRatio': .5,
    });
    for (final key in [
      'catchRadius',
      'moveSpeed',
      'beerPoints',
      'comboBonus',
    ]) {
      expect(b.values.containsKey(key), false);
    }
    expect(b['badRatio'], .5);
  });
  test('lane rounds keep the default can mix for every seed', () {
    final a = CatchGame();
    a.start(seed: 987);
    expect(a.drops.length, 16);
    expect(a.drops.where((d) => d.kind.isBad).length, 4);
    expect(a.drops.where((d) => !d.kind.isBad).length, 12);
    for (var seed = 1; seed <= 40; seed++) {
      final g = CatchGame();
      g.start(seed: seed);
      expect(g.drops.length, 16);
      expect(g.drops.where((d) => d.kind.isBad).length, 4);
    }
  });
  test('maximum density fits visual pool and round resolves every drop', () {
    final g = CatchGame();
    g.balance = Balance.fromMap({
      'roundSeconds': 60,
      'spawnInterval': .5,
      'fallSeconds': 6,
    });
    g.start();
    for (var i = 0; i < 3800; i++) {
      g.tick(1 / 60);
      expect(
        g.drops.where((d) => d.visible(g.time)).length,
        lessThanOrEqualTo(16),
      );
    }
    expect(g.phase, Phase.result);
    // The round ends just after its last drop is judged, not on an empty sky.
    final last = g.drops.map((d) => d.landing).reduce(math.max);
    expect(g.time, closeTo(last + g.catchGrace + CatchGame.endBeat, 1e-9));
    expect(g.time, lessThanOrEqualTo(60));
    expect(g.drops.every((d) => d.resolved), true);
    expect(g.drops.every((d) => d.resolved), true);
  });
}
