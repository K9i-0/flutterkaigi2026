import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:yumemi_recruit_exam/balance.dart';
import 'package:yumemi_recruit_exam/catch_game.dart';

void main() {
  CatchGame turned(int steps) {
    final g = CatchGame()..start();
    for (var i = 0; i < steps; i++) {
      g.rotate(1);
    }
    g.phase = Phase.playing;
    return g;
  }

  test('from the side, tilting forward walks the beam', () {
    // Three 30-degree steps look straight along the beam.
    final g = turned(3);
    for (var i = 0; i < 90; i++) {
      g.tick(1 / 60, inputY: 1);
    }
    expect(g.yaw, closeTo(math.pi / 2, .02));
    expect(g.x, lessThan(-1));
  });

  test('in the default view only left and right tilt moves', () {
    final g = turned(0);
    for (var i = 0; i < 60; i++) {
      g.tick(1 / 60, inputY: 1);
    }
    expect(g.x, closeTo(0, 1e-9));
    for (var i = 0; i < 60; i++) {
      g.tick(1 / 60, inputX: .7);
    }
    expect(g.x, lessThan(-1));
  });

  test('the demo still finishes rounds while looking around', () {
    final g = turned(2);
    var steps = 0;
    while (g.phase != Phase.result && steps++ < 30 * 60) {
      final input = g.demoInput();
      g.tick(1 / 60, inputX: input.x, inputY: input.y);
    }
    expect(g.phase, Phase.result);
    expect(g.caught, greaterThan(0));
  });

  test('drops face every direction by default', () {
    final g = CatchGame();
    g.start(seed: 4);
    final degrees = g.drops.map((d) => d.facing * 180 / math.pi).toList();
    expect(degrees.every((d) => d.abs() <= 180), true);
    // Front, side and back headings all appear, not only the beam axis.
    expect(degrees.any((d) => d.abs() < 45), true);
    expect(degrees.any((d) => d.abs() > 135), true);
    expect(
      Balance.defaults()['zoomMin'],
      lessThan(Balance.defaults()['zoomMax']),
    );
  });
}
