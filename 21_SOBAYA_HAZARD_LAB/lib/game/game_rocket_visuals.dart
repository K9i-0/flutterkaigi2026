import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'game_state.dart';
import 'game_world_effects.dart';

/// Reusable low-poly prop in GunSocket coordinates (barrel points along -Z).
Node buildRocketLauncher() {
  final root = Node(name: 'RocketLaunchua');
  PhysicallyBasedMaterial material(
    double r,
    double g,
    double b,
    double metal,
  ) => PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(r, g, b, 1)
    ..metallicFactor = metal
    ..roughnessFactor = .48;
  final olive = material(.24, .30, .14, .45);
  final steel = material(.13, .15, .16, .8);
  final black = material(.018, .021, .019, .1);
  final warning = material(.8, .55, .08, .2);
  void tube(double radius, double length, double z, Material mat) {
    root.add(
      Node(
          mesh: Mesh(
            CylinderGeometry(
              bottomRadius: radius,
              topRadius: radius,
              height: length,
              radialSegments: 16,
            ),
            mat,
          ),
        )
        ..position = vm.Vector3(0, .11, z)
        ..rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2),
    );
  }

  tube(.085, 1.05, -.24, olive);
  tube(.10, .08, -.80, steel);
  tube(.082, .004, -.844, black);
  tube(.10, .09, .30, steel);
  tube(.09, .045, -.58, warning);
  for (final z in [-.1, -.43]) {
    root.add(
      Node(mesh: Mesh(CuboidGeometry(vm.Vector3(.045, .14, .055)), black))
        ..position = vm.Vector3(0, -.015, z),
    );
  }
  root.add(
    Node(mesh: Mesh(CuboidGeometry(vm.Vector3(.06, .055, .24)), steel))
      ..position = vm.Vector3(0, .225, -.25),
  );
  return root;
}

/// Three shared batches replace per-sphere scene nodes. Residual smoke outlives
/// the damaging .55 s blast without extending damage or AI noise.
class RocketVisuals {
  RocketVisuals(this.scene) {
    for (final batch in [_fire, _glow, _smoke]) {
      scene.add(batch.node);
    }
    scene.add(_lightNode);
  }
  final Scene scene;
  final _fire = HazardSpriteBatch(capacity: 80, flame: true);
  final _glow = HazardSpriteBatch(capacity: 80);
  final _smoke = HazardSpriteBatch(capacity: 32, smoke: true);
  final _blasts = <RocketBlast, double>{};
  final _flash = PointLight(color: vm.Vector3(1, .43, .12), range: 9);
  late final _lightNode = Node()
    ..visible = false
    ..addComponent(PointLightComponent(_flash));
  String _zone = '';
  double _lastClock = 0;

  void update(HazardGameState s, {bool enhanced = true}) {
    // A new game or region discards the old render-only aftermath.
    if (_zone != s.zoneId || s.time < _lastClock) _blasts.clear();
    _zone = s.zoneId;
    _lastClock = s.time;
    for (final b in s.rocketBlasts) {
      _blasts.putIfAbsent(b, () => s.time - b.age);
    }
    _blasts.removeWhere((_, start) => s.time - start > 1.65);
    while (_blasts.length > 4) {
      _blasts.remove(_blasts.keys.first);
    }
    for (final batch in [_fire, _glow, _smoke]) {
      batch.begin();
    }
    _flash.intensity = 0;
    for (final r in s.rockets.take(4)) {
      final flicker = hazardFireIntensity(r.age);
      _glow.add(
        position: r.position,
        width: .23,
        height: .23,
        color: vm.Vector4(3.5, 2.4, .75, .9),
      );
      for (var i = 1; i <= 8; i++) {
        final age = i / 8;
        _glow.add(
          position: r.position - r.direction * (i * .085),
          width: (.17 - age * .11) * flicker,
          height: .18 - age * .10,
          color: vm.Vector4(2.5, 1 - age * .7, .06, 1 - age * .75),
        );
      }
    }
    for (final entry in _blasts.entries) {
      final b = entry.key;
      final age = (s.time - entry.value).clamp(0.0, 1.65);
      final heat = (1 - age / .65).clamp(0.0, 1.0);
      final shock = math.sin((age / .24).clamp(0.0, 1.0) * math.pi);
      if (heat > 0) {
        _glow.add(
          position: b.position,
          width: .5 + age * 6,
          height: .5 + age * 6,
          color: vm.Vector4(3.8, 2.0, .5, heat * .65),
        );
        _glow.add(
          position: b.position,
          width: 1 + age * 12,
          height: .18 + age * .5,
          color: vm.Vector4(2, .9, .23, shock * .4),
        );
        for (var i = 0; i < (enhanced ? 16 : 9); i++) {
          final angle = i * 2.399;
          final spread = .15 + age * (1.6 + i % 3 * .3);
          _fire.add(
            position:
                b.position +
                vm.Vector3(
                  math.cos(angle) * spread,
                  math.sin(i * 1.7) * spread * .5 + age * 1.5,
                  math.sin(angle) * spread,
                ),
            width: (.55 + age * .75) * heat,
            height: (.8 + age) * heat,
            color: vm.Vector4(3, .2 + heat * 1.1, .06, heat * .9),
          );
        }
      }
      for (var i = 0; i < (enhanced ? 12 : 6); i++) {
        final angle = i * 2.399;
        final life = (1 - age / (1 + i % 3 * .2)).clamp(0.0, 1.0);
        final speed = 2.4 + i % 4 * .5;
        _glow.add(
          position:
              b.position +
              vm.Vector3(
                math.cos(angle) * age * speed,
                (.8 + i % 3 * .5) * age - age * age * 1.7,
                math.sin(angle) * age * speed,
              ),
          width: .025,
          height: .08,
          color: vm.Vector4(3, .75, .05, life),
          rotation: angle,
        );
      }
      for (var i = 0; i < (enhanced ? 7 : 4); i++) {
        final angle = i * 2.399;
        final opacity = math.sin(age / 1.65 * math.pi) * .4;
        final size = .6 + age * 1.1;
        _smoke.add(
          position:
              b.position +
              vm.Vector3(
                math.cos(angle) * age * .7,
                age * (1 + i % 3 * .2),
                math.sin(angle) * age * .7,
              ),
          width: size,
          height: size,
          color: vm.Vector4(.21, .20, .18, opacity),
          rotation: angle + age * .12,
        );
      }
      final intensity = enhanced ? 18 * math.pow(heat, 3) : 0.0;
      if (intensity > _flash.intensity) {
        _flash.intensity = intensity.toDouble();
        _lightNode.position = b.position;
      }
    }
    _lightNode.visible = _flash.intensity > .001;
    for (final batch in [_fire, _glow, _smoke]) {
      batch.end();
    }
  }
}
