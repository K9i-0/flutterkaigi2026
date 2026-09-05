import 'dart:math' as math;

import 'package:flutter_scene/scene.dart' show PerspectiveCamera;
import 'package:vector_math/vector_math.dart' as vm;

import 'game_state.dart';

PerspectiveCamera playerCamera(HazardGameState s) {
  final right = vm.Vector3(-math.cos(s.yaw), 0, math.sin(s.yaw));
  final pivot = vm.Vector3(s.x, s.y + 1.35, s.z);
  final shoulder = s.aiming ? .43 : .22;
  final clearance = cameraCollisionDistance(s, pivot, right, shoulder);
  final target =
      pivot + right * math.max(0, math.min(shoulder, clearance - .02));
  final distance = s.aiming ? 2.0 : 3.4;
  final offset = vm.Vector3(
    math.sin(s.yaw) * math.cos(s.pitch - s.recoil) * distance,
    math.sin(s.pitch - s.recoil) * distance + .18,
    math.cos(s.yaw) * math.cos(s.pitch - s.recoil) * distance,
  );
  final length = cameraCollisionDistance(
    s,
    target,
    offset.normalized(),
    offset.length,
  );
  final actual = math.max(.01, math.min(offset.length, length - .02));
  return PerspectiveCamera(
    position: target + offset.normalized() * actual,
    target: target,
    fovRadiansY: (s.aiming ? 42 : 53) * math.pi / 180,
    fovNear: .07,
    fovFar: 85,
  );
}

// A small camera sphere keeps the near plane clear when skimming a wall.
double cameraCollisionDistance(
  HazardGameState s,
  vm.Vector3 origin,
  vm.Vector3 direction,
  double distance,
) {
  var result = distance;
  for (final obstacle in s.obstacles) {
    if (obstacle.id == 'gate' && s.gateOpen) continue;
    final hit = obstacle.ray(origin, direction, result, padding: .12);
    if (hit != null) result = math.min(result, hit);
  }
  for (final c in s.crates.where((c) => !c.broken)) {
    final box = Obstacle({
      'x': c.x,
      'z': c.z,
      'w': .9,
      'd': .9,
      'bottom': 0,
      'top': 1.0,
    });
    final hit = box.ray(origin, direction, result, padding: .12);
    if (hit != null) result = math.min(result, hit);
  }
  return result;
}
