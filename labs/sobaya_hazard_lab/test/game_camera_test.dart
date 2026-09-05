import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:sobaya_hazard_lab/game/game_camera.dart';
import 'package:sobaya_hazard_lab/game/game_native_audit.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';

void main() {
  test('shoulder ray respects cover even when muzzle can see the target', () {
    final s =
        HazardGameState(
            jsonDecode(File('assets/village.json').readAsStringSync()),
          )
          ..x = 4.249403849398622
          ..z = -10.9967794047559;
    final target = vm.Vector3(-2, 1.1, -6);
    aimCameraState(s, target);
    final c = playerCamera(s),
        r = c.screenPointToRay(
          const ui.Offset(640, 420),
          const ui.Size(1280, 840),
        );
    final delta = target - r.origin;
    expect(delta.cross(r.direction.normalized()).length, lessThan(.001));
    expect(
      s.wallDistance(r.origin, r.direction.normalized(), delta.length),
      lessThan(delta.length - .3),
    );
  });

  test('upper floor blocks a ray while the stairwell stays open', () {
    final s = HazardGameState(
      jsonDecode(File('assets/village.json').readAsStringSync()),
    );
    expect(
      s.wallDistance(vm.Vector3(7, 4, -6), vm.Vector3(0, -1, 0), 4),
      closeTo(.97, .001),
    );
    expect(
      s.wallDistance(vm.Vector3(10.95, 4, -6), vm.Vector3(0, -1, 0), 4),
      4,
    );
  });

  test('camera does not cross the village wall when the shoulder approaches a corner', () {
    final s =
        HazardGameState(
            jsonDecode(File('assets/village.json').readAsStringSync()),
          )
          ..x = 4.287296518367787
          ..z = -11
          ..yaw = .796373653965431
          ..pitch = 0
          ..aiming = true;
    final camera = playerCamera(s);
    for (final o in s.obstacles) {
      final p = camera.position;
      expect(
        p.x > o.x - o.w / 2 &&
            p.x < o.x + o.w / 2 &&
            p.z > o.z - o.d / 2 &&
            p.z < o.z + o.d / 2 &&
            p.y > o.bottom &&
            p.y < o.top,
        false,
      );
    }
  });

  test('center-screen camera ray can reach an elevated farm medal', () {
    final s =
        HazardGameState(jsonDecode(File('assets/farm.json').readAsStringSync()))
          ..x = 6
          ..z = -20;

    final target = vm.Vector3(6, 4.6, -14.22);
    aimCameraState(s, target);
    final camera = playerCamera(s);
    final ray = camera.screenPointToRay(
      const ui.Offset(640, 400),
      const ui.Size(1280, 800),
    );
    final delta = target - ray.origin;
    expect(delta.cross(ray.direction).length, lessThan(.02));
    expect(s.pitch, lessThan(-.25));
    s.shoot(ray.origin, ray.direction);
    expect(s.medallions, contains('farm_5'));
    final restored = restoreHazardCheckpoint(s.checkpoint(), s.map, {});
    expect(restored.pitch, s.pitch);
  });
}
