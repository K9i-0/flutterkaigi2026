import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'game_state.dart';
import 'game_world_effects.dart';
import '../lab/beer_mug_component.dart';

class BeerThrowVisuals {
  BeerThrowVisuals(Scene scene, Node mugTemplate, Node handSocket) {
    scene.add(dots.node);
    for (var i = 0; i < 4; i++) {
      final node = mugTemplate.clone()..visible = false;
      node.addComponent(
        BeerMugComponent(isPaused: () => _paused)..detail = false,
      );
      flying.add(node);
      scene.add(node);
    }
    held = mugTemplate.clone()..visible = false;
    held.addComponent(
      BeerMugComponent(isPaused: () => _paused)..detail = false,
    );
    final inverseGrip =
        vm.Matrix4.copy(held.getChildByName('Grip')!.globalTransform)
          ..invert()
          ..multiply(held.globalTransform);
    held.localTransform = inverseGrip;
    handSocket.add(held);
  }
  final dots = HazardSpriteBatch(capacity: 384);
  final flying = <Node>[];
  late final Node held;
  bool _paused = true;

  void update(HazardGameState s) {
    _paused = !s.running;
    held.visible =
        s.running &&
        s.aiming &&
        s.weapon == 'beer' &&
        s.beers > 0 &&
        s.beerThrowTime == 0;
    for (var i = 0; i < flying.length; i++) {
      flying[i].visible = i < s.beerFlights.length;
      if (!flying[i].visible) continue;
      final b = s.beerFlights[i];
      flying[i].position = b.position - vm.Vector3(0, .1, 0);
      flying[i].rotation = vm.Quaternion.euler(b.age * 7, b.age * 2, .25);
    }
    dots.begin();
    final plan = s.beerPreview;
    if (s.running &&
        s.aiming &&
        s.weapon == 'beer' &&
        plan != null &&
        s.beers > 0) {
      for (final point in plan.points) {
        dots.add(
          position: point,
          width: .035,
          height: .035,
          color: vm.Vector4(.8, .9, .7, .75),
        );
      }
      // The ground ring is the unobstructed maximum, not an enemy detector.
      for (var i = 0; i < 192; i++) {
        final angle = i * math.pi * 2 / 192;
        final x = plan.landing.x + math.sin(angle) * hazardBeerLureRadius;
        final z = plan.landing.z + math.cos(angle) * hazardBeerLureRadius;
        dots.add(
          position: vm.Vector3(x, s.floorHeight(x, z, plan.landing.y) + .08, z),
          width: .16,
          height: .10,
          color: vm.Vector4(1.2, 1.0, .08, .65),
        );
      }
      for (var i = 0; i < 20; i++) {
        final angle = i * math.pi / 10;
        dots.add(
          position:
              plan.landing +
              vm.Vector3(math.sin(angle) * .28, .025, math.cos(angle) * .28),
          width: .055,
          height: .055,
          color: vm.Vector4(1.4, .08, .05, .95),
        );
      }
    }
    for (final splash in s.beerSplashes.take(3)) {
      final age = splash.age, opacity = (1 - age / 1.4).clamp(0.0, 1.0);
      for (var i = 0; i < 16; i++) {
        final angle = i * 2.399;
        final position =
            splash.position +
            vm.Vector3(
              math.cos(angle) * age * .9,
              math.max(.015, (.6 + i % 3 * .22) * age - age * age * 2),
              math.sin(angle) * age * .9,
            );
        dots.add(
          position: position,
          width: .025,
          height: .05,
          color: vm.Vector4(1.0, .61 + (i % 2) * .3, .17, opacity * .8),
        );
      }
    }
    dots.end();
  }
}
