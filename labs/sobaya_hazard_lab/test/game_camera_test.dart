import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:sobaya_hazard_lab/game/game_camera.dart';
import 'package:sobaya_hazard_lab/game/game_native_audit.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';

void main() {
  test(
    'pointer movement turns the center ray toward that screen direction',
    () {
      final map = jsonDecode(File('assets/village.json').readAsStringSync());
      const size = ui.Size(1280, 840), center = ui.Offset(640, 420);
      // Check the rendered camera's rays, not just the sign of a stored angle.
      for (final yaw in [0.0, math.pi / 2, math.pi, -math.pi / 2]) {
        for (final aiming in [false, true]) {
          for (final delta in [
            const ui.Offset(20, 0),
            const ui.Offset(-20, 0),
            const ui.Offset(0, 20),
            const ui.Offset(0, -20),
          ]) {
            final s = HazardGameState(map)
              ..phase = PlayPhase.playing
              ..yaw = yaw
              ..pitch = 0
              ..aiming = aiming;
            s.obstacles.clear();
            s.crates.clear();
            final before = playerCamera(s);
            final forward = before.screenPointToRay(center, size).direction;
            final expected = before
                .screenPointToRay(center + delta, size)
                .direction;
            rotatePlayerView(s, delta.dx, delta.dy);
            final actual = playerCamera(s)
                .screenPointToRay(center, size)
                .direction;
            expect(
              (actual - forward).dot(expected - forward),
              greaterThan(0),
              reason: 'yaw=$yaw aiming=$aiming delta=$delta',
            );
          }
        }
      }
    },
  );

  test('pointer look respects pause, sensitivity and vertical limits', () {
    final s = HazardGameState(
      jsonDecode(File('assets/village.json').readAsStringSync()),
    )..phase = PlayPhase.paused;
    final yaw = s.yaw, pitch = s.pitch;
    rotatePlayerView(s, 30, 20);
    expect(s.yaw, yaw);
    expect(s.pitch, pitch);
    s.phase = PlayPhase.playing;
    rotatePlayerView(s, 30, 0, sensitivity: .5);
    expect(s.yaw - yaw, closeTo(.09, .000001));
    rotatePlayerView(s, 0, 10000);
    expect(s.pitch, maxCameraPitch);
    rotatePlayerView(s, 0, -10000);
    expect(s.pitch, minCameraPitch);
  });

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
