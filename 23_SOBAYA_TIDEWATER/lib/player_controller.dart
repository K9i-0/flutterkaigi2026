import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'island_world.dart';

/// Upright capsule with horizontal substeps and swept floor/ceiling tests.
class PlayerController {
  PlayerController(this.world, this.feet);
  final IslandWorld world;
  final Vector3 feet;
  final velocity = Vector3.zero();
  final safe = Vector3.zero();
  bool grounded = false, landed = false;
  double travelled = 0, _jumpBuffer = 0, _coyote = 0;
  int jumps = 0, landings = 0;
  static const bodyHeight = 1.7, stepHeight = .36;

  static Vector3 direction(double yaw, double forward, double right) {
    // Flutter Scene is left-handed: screen right = up × camera forward.
    final length = math.max(1.0, math.sqrt(forward * forward + right * right));
    return Vector3(
      (-math.sin(yaw) * forward - math.cos(yaw) * right) / length,
      0,
      (-math.cos(yaw) * forward + math.sin(yaw) * right) / length,
    );
  }

  void reset({bool onGround = true}) {
    velocity.setZero();
    _jumpBuffer = 0;
    _coyote = 0;
    grounded = onGround;
    landed = false;
    travelled = 0;
    safe.setFrom(feet);
  }

  void stop() {
    velocity.x = 0;
    velocity.z = 0;
    _jumpBuffer = 0;
  }

  void jump() => _jumpBuffer = .12;

  void update(
    double delta,
    double yaw,
    double forward,
    double right,
    bool sprint,
  ) {
    final dt = delta.clamp(0.0, .05);
    landed = false;
    travelled = 0;
    _jumpBuffer = math.max(0, _jumpBuffer - dt);
    _coyote = grounded ? .10 : math.max(0, _coyote - dt);
    if (_jumpBuffer > 0 && _coyote > 0) {
      velocity.y = 5.8;
      grounded = false;
      _jumpBuffer = 0;
      _coyote = 0;
      jumps++;
    }
    final directionVector = direction(yaw, forward, right);
    final speed = sprint ? 5.3 : 2.8;
    final blend = 1 - math.exp(-dt * (grounded ? 18 : 6));
    velocity.x += (directionVector.x * speed - velocity.x) * blend;
    velocity.z += (directionVector.z * speed - velocity.z) * blend;
    final count = math.max(
      1,
      (math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z) * dt / .06)
          .ceil(),
    );
    for (var i = 0; i < count; i++) {
      final step = dt / count;
      final before = feet.clone();
      final climb = grounded && velocity.y <= 0 ? stepHeight : 0.0;
      feet.x += velocity.x * step;
      feet.z += velocity.z * step;
      // Repeat to settle corners shared by adjacent boxes.
      for (var pass = 0; pass < 2; pass++) {
        world.resolve(feet, step: climb);
      }
      var floor = world.supportAt(feet.x, feet.z, feet.y + climb);
      // Dry-land prototype: keep the coastline and very steep slopes closed.
      final blockedHeadroom =
          floor > feet.y &&
          floor + bodyHeight >
              world.ceilingAt(feet.x, feet.z, feet.y + bodyHeight);
      if (floor < -.2 || floor > feet.y + climb + .001 || blockedHeadroom) {
        feet.x = before.x;
        feet.z = before.z;
        floor = world.supportAt(feet.x, feet.z, feet.y + climb);
      }
      if (grounded && floor >= feet.y - .06 && floor <= feet.y + climb) {
        feet.y = floor;
        velocity.y = 0;
      } else {
        grounded = false;
        final oldY = feet.y;
        velocity.y -= 18 * step;
        var nextY = oldY + velocity.y * step;
        if (velocity.y > 0) {
          final roof = world.ceilingAt(feet.x, feet.z, oldY + bodyHeight);
          if (nextY + bodyHeight >= roof) {
            nextY = roof - bodyHeight;
            velocity.y = 0;
          }
        } else {
          final landing = world.supportAt(feet.x, feet.z, oldY + .002);
          if (nextY <= landing && oldY >= landing - .002) {
            nextY = landing;
            velocity.y = 0;
            grounded = true;
            landed = true;
            landings++;
          }
        }
        feet.y = nextY;
      }
      if (grounded) {
        travelled += math.sqrt(
          math.pow(feet.x - before.x, 2) + math.pow(feet.z - before.z, 2),
        );
        safe.setFrom(feet);
      }
    }
    if (feet.y < -5) {
      feet.setFrom(safe);
      reset();
    }
  }
}
