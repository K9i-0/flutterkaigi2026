import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_beer_rain/balance.dart';
import 'package:sobaya_beer_rain/catch_game.dart';

void main() {
  test('reject invalid and unknown settings atomically', () {
    for (final input in <Map<String, dynamic>>[
      {'fallSeconds': 0},
      {'moveSpeed': double.nan},
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
    final g = CatchGame()..lane = true;
    g.balance = Balance.fromMap({
      'roundSeconds': 10,
      'spawnInterval': .5,
      'fallSeconds': 2,
      'badRatio': 1,
      'penalty': 75,
    });
    g.start(seed: 42);
    expect(g.drops.length, 15);
    expect(g.drops.every((d) => d.kind == CanKind.happoshu), true);
    expect(g.drops.first.landing, 2);
    g.phase = Phase.playing;
    g.x = g.drops.first.x;
    for (var i = 0; i < 121; i++) {
      g.tick(1 / 60);
    }
    expect(g.bad, 1);
    expect(g.score, -75);
  });
  test('same seed and settings reproduce layout; all-beer ratio works', () {
    final a = CatchGame()..lane = true;
    final b = CatchGame()..lane = true;
    a.balance = b.balance = Balance.fromMap({'badRatio': 0});
    a.start(seed: 987);
    b.start(seed: 987);
    expect(
      a.drops.map((d) => (d.x, d.facing, d.kind)),
      b.drops.map((d) => (d.x, d.facing, d.kind)),
    );
    expect(a.drops.any((d) => d.kind == CanKind.happoshu), false);
  });
  test('maximum density fits visual pool and round resolves every drop', () {
    final g = CatchGame()..lane = true;
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
    expect(g.time, 60);
    expect(g.drops.every((d) => d.resolved), true);
  });
}
