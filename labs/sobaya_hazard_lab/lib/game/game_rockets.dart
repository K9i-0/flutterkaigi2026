part of 'game_state.dart';

class HazardRocket {
  HazardRocket(this.targetId, this.position, this.direction);
  final int targetId;
  final vm.Vector3 position;
  vm.Vector3 direction;
  double age = 0;
}

class RocketBlast {
  RocketBlast(this.position);
  final vm.Vector3 position;
  double age = 0;
}

extension HazardRocketCombat on HazardGameState {
  /// Uses the actual camera frustum, then both camera and muzzle visibility.
  /// The closest target to screen centre wins; walls cannot be locked through.
  void updateRocketLock(
    vm.Vector3 eye,
    vm.Vector3 forward, {
    required double fovY,
    required double aspect,
  }) {
    rocketLockId = null;
    if (weapon != 'rocket' || !hasRocket || !running || !aiming) return;
    final f = forward.normalized();
    final right = f.cross(vm.Vector3(0, 1, 0)).normalized();
    final up = right.cross(f).normalized();
    final tanY = math.tan(fovY / 2), tanX = tanY * aspect;
    final muzzle = rocketMuzzle ?? vm.Vector3(x, y + 1.25, z);
    var best = double.infinity;
    for (final e in enemies.where((e) => e.alive && e.active)) {
      final point = vm.Vector3(e.x, e.y + e.targetHeight, e.z);
      final to = point - eye, depth = to.dot(f);
      if (depth <= .1 || to.length > 60) continue;
      final sx = to.dot(right) / (depth * tanX);
      final sy = to.dot(up) / (depth * tanY);
      if (sx.abs() > .96 || sy.abs() > .96) continue;
      final barrel = point - muzzle;
      if (wallDistance(eye, to.normalized(), to.length) < to.length - .15 ||
          wallDistance(muzzle, barrel.normalized(), barrel.length) <
              barrel.length - .15) {
        continue;
      }
      final score = sx * sx + sy * sy + depth * .0001;
      if (score < best) {
        best = score;
        rocketLockId = e.id;
      }
    }
  }

  void launchRocket() {
    if (!hasRocket) return;
    final target = enemies
        .where((e) => e.id == rocketLockId && e.alive && e.active)
        .firstOrNull;
    if (target == null) {
      say('画面内のそば屋にロックオンしてから発射');
      return;
    }
    final start = (rocketMuzzle ?? vm.Vector3(x, y + 1.25, z)).clone();
    final direction =
        (vm.Vector3(target.x, target.y + target.targetHeight, target.z) - start)
            .normalized();
    if (wallDistance(start, direction, .6) < .6) return;
    rockets.add(HazardRocket(target.id, start, direction));
    shots++;
    noiseTime = 4;
    fireCooldown = 1.25;
    recoil = .22;
    emitSound('rocket_launch');
  }

  void tickRockets(double dt) {
    for (final b in rocketBlasts) {
      b.age += dt;
    }
    rocketBlasts.removeWhere((b) => b.age > .55);
    for (final r in List<HazardRocket>.of(rockets)) {
      r.age += dt;
      final target = enemies
          .where((e) => e.id == r.targetId && e.alive && e.active)
          .firstOrNull;
      final goal = target == null
          ? null
          : vm.Vector3(target.x, target.y + target.targetHeight, target.z);
      final to = goal == null ? null : goal - r.position;
      // A bounded flight speed and swept segment avoid frame-dependent tunnelling.
      if (to != null && to.length > .001) r.direction = to.normalized();
      final travel = math.min(14 * dt, to?.length ?? double.infinity);
      final wall = wallDistance(r.position, r.direction, travel);
      final hitWall = wall < travel - .001;
      r.position.add(r.direction * wall);
      final hitTarget = !hitWall && to != null && to.length <= travel + .25;
      if (hitWall || hitTarget || r.age > 5) {
        rockets.remove(r);
        rocketBlasts.add(RocketBlast(r.position.clone()));
        emitSound(
          'rocket_blast',
          x: r.position.x,
          y: r.position.y,
          z: r.position.z,
        );
        if (hitTarget && target != null) {
          hits++;
          hitFlash = .2;
          shotEnd = r.position.clone();
          target.alerted = true;
          target.hp = math.max(
            0,
            target.hp - (target.boss ? 300 : target.maxHp),
          );
          if (target.hp == 0) _defeat(target, suppressBeer: true);
        }
      }
    }
  }
}
