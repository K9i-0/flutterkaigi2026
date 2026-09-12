import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_scene/scene.dart'
    show CameraProjection, PerspectiveCamera;
import 'package:vector_math/vector_math.dart' as vm;

import 'game_state.dart';

/// Keep cinematic subjects above the subtitle panel on short landscape phones.
/// A lens shift preserves the authored eye position, sight lines and lighting;
/// moving the camera down would introduce walls and table occlusion.
PerspectiveCamera frameAboveCaptions(PerspectiveCamera camera, ui.Size size) =>
    size.height < 500 && size.width > size.height
    ? _CaptionCamera(camera)
    : camera;

class _CaptionCamera extends PerspectiveCamera {
  _CaptionCamera(PerspectiveCamera source)
    : super(
        position: source.position,
        target: source.target,
        up: source.up,
        fovRadiansY: source.fovRadiansY,
        fovNear: source.fovNear,
        fovFar: source.fovFar,
      );
  @override
  CameraProjection get projection => _CaptionProjection(super.projection);
}

class _CaptionProjection extends CameraProjection {
  _CaptionProjection(this.base);
  final CameraProjection base;
  @override
  vm.Matrix4 getProjectionMatrix(double aspectRatio, {vm.Vector2? jitter}) {
    final matrix = base.getProjectionMatrix(aspectRatio, jitter: jitter);
    // Target at 35% of screen height instead of 50%; near/far depths unchanged.
    matrix.setRow(1, matrix.getRow(1) + matrix.getRow(3) * .30);
    return matrix;
  }
}

/// Pointer deltas steer the viewing direction, rather than dragging the world.
void rotatePlayerView(
  HazardGameState s,
  double dx,
  double dy, {
  double sensitivity = 1,
}) {
  if (!s.running) return;
  s.yaw += dx * .006 * sensitivity;
  s.pitch = (s.pitch + dy * .004 * sensitivity).clamp(
    minCameraPitch,
    maxCameraPitch,
  );
}

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

/// Reuse the collision-resolved camera only for one enemy update loop.
/// Movement, recoil, projectiles and obstacle changes finish before that loop.
/// A grab can stop aiming during it, so rebuild at that boundary. The caller
/// must create a fresh predicate for each update; nothing survives a frame.
bool Function(vm.Vector3) playerViewForUpdate(
  HazardGameState s,
  ui.Size viewport,
) {
  PerspectiveCamera? view;
  bool? aiming;
  return (point) {
    if (view == null || aiming != s.aiming) {
      view = playerCamera(s);
      aiming = s.aiming;
    }
    final projected = view!.worldToScreen(point, viewport);
    return projected != null &&
        projected.dx >= 0 &&
        projected.dx <= viewport.width &&
        projected.dy >= 0 &&
        projected.dy <= viewport.height;
  };
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
