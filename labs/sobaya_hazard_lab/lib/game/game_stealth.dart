part of 'game_state.dart';

/// Suspicion and sound investigation do not grant knowledge of the player.
enum EnemyAwareness { idle, suspicious, investigating, chasing, searching }

class HazardNoise {
  HazardNoise(this.serial, this.kind, this.x, this.y, this.z, this.radius);
  final int serial;
  final String kind;
  final double x, y, z, radius;
  double remaining = .65;
}

extension HazardStealth on HazardGameState {
  double get movementNoiseRadius => evadeTime > 0
      ? 7
      : sneaking
      ? .7
      : sprint
      ? 9
      : 4;
  double enemySightRange(Enemy e) => e.boss
      ? 18
      : e.alerted
      ? 17
      : sneaking
      ? 10
      : 13;
  double enemySightHalfAngle(Enemy e) => e.boss
      ? math.pi * .48
      : e.alerted
      ? math.pi * .39
      : math.pi * .31;

  /// The same obstacle ray test drives perception and the displayed cone.
  List<vm.Vector2> enemySightPolygon(Enemy e) {
    final result = <vm.Vector2>[vm.Vector2(e.x, e.z)];
    final half = enemySightHalfAngle(e), range = enemySightRange(e);
    final origin = vm.Vector3(e.x, e.y + 1.35 * e.modelScale, e.z);
    for (var i = 0; i <= 14; i++) {
      final angle = e.heading - half + half * 2 * i / 14;
      final direction = vm.Vector3(math.sin(angle), 0, math.cos(angle));
      final distance = wallDistance(origin, direction, range);
      result.add(
        vm.Vector2(e.x + direction.x * distance, e.z + direction.z * distance),
      );
    }
    return result;
  }

  bool _sightLineClear(vm.Vector3 from, vm.Vector3 to) {
    final delta = to - from;
    return delta.length < .01 ||
        wallDistance(from, delta.normalized(), delta.length) >=
            delta.length - .08;
  }

  bool _enemyPlayerLineClear(Enemy e) => _sightLineClear(
    vm.Vector3(e.x, e.y + 1.35 * e.modelScale, e.z),
    vm.Vector3(x, y + (sneaking ? .9 : 1.15), z),
  );

  bool enemyCanSeePlayer(Enemy e) {
    final dx = x - e.x, dz = z - e.z;
    final distance = math.sqrt(dx * dx + dz * dz);
    if (distance > enemySightRange(e)) return false;
    // No omnidirectional proximity alarm: the rear remains safe even nearby.
    final facing = distance < .01
        ? 1.0
        : (dx * math.sin(e.heading) + dz * math.cos(e.heading)) / distance;
    if (facing < math.cos(enemySightHalfAngle(e))) return false;
    return _enemyPlayerLineClear(e);
  }

  void _updatePlayerDiscovery(Enemy e) {
    final from = vm.Vector3(x, y + 1.5, z);
    final forward = vm.Vector3(
      -math.sin(yaw) * math.cos(pitch),
      -math.sin(pitch),
      -math.cos(yaw) * math.cos(pitch),
    );
    final right = forward.cross(vm.Vector3(0, 1, 0)).normalized();
    final up = right.cross(forward).normalized();
    final tanY = math.tan((aiming ? 42 : 53) * math.pi / 360);
    bool visible(vm.Vector3 target) {
      final delta = target - from;
      final depth = delta.dot(forward);
      final inFrustum =
          depth > .05 &&
          delta.dot(right).abs() < depth * tanY * viewAspect.clamp(.2, 5) &&
          delta.dot(up).abs() < depth * tanY;
      // A visible head above cover is enough, but its own sample must pass
      // both tests: a blocked torso on screen cannot borrow an offscreen head.
      return delta.length < 24 &&
          (enemyVisibleInView?.call(target) ?? inFrustum) &&
          _sightLineClear(from, target);
    }

    e.visibleToPlayer =
        visible(vm.Vector3(e.x, e.y + e.targetHeight, e.z)) ||
        visible(e.headCentre ?? vm.Vector3(e.x, e.y + e.headHeight, e.z));
    if (!e.visibleToPlayer) return;
    e.discovered = true;
    e.lastSeenByPlayerX = e.x;
    e.lastSeenByPlayerY = e.y;
    e.lastSeenByPlayerZ = e.z;
    e.lastSeenByPlayerHeading = e.heading;
  }

  void clearStealthNoise() {
    _noiseEvents.clear();
    _noiseFootDistance = 0;
    playerNoiseRadius = playerNoiseTime = 0;
  }

  /// Sound is an event at its original world location, never a player beacon.
  void emitNoise(
    String kind, {
    required double radius,
    double? sourceX,
    double? sourceY,
    double? sourceZ,
  }) {
    if (!radius.isFinite || radius <= 0) return;
    _noiseEvents.add(
      HazardNoise(
        ++_noiseSerial,
        kind,
        sourceX ?? x,
        sourceY ?? y + .6,
        sourceZ ?? z,
        radius,
      ),
    );
    if (_noiseEvents.length > 24) _noiseEvents.removeAt(0);
    playerNoiseRadius = math.max(
      playerNoiseTime > 0 ? playerNoiseRadius : 0,
      radius,
    );
    playerNoiseTime = .8;
  }

  void _tickNoise(double dt) {
    playerNoiseTime = math.max(0, playerNoiseTime - dt);
    if (playerNoiseTime == 0) playerNoiseRadius = 0;
    for (final noise in _noiseEvents) {
      noise.remaining -= dt;
    }
    _noiseEvents.removeWhere((noise) => noise.remaining <= 0);
  }

  void _emitMovementNoise(double distance) {
    if (distance < .0001) return;
    _noiseFootDistance += distance;
    final stride = sneaking && evadeTime <= 0 ? .35 : .55;
    if (_noiseFootDistance < stride) return;
    _noiseFootDistance %= stride;
    emitNoise(
      evadeTime > 0
          ? 'roll'
          : sneaking
          ? 'sneak'
          : sprint
          ? 'sprint'
          : 'walk',
      radius: movementNoiseRadius,
    );
  }

  double _perceivedNoiseStrength(Enemy e, HazardNoise noise) {
    final from = vm.Vector3(noise.x, noise.y, noise.z);
    final to = vm.Vector3(e.x, e.y + 1.2, e.z), delta = to - from;
    final distance = delta.length;
    var radius = noise.radius;
    if ((noise.y - (e.y + .6)).abs() > 2) radius *= .6;
    if (distance < .01) return radius / .01;
    var walls = 0;
    for (final obstacle in collisionObstacles) {
      if (obstacle.id == 'gate' && gateOpen) continue;
      if (obstacle.ray(from, delta.normalized(), distance) != null) walls++;
    }
    // A single wall muffles footsteps; a gunshot remains audible nearby.
    radius *= math.pow(.48, math.min(walls, 3));
    // The ratio is 1 at the hearing threshold and grows for stronger sources
    // and shorter distances. Cover affects both audibility and prioritization.
    return distance <= radius ? radius / distance : 0;
  }

  void _rememberPosition(Enemy e, double px, double py, double pz) {
    if (e.lastKnownX == null ||
        math.pow(px - e.lastKnownX!, 2) + math.pow(pz - e.lastKnownZ!, 2) >
            .25 ||
        (py - e.lastKnownY!).abs() > .3) {
      e.memoryFlowTime = 0;
    }
    e.lastKnownX = px;
    e.lastKnownY = py;
    e.lastKnownZ = pz;
    e.contactAge = 0;
    e.searchTime = 0;
  }

  void _rememberAttack(Enemy e) {
    e.alerted = true;
    _rememberPosition(e, x, y, z);
  }

  void _disengage(Enemy e) {
    e.alerted = false;
    e.notice = 0;
    e.seesPlayer = false;
    e.lastKnownX = e.lastKnownY = e.lastKnownZ = null;
    e.memoryNavigation = null;
    e.contactAge = e.searchTime = 0;
    e.approachX = e.approachZ = null;
    e.approachHeading = null;
    e.attackPending = e.grabPending = false;
    e.companionTarget = null;
    e.windup = 0;
  }

  bool _updateEnemyPerception(Enemy e, double dt, double distance) {
    // Existing encounter/scenario initialization and old checkpoints use alerted.
    if (e.alerted && e.lastKnownX == null) {
      _rememberPosition(e, x, y, z);
      if (!e.attackPending && e.climb == null && e.vault == null) {
        e.heading = math.atan2(x - e.x, z - e.z);
      }
    }
    e.contactAge += dt;
    e.seesPlayer = enemyCanSeePlayer(e);
    HazardNoise? heard;
    var strongest = 0.0;
    for (final noise in _noiseEvents) {
      if (noise.serial <= e.heardNoiseSerial) continue;
      final strength = _perceivedNoiseStrength(e, noise);
      if (strength > strongest) {
        heard = noise;
        strongest = strength;
      }
    }
    // Consume the entire batch, including quieter events: otherwise the next
    // tick would replace a gunshot's location with its already-heard impact.
    e.heardNoiseSerial = _noiseSerial;
    if (heard != null && !e.seesPlayer) {
      _rememberPosition(
        e,
        heard.x,
        floorHeight(heard.x, heard.z, heard.y),
        heard.z,
      );
      e.awareness = e.alerted
          ? EnemyAwareness.chasing
          : EnemyAwareness.investigating;
      e.hasBeenAlerted = true;
      e.notice = math.max(e.notice, .15);
    }
    if (e.seesPlayer) {
      _rememberPosition(e, x, y, z);
      // Sprinting in sight is obvious; cautious movement at range buys time.
      final rate = distance < 3
          ? 4.5
          : sprint && !sneaking
          ? 3.4
          : sneaking
          ? 1.1
          : 2.1;
      e.notice = (e.notice + dt * rate).clamp(0.0, 1.0);
      if (e.alerted || e.notice >= 1) {
        e.alerted = true;
        e.awareness = EnemyAwareness.chasing;
      } else {
        e.awareness = EnemyAwareness.suspicious;
        return false;
      }
    } else {
      e.notice = math.max(0, e.notice - dt * .65);
      if (e.awareness == EnemyAwareness.suspicious && e.notice == 0) {
        e.awareness = EnemyAwareness.investigating;
      }
      if (e.alerted && e.contactAge > 2.2) {
        e.awareness = EnemyAwareness.searching;
      }
      if (e.awareness == EnemyAwareness.searching &&
          e.lastKnownX != null &&
          math.pow(e.lastKnownX! - e.x, 2) + math.pow(e.lastKnownZ! - e.z, 2) <
              .8 * .8 &&
          (e.lastKnownY! - e.y).abs() < .8) {
        e.searchTime += dt;
      }
      final companionContact = e.companionTarget != null;
      if (!e.boss &&
          !companionContact &&
          e.climb == null &&
          e.vault == null &&
          !e.attackPending &&
          ((e.contactAge > 3 && distance > 19) ||
              e.contactAge > 18 ||
              e.searchTime > 5)) {
        _disengage(e);
        return false;
      }
    }
    return e.alerted ||
        e.awareness == EnemyAwareness.investigating ||
        e.awareness == EnemyAwareness.searching;
  }

  EnemyNavigation? _memoryNavigation(Enemy e, double dt) {
    if (e.lastKnownX == null) return null;
    e.memoryFlowTime -= dt;
    final flow = e.memoryNavigation ??= prepareNavigation().fork();
    if (e.memoryFlowTime <= 0) {
      e.memoryFlowTime = 1.2;
      flow.update(
        e.lastKnownX!,
        e.lastKnownY!,
        e.lastKnownZ!,
        (px, pz, py) =>
            (!gateOpen &&
                collisionObstacles.any(
                  (o) => o.id == 'gate' && o.overlaps(px, pz, .37, py),
                )) ||
            crates.any(
              (c) =>
                  !c.broken &&
                  py < 1 &&
                  (c.x - px).abs() < .82 &&
                  (c.z - pz).abs() < .82,
            ),
      );
    }
    return flow;
  }

  Enemy? get stealthTarget {
    if (!running ||
        actionLocked ||
        aiming ||
        reloading > 0 ||
        evadeTime > 0 ||
        kickTime > 0 ||
        hurtTime > .2) {
      return null;
    }
    Enemy? nearest;
    var best = 1.6;
    for (final e in enemies) {
      if (!e.alive ||
          !e.active ||
          e.boss ||
          e.alerted ||
          e.notice > .3 ||
          e.attackPending ||
          e.climb != null ||
          e.vault != null ||
          e.stun > 0 ||
          (e.y - y).abs() > .55) {
        continue;
      }
      final dx = x - e.x, dz = z - e.z;
      final distance = math.sqrt(dx * dx + dz * dz);
      if (distance < .4 ||
          distance >= best ||
          (dx * math.sin(e.heading) + dz * math.cos(e.heading)) / distance >
              -.6 ||
          !_reachable(e.x, e.z)) {
        continue;
      }
      nearest = e;
      best = distance;
    }
    return nearest;
  }

  void stealthKill() {
    final target = stealthTarget;
    if (target == null) return;
    heading = math.atan2(target.x - x, target.z - z);
    target.hp = 0;
    _defeat(target, suppressBeer: true);
    emitNoise(
      'beer_break',
      radius: 2.4,
      sourceX: target.x,
      sourceY: target.y + 1,
      sourceZ: target.z,
    );
    emitSound('break', x: target.x, y: target.y + 1, z: target.z, loudness: .6);
    hitFlash = .18;
    checkpointRequested = true;
    say('ステルス成功 — ビールを破壊してそば屋を倒した');
    interaction = null;
  }

  Map<String, Object?> inspectEnemyPerception(Enemy e) => {
    'awareness': e.awareness.name,
    'seesPlayer': e.seesPlayer,
    'discovered': e.discovered,
    'visibleToPlayer': e.visibleToPlayer,
    'notice': e.notice,
    'contactAge': e.contactAge,
    'lastKnown': e.lastKnownX == null
        ? null
        : [e.lastKnownX, e.lastKnownY, e.lastKnownZ],
    'lastSeenByPlayer': e.lastSeenByPlayerX == null
        ? null
        : [e.lastSeenByPlayerX, e.lastSeenByPlayerY, e.lastSeenByPlayerZ],
    'sightRange': enemySightRange(e),
    'sightHalfAngle': enemySightHalfAngle(e),
    'heading': e.heading,
  };

  Map<String, Object?> inspectStealth() => {
    'sneaking': sneaking,
    'movementNoiseRadius': movementNoiseRadius,
    'playerNoiseRadius': playerNoiseRadius,
    'playerNoiseTime': playerNoiseTime,
    'target': stealthTarget?.id,
    'sounds': [
      for (final n in _noiseEvents)
        {
          'kind': n.kind,
          'position': [n.x, n.y, n.z],
          'radius': n.radius,
        },
    ],
  };
}
