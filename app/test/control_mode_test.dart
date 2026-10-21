import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:yumemi_recruit_exam/balance.dart';
import 'package:yumemi_recruit_exam/catch_game.dart';

void main() {
  CatchGame turned(ControlMode mode, int steps) {
    final g = CatchGame()
      ..lane = true
      ..controlMode = mode;
    g.start();
    for (var i = 0; i < steps; i++) {
      g.rotate(1);
    }
    g.phase = Phase.playing;
    return g;
  }

  test('camera mode: from the side, tilting forward walks the beam', () {
    // Three 30-degree steps look straight along the beam.
    final camera = turned(ControlMode.camera, 3);
    final fixed = turned(ControlMode.fixed, 3);
    for (var i = 0; i < 90; i++) {
      camera.tick(1 / 60, inputY: 1);
      fixed.tick(1 / 60, inputY: 1);
    }
    expect(camera.yaw, closeTo(math.pi / 2, .02));
    expect(camera.x, lessThan(-1));
    expect(fixed.x, 0);
    expect(camera.z, 0);
  });

  test('camera mode matches the fixed mode in the default view', () {
    final camera = turned(ControlMode.camera, 0);
    final fixed = turned(ControlMode.fixed, 0);
    for (var i = 0; i < 60; i++) {
      camera.tick(1 / 60, inputX: .7);
      fixed.tick(1 / 60, inputX: .7);
    }
    expect(camera.x, closeTo(fixed.x, 1e-9));
  });

  test('camera-mode demo still finishes rounds while looking around', () {
    final g = turned(ControlMode.camera, 2);
    var steps = 0;
    while (g.phase != Phase.result && steps++ < 30 * 60) {
      final input = g.demoInput();
      g.tick(1 / 60, inputX: input.x, inputY: input.y);
    }
    expect(g.phase, Phase.result);
    expect(g.caught, greaterThan(0));
  });

  test('drops face every direction by default', () {
    final g = CatchGame()..lane = true;
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
