import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:sobaya_tidewater/island_world.dart';
import 'package:sobaya_tidewater/player_controller.dart';

class FlatWorld extends IslandWorld {
  FlatWorld(
    List<Map<String, Object>> boxes, {
    List<Map<String, Object>> cylinders = const [],
  }) : super({
         'heightfield': {'resolution': 2, 'origin': 0, 'texel': 1},
         'boxes': boxes,
         'cylinders': cylinders,
       }, ByteData(16));
  @override
  double heightAt(double x, double z) => 0;
}

Map<String, Object> box(
  double x,
  double z,
  double hx,
  double hz,
  double bottom,
  double top, {
  double angle = 0,
}) => {
  'center': {'x': x, 'y': (bottom + top) / 2, 'z': z},
  'half': {'x': hx, 'y': (top - bottom) / 2, 'z': hz},
  'bottom': bottom,
  'top': top,
  'cos': math.cos(angle),
  'sin': math.sin(angle),
  'solid': true,
  'walkable': false,
};
void advance(
  PlayerController p,
  double seconds, {
  double yaw = 0,
  double forward = 0,
  double right = 0,
  bool run = false,
}) {
  for (var i = 0; i < (seconds * 120).round(); i++) {
    p.update(1 / 120, yaw, forward, right, run);
  }
}

void main() {
  test(
    'right strafe matches the actual left-handed camera at every heading',
    () {
      for (final yaw in [0.0, .5, math.pi / 2, math.pi, 4.2]) {
        final forward = Vector3(-math.sin(yaw), 0, -math.cos(yaw));
        final right = Vector3(0, 1, 0).cross(forward);
        expect(
          PlayerController.direction(yaw, 0, 1).distanceTo(right),
          lessThan(1e-6),
        );
        expect(PlayerController.direction(yaw, 1, 1).length, closeTo(1, 1e-6));
      }
    },
  );
  test(
    'jump rises about 90 cm, moves in air, and lands once without double jump',
    () {
      final p = PlayerController(FlatWorld([]), Vector3.zero())..reset();
      p.jump();
      advance(p, .3, forward: 1);
      expect(p.feet.y, inInclusiveRange(.8, 1));
      expect(p.feet.z, lessThan(-.4));
      p.jump();
      advance(p, .7, forward: 1);
      expect(p.feet.y, closeTo(0, 1e-5));
      expect(p.grounded, true);
      expect(p.jumps, 1);
      expect(p.landings, 1);
    },
  );
  test('head stops on underside; falling lands on a crate top', () {
    final roof = PlayerController(
      FlatWorld([box(0, 0, 2, 2, 2, 2.2)]),
      Vector3.zero(),
    )..reset();
    roof.jump();
    advance(roof, .15);
    expect(roof.feet.y, lessThanOrEqualTo(.301));
    expect(roof.velocity.y, lessThanOrEqualTo(0));
    advance(roof, 1);
    expect(roof.feet.x.abs() + roof.feet.z.abs(), lessThan(1e-6));
    final crate = PlayerController(
      FlatWorld([box(0, 0, .5, .5, 0, .8)]),
      Vector3(0, 2, 0),
    )..reset(onGround: false);
    advance(crate, 1);
    expect(crate.feet.y, closeTo(.8, 1e-5));
    expect(crate.grounded, true);
  });
  test('sprint does not tunnel through thin fence or a rotated box', () {
    for (final angle in [0.0, .3]) {
      final p = PlayerController(
        FlatWorld([box(0, -2, 3, .05, 0, 2, angle: angle)]),
        Vector3.zero(),
      )..reset();
      advance(p, 2, forward: 1, run: true);
      final localZ =
          p.feet.x * math.sin(angle) + (p.feet.z + 2) * math.cos(angle);
      expect(localZ, greaterThanOrEqualTo(.329));
    }
  });
  test('barrel side blocks, top supports; stairs step up without a jump', () {
    final w = FlatWorld(
      [box(0, -1, 1, .5, 0, .25)],
      cylinders: [
        {'x': 3.0, 'z': 0.0, 'radius': .4, 'yMin': 0.0, 'yMax': .9},
      ],
    );
    final p = PlayerController(w, Vector3.zero())..reset();
    advance(p, .4, forward: 1);
    expect(p.feet.y, closeTo(.25, 1e-5));
    final barrel = PlayerController(w, Vector3(3, 2, 0))
      ..reset(onGround: false);
    advance(barrel, 1);
    expect(barrel.feet.y, closeTo(.9, 1e-5));
    final side = Vector3(3.2, 0, 0);
    w.resolve(side, step: 0);
    expect(side.x, closeTo(3.68, 1e-5));
  });
  test('standing still or pushing a wall does not accumulate footsteps', () {
    final p = PlayerController(
      FlatWorld([box(0, -.33, 2, .05, 0, 2)]),
      Vector3.zero(),
    )..reset();
    advance(p, 1, forward: 1);
    expect(p.travelled, lessThan(.001));
    advance(p, 1);
    expect(p.travelled, lessThan(.001));
  });
}
