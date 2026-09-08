part of 'game_state.dart';

/// Suspicion and sound investigation do not grant knowledge of the player.
enum EnemyAwareness {
  idle,
  suspicious,
  investigating,
  chasing,
  searching,
  returning,
}

/// One contract shared by the HUD, music and inspection harness.
class StealthFeedback {
  const StealthFeedback({
    required this.phase,
    this.remaining = 0,
    this.duration = 0,
    this.suspicion = 0,
    this.bearing,
    this.reason = '',
  });
  final String phase, reason;
  final double remaining, duration, suspicion;
  final double? bearing;
}

class HazardNoise {
  HazardNoise(
    this.serial,
    this.kind,
    this.x,
    this.y,
    this.z,
    this.radius,
    this.time,
  );
  final int serial;
  final String kind;
  final double x, y, z, radius, time;
  int? lureInvestigator;
  bool lureAssigned = false;
  double remaining = .65;
}

extension HazardStealth on HazardGameState {
  double get movementNoiseRadius => sneaking
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
      final distance = sightDistance(origin, direction, range);
      result.add(
        vm.Vector2(e.x + direction.x * distance, e.z + direction.z * distance),
      );
    }
    return result;
  }

  bool _sightLineClear(vm.Vector3 from, vm.Vector3 to) {
    final delta = to - from;
    return delta.length < .01 ||
        sightDistance(from, delta.normalized(), delta.length) >=
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
        time,
      ),
    );
    if (_noiseEvents.length > 24) _noiseEvents.removeAt(0);
    // A thrown mug makes noise at its landing, not around the player's feet.
    if (kind == 'beer_lure') return;
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
    final stride = sneaking ? .35 : .55;
    if (_noiseFootDistance < stride) return;
    _noiseFootDistance %= stride;
    emitNoise(
      sneaking
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
    for (final obstacle in perceptionObstacles) {
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
      e.searchPlanRetry = 0;
    }
    e.lastKnownX = px;
    e.lastKnownY = py;
    e.lastKnownZ = pz;
    e.contactAge = 0;
  }

  void _emitEnemyFootstep(Enemy e) {
    e.footDistance += e.moved;
    final stride = e.awareness == EnemyAwareness.chasing ? .75 : .6;
    if (e.footDistance < stride) return;
    e.footDistance %= stride;
    emitSound(
      'enemy_step',
      x: e.x,
      y: e.y + .1,
      z: e.z,
      loudness: e.awareness == EnemyAwareness.chasing ? 1 : .7,
    );
  }

  double _searchLength(Enemy e, {bool gunfire = false}) =>
      (gunfire ? 20.0 : 14.0) + (e.id % 3 - 1);

  void _startSearchClock(Enemy e, {bool gunfire = false}) {
    e.searchDuration =
        1.8 +
        _searchLength(
          e,
          gunfire: gunfire || e.alerted && e.searchDuration > 18,
        );
    e.searchRemaining = e.searchDuration;
    e.pursuitRemaining = e.alerted ? 1.8 : 0;
    e.searchTime = e.weakNoiseExtension = 0;
    e.returnRemaining = 0;
  }

  void _rememberAttack(Enemy e) {
    e.investigationTarget = null;
    e.lureAttention = e.lureHold = 0;
    e.alerted = true;
    // Being hit provides the attack origin once. It is not a persistent beacon.
    _rememberPosition(e, x, y, z);
    e.knowledgeSource = 'attack';
    e.knowledgeTime = time;
    e.uncertainty = 0;
    e.hadVisualContact = true;
    e.feedbackReason = '攻撃で気づかれた';
    _startSearchClock(e, gunfire: weapon != 'beer');
    e.searchPoints.clear();
  }

  void _disengage(Enemy e) {
    e.alerted = false;
    e.notice = 0;
    e.seesPlayer = false;
    e.lastKnownX = e.lastKnownY = e.lastKnownZ = null;
    e.memoryNavigation = null;
    e.contactAge = e.searchTime = e.searchRemaining = e.searchDuration = 0;
    e.approachX = e.approachZ = null;
    e.approachHeading = null;
    e.attackPending = e.grabPending = false;
    e.companionTarget = null;
    e.windup = 0;
    e.searchPoints.clear();
    e.investigationTarget = null;
    e.lureAttention = e.lureHold = 0;
    e.hadVisualContact = false;
    e.returnRemaining = 0;
    e.returnTarget = null;
  }

  void _returnHome(Enemy e) {
    _disengage(e);
    e.awareness = EnemyAwareness.returning;
    e.returnRemaining = 8;
    e.feedbackReason = '追跡を振り切った';
    e.patrolIndex = 0;
    e.patrolWait = 3;
    e.memoryFlowTime = 0;
  }

  vm.Vector3 _navigationTarget(Enemy e) {
    if (e.awareness == EnemyAwareness.returning) {
      if (e.returnTarget != null) return e.returnTarget!;
      final homeY = floorHeight(e.homeX, e.homeZ, 0);
      if (blocked(e.homeX, e.homeZ, homeY, radius: e.collisionRadius)) {
        final nearby = prepareNavigation().nearest(
          e.homeX,
          homeY,
          e.homeZ,
          blocked: (px, pz, py) =>
              blocked(px, pz, py, radius: e.collisionRadius),
        );
        if (nearby != null) return vm.Vector3(nearby.x, nearby.y, nearby.z);
      }
      return vm.Vector3(e.homeX, homeY, e.homeZ);
    }
    if (e.seesPlayer && e.searchRole != 'pursuer' && e.lastKnownX != null) {
      final side = e.searchRole == 'flanker' ? 3.0 : -4.0;
      final angle = math.atan2(e.lastKnownX! - e.x, e.lastKnownZ! - e.z);
      final px = e.lastKnownX! + math.cos(angle) * side;
      final pz = e.lastKnownZ! - math.sin(angle) * side;
      final p = prepareNavigation().nearest(px, e.lastKnownY!, pz);
      if (p != null) return vm.Vector3(p.x, p.y, p.z);
    }
    if (e.investigationTarget != null) return e.investigationTarget!;
    if (e.searchPoints.isNotEmpty &&
        e.searchIndex < e.searchPoints.length &&
        e.pursuitRemaining <= 0) {
      return e.searchPoints[e.searchIndex];
    }
    return vm.Vector3(
      e.lastKnownX ?? e.x,
      e.lastKnownY ?? e.y,
      e.lastKnownZ ?? e.z,
    );
  }

  void _buildSearchPoints(Enemy e) {
    if (e.lastKnownX == null) return;
    final centre = vm.Vector3(e.lastKnownX!, e.lastKnownY!, e.lastKnownZ!);
    final candidates = <vm.Vector3>[centre];
    final radius = math.max(2.5, e.uncertainty + 1);
    // The previous observed direction and known geometry determine these
    // guesses; none is based on the hidden player's current position.
    for (final turn in [0.0, -.85, .85, -1.8, 1.8]) {
      final a = e.observedHeading + turn;
      candidates.add(
        vm.Vector3(
          centre.x + math.sin(a) * radius,
          centre.y,
          centre.z + math.cos(a) * radius,
        ),
      );
    }
    final nearbyCorners = <vm.Vector3>[];
    for (final o in perceptionObstacles) {
      if (o.top < centre.y + 1.2 || o.bottom > centre.y + 1.5) continue;
      for (final sx in [-1.0, 1.0]) {
        for (final sz in [-1.0, 1.0]) {
          final p = vm.Vector3(
            o.x + sx * (o.w / 2 + .7),
            centre.y,
            o.z + sz * (o.d / 2 + .7),
          );
          if ((p - centre).length < 5.5) nearbyCorners.add(p);
        }
      }
    }
    nearbyCorners.sort(
      (a, b) => (a - centre).length2.compareTo((b - centre).length2),
    );
    candidates.insertAll(1, nearbyCorners.take(3));
    e.searchPoints.clear();
    final nav = prepareNavigation();
    for (final c in candidates) {
      final p = nav.nearest(
        c.x,
        c.y,
        c.z,
        blocked: (px, pz, py) => blocked(px, pz, py, radius: .4),
      );
      if (p == null) continue;
      final point = vm.Vector3(p.x, p.y, p.z);
      if (e.searchPoints.any((other) => (other - point).length < 1)) continue;
      e.searchPoints.add(point);
      if (e.searchPoints.length == 6) break;
    }
    e.searchIndex = 0;
    e.pointTime = e.lookTime = 0;
    e.memoryFlowTime = 0;
    // An unreachable or boxed-in cue may have no usable candidates. Do not
    // rebuild its geometry every frame; retry after changes can have occurred.
    e.searchPlanRetry = e.searchPoints.isEmpty ? 1 : 0;
  }

  void _advanceSearchPoint(Enemy e, double dt) {
    if (e.pursuitRemaining > 0 || e.lastKnownX == null) return;
    e.searchPlanRetry = math.max(0, e.searchPlanRetry - dt);
    if (e.searchPoints.isEmpty && e.searchPlanRetry == 0) _buildSearchPoints(e);
    if (e.searchPoints.isEmpty) return;
    e.pointTime += dt;
    final target = _navigationTarget(e);
    final reached =
        math.pow(target.x - e.x, 2) + math.pow(target.z - e.z, 2) < .75 * .75 &&
        (target.y - e.y).abs() < .8;
    if (reached) e.lookTime += dt;
    // A blocked candidate is abandoned. Arrival never controls the expiry clock.
    if (e.lookTime > 1.1 || e.pointTime > 3.5) {
      e.searchIndex++;
      e.pointTime = e.lookTime = 0;
      e.memoryFlowTime = 0;
      if (e.searchIndex >= e.searchPoints.length) {
        e.searchIndex = e.searchPoints.length - 1;
        e.lookTime = 1.2;
      }
    }
  }

  vm.Vector3 _heardLocation(Enemy e, HazardNoise sound, double strength) {
    final clear = _sightLineClear(
      vm.Vector3(sound.x, sound.y, sound.z),
      vm.Vector3(e.x, e.y + 1.2, e.z),
    );
    e.uncertainty = clear ? (strength > 4 ? .75 : 1.8) : 3.2;
    // Quantized acoustic regions retain one stable biased estimate per listener.
    // Repeated footsteps cannot be averaged into a precise hidden location.
    final cell = e.uncertainty;
    final cx = (sound.x / cell).floor(), cz = (sound.z / cell).floor();
    final angle = ((e.id * 97 + cx * 31 + cz * 17) % 360) * math.pi / 180;
    var px = (cx + .5) * cell + math.sin(angle) * cell * .3;
    var pz = (cz + .5) * cell + math.cos(angle) * cell * .3;
    px = px.clamp(-22.0, 22.0);
    pz = pz.clamp(-24.0, 29.5);
    final py = floorHeight(px, pz, sound.y);
    final p = prepareNavigation().nearest(
      px,
      py,
      pz,
      blocked: (px, pz, py) => blocked(px, pz, py, radius: .4),
    );
    return p == null ? vm.Vector3(px, py, pz) : vm.Vector3(p.x, p.y, p.z);
  }

  bool _isGunfire(String kind) =>
      const ['handgun', 'shotgun', 'rocket', 'explosion'].contains(kind);

  void _hearNoise(Enemy e, HazardNoise heard, double strength) {
    if (heard.kind == 'beer_lure') {
      if (e.boss) return;
      // A bottle visibly landing is a real object, not knowledge of its thrower.
      e.investigationTarget = vm.Vector3(
        heard.x,
        floorHeight(heard.x, heard.z, heard.y),
        heard.z,
      );
      e.lureAttention = 5;
      e.lureHold = 0;
      e.memoryFlowTime = 0;
      e.searchRemaining = e.searchDuration = 10;
      e.pursuitRemaining = 0;
      e.awareness = EnemyAwareness.investigating;
      e.attackPending = e.grabPending = false;
      e.companionTarget = null;
      e.windup = 0;
      e.knowledgeSource = 'beer_lure';
      e.knowledgeTime = heard.time;
      e.feedbackReason = 'ビールに夢中 — 今のうちに隠れろ';
      e.hasBeenAlerted = true;
      return;
    }
    final gunfire = _isGunfire(heard.kind);
    final continuing =
        e.searchRemaining > 0 && e.awareness != EnemyAwareness.returning;
    final p = _heardLocation(e, heard, strength);
    final changedRegion =
        e.lastKnownX == null ||
        math.pow(p.x - e.lastKnownX!, 2) + math.pow(p.z - e.lastKnownZ!, 2) >
            .5;
    _rememberPosition(e, p.x, p.y, p.z);
    e.knowledgeSource = heard.kind;
    e.knowledgeTime = heard.time;
    e.investigationTarget = null;
    e.lureAttention = e.lureHold = 0;
    if (changedRegion) e.searchPoints.clear();
    if (!continuing || gunfire) {
      _startSearchClock(e, gunfire: gunfire);
    } else {
      final strongStep = heard.kind == 'sprint';
      final extension = strongStep
          ? 1.0
          : math.min(.65, 4 - e.weakNoiseExtension);
      if (!strongStep) e.weakNoiseExtension += extension;
      e.searchRemaining = math.min(
        e.searchDuration + 4,
        e.searchRemaining + extension,
      );
    }
    e.awareness = e.alerted
        ? EnemyAwareness.searching
        : EnemyAwareness.investigating;
    e.hasBeenAlerted = true;
    e.notice = math.max(e.notice, .15);
    e.feedbackReason = gunfire ? '新しい銃声' : '足音を聞かれた';
  }

  void _assignPursuitRole(Enemy e) {
    final peers = enemies
        .where(
          (other) =>
              other.active &&
              other.alive &&
              !other.boss &&
              other.alerted &&
              other.lastKnownX != null &&
              math.pow(other.lastKnownX! - e.lastKnownX!, 2) +
                      math.pow(other.lastKnownZ! - e.lastKnownZ!, 2) <
                  16 &&
              math.pow(other.x - e.x, 2) + math.pow(other.z - e.z, 2) < 100,
        )
        .toList();
    peers.sort((a, b) {
      final da =
          math.pow(a.x - a.lastKnownX!, 2) + math.pow(a.z - a.lastKnownZ!, 2);
      final db =
          math.pow(b.x - b.lastKnownX!, 2) + math.pow(b.z - b.lastKnownZ!, 2);
      return da == db ? a.id.compareTo(b.id) : da.compareTo(db);
    });
    for (var i = 0; i < peers.length; i++) {
      peers[i].searchRole = i == 0
          ? 'pursuer'
          : i == 1
          ? 'flanker'
          : 'watcher';
    }
  }

  void _shareVisualContact(Enemy e) {
    if (e.shareCooldown > 0 || !e.alerted || !e.seesPlayer) return;
    e.shareCooldown = 1;
    final peers =
        enemies
            .where(
              (other) =>
                  other != e &&
                  !other.boss &&
                  other.active &&
                  other.alive &&
                  math.pow(other.x - e.x, 2) + math.pow(other.z - e.z, 2) <= 64,
            )
            .toList()
          ..sort(
            (a, b) => (math.pow(a.x - e.x, 2) + math.pow(a.z - e.z, 2))
                .compareTo(math.pow(b.x - e.x, 2) + math.pow(b.z - e.z, 2)),
          );
    // One nearby partner receives the original observation. Recipients never
    // relay it and a repeated timestamp cannot extend anybody's search.
    if (peers.isEmpty) return;
    final peer = peers.first;
    if (peer.seesPlayer ||
        peer.lureAttention > 0 ||
        peer.lastSharedTime >= e.knowledgeTime) {
      return;
    }
    peer.lastSharedTime = e.knowledgeTime;
    peer.alerted = true;
    _rememberPosition(peer, e.lastKnownX!, e.lastKnownY!, e.lastKnownZ!);
    peer.knowledgeSource = 'shared_sight';
    peer.knowledgeTime = e.knowledgeTime;
    peer.uncertainty = e.uncertainty;
    peer.observedHeading = e.observedHeading;
    peer.searchRole = 'flanker';
    peer.feedbackReason = '近くのそば屋が呼びかけた';
    _startSearchClock(peer);
    peer.pursuitRemaining = 0;
    _buildSearchPoints(peer);
    if (peer.searchPoints.length > 1) peer.searchIndex = 1;
    peer.awareness = EnemyAwareness.searching;
  }

  double _turnTowards(double from, double to, double maximum) {
    var delta = (to - from + math.pi) % (math.pi * 2) - math.pi;
    return from + delta.clamp(-maximum, maximum);
  }

  bool _tickHomeOrPatrol(Enemy e, double dt) {
    if (e.awareness == EnemyAwareness.returning) {
      e.returnRemaining = math.max(0, e.returnRemaining - dt);
      final target = _navigationTarget(e);
      if (math.pow(e.x - target.x, 2) + math.pow(e.z - target.z, 2) < .8 * .8 &&
          (e.y - target.y).abs() < .8) {
        e.awareness = EnemyAwareness.idle;
        e.returnRemaining = 0;
        e.heading = e.homeHeading ?? e.heading;
        e.memoryNavigation = null;
        return false;
      }
      return true;
    }
    if (e.awareness != EnemyAwareness.idle) return false;
    final authored = (map['enemies'] as List)
        .where((j) => j['id'] == e.id)
        .firstOrNull;
    final patrol = authored?['patrol'] as List?;
    if (patrol == null || patrol.isEmpty || e.stun > 0) return false;
    e.patrolWait = math.max(0, e.patrolWait - dt);
    if (e.patrolWait > 0) return false;
    final p = patrol[e.patrolIndex % patrol.length] as List;
    final tx = (p[0] as num).toDouble(), tz = (p[1] as num).toDouble();
    final dx = tx - e.x, dz = tz - e.z, distance = math.sqrt(dx * dx + dz * dz);
    if (distance < .4) {
      e.patrolIndex = (e.patrolIndex + 1) % patrol.length;
      e.patrolWait = 4 + e.id % 3;
      return false;
    }
    final wanted = math.atan2(dx, dz);
    e.heading = _turnTowards(e.heading, wanted, dt * 1.5);
    if (math.cos(e.heading - wanted) < .85) return false;
    final oldX = e.x, oldZ = e.z;
    _moveEnemy(e, dx / distance * .65 * dt, dz / distance * .65 * dt);
    e.moved = math.sqrt(math.pow(e.x - oldX, 2) + math.pow(e.z - oldZ, 2));
    _emitEnemyFootstep(e);
    return false;
  }

  bool _updateEnemyPerception(Enemy e, double dt, double distance) {
    if (e.boss) return _updateBossPerception(e, dt, distance);
    e.homeHeading ??= e.heading;
    e.contactAge += dt;
    e.shareCooldown = math.max(0, e.shareCooldown - dt);
    final previouslySeeing = e.seesPlayer;
    e.seesPlayer = enemyCanSeePlayer(e);
    HazardNoise? heard;
    var strongest = 0.0;
    HazardNoise? beer;
    var gunfire = false;
    for (final noise in _noiseEvents) {
      if (noise.serial <= e.heardNoiseSerial) continue;
      final strength = _perceivedNoiseStrength(e, noise);
      if (strength > 0) {
        if (noise.kind == 'beer_lure') beer = noise;
        if (_isGunfire(noise.kind)) gunfire = true;
      }
      if (strength > strongest) {
        heard = noise;
        strongest = strength;
      }
    }
    e.heardNoiseSerial = _noiseSerial;
    // Beer wins over pursuit and footsteps, but never over nearby danger.
    if (beer != null && !gunfire) _hearNoise(e, beer, 1);
    if (e.lureAttention > 0 && e.investigationTarget != null) {
      final danger = gunfire || (distance < 1.8 && e.seesPlayer);
      final p = e.investigationTarget!;
      e.searchRemaining = math.max(0, e.searchRemaining - dt);
      if (math.pow(p.x - e.x, 2) + math.pow(p.z - e.z, 2) < 1 &&
          (p.y - e.y).abs() < .8) {
        e.lureHold += dt;
      }
      if (!danger && e.searchRemaining > 0 && e.lureHold < e.lureAttention) {
        e.seesPlayer = false;
        e.awareness = EnemyAwareness.investigating;
        return true;
      }
      e.investigationTarget = null;
      e.lureAttention = e.lureHold = 0;
      if (!danger && !e.seesPlayer) {
        _returnHome(e);
        return _tickHomeOrPatrol(e, dt);
      }
    }
    // A consumed lure must not restart later in this same perception tick.
    if (heard?.kind == 'beer_lure') heard = null;
    if (e.seesPlayer) {
      if (e.lastKnownX != null && previouslySeeing) {
        final dx = x - e.lastKnownX!, dz = z - e.lastKnownZ!;
        if (dx * dx + dz * dz > .0001) e.observedHeading = math.atan2(dx, dz);
      } else {
        e.observedHeading = e.heading;
      }
      _rememberPosition(e, x, y, z);
      e.knowledgeSource = 'sight';
      e.knowledgeTime = e.lastVisualTime = time;
      e.uncertainty = 0;
      e.investigationTarget = null;
      e.lureAttention = e.lureHold = 0;
      final facing = distance < .01
          ? 1.0
          : ((x - e.x) * math.sin(e.heading) +
                    (z - e.z) * math.cos(e.heading)) /
                distance;
      final peripheral = facing < .72;
      final rate = distance < 3
          ? 3.6
          : sprint && !sneaking
          ? 2.8
          : sneaking || peripheral
          ? .7
          : 1.6;
      e.notice = (e.notice + dt * rate).clamp(0.0, 1.0);
      if (!e.alerted && e.notice < 1) {
        e.awareness = EnemyAwareness.suspicious;
        return false;
      }
      e.alerted = true;
      e.awareness = EnemyAwareness.chasing;
      e.hadVisualContact = true;
      _assignPursuitRole(e);
      _startSearchClock(e);
      e.searchPoints.clear();
      e.searchPlanRetry = 0;
      e.feedbackReason = '見つかっている';
      _shareVisualContact(e);
      return true;
    }
    // Legacy alerted saves without a memory investigate their own location;
    // they cannot initialize knowledge from a player hidden behind geometry.
    if (e.alerted && e.lastKnownX == null) {
      _rememberPosition(e, e.x, e.y, e.z);
      _startSearchClock(e);
    }
    if (e.alerted && e.searchDuration == 0) _startSearchClock(e);
    if (heard != null) _hearNoise(e, heard, strongest);
    e.notice = math.max(0, e.notice - dt * .5);
    if (e.searchRemaining <= 0 &&
        e.lastKnownX != null &&
        e.awareness == EnemyAwareness.suspicious) {
      _startSearchClock(e);
    }
    if (e.searchRemaining > 0) {
      e.searchRemaining = math.max(0, e.searchRemaining - dt);
      e.pursuitRemaining = math.max(0, e.pursuitRemaining - dt);
      e.searchTime += dt;
      if (e.alerted) {
        e.awareness = e.pursuitRemaining > 0
            ? EnemyAwareness.chasing
            : EnemyAwareness.searching;
      } else {
        e.awareness = EnemyAwareness.investigating;
      }
      if (e.searchRemaining == 0 && e.companionTarget == null) {
        _returnHome(e);
      } else {
        if (e.investigationTarget != null) {
          final p = e.investigationTarget!;
          final arrived = math.pow(p.x - e.x, 2) + math.pow(p.z - e.z, 2) < 1.0;
          if (arrived) {
            e.lureHold += dt;
            if (e.lureHold >= e.lureAttention) {
              e.investigationTarget = null;
              e.lureAttention = e.lureHold = 0;
              if (!e.alerted) _returnHome(e);
            }
          }
        } else {
          _advanceSearchPoint(e, dt);
        }
      }
    }
    if (e.alerted && e.searchRemaining <= 0 && e.companionTarget == null) {
      _returnHome(e);
    }
    if (e.awareness == EnemyAwareness.idle ||
        e.awareness == EnemyAwareness.returning) {
      return _tickHomeOrPatrol(e, dt);
    }
    return e.alerted ||
        e.awareness == EnemyAwareness.investigating ||
        e.awareness == EnemyAwareness.searching;
  }

  bool _updateBossPerception(Enemy e, double dt, double distance) {
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

  NavigationCollision _dynamicNavigationCollision() {
    // EnemyNavigation already rejects immutable walls, floors, refuge and NPC
    // footprints. Rechecking all of them at every BFS node multiplies work by
    // the number of guards. Only the gate and intact crates can change here.
    final gates = gateOpen || hasRefuge
        ? <Obstacle>[]
        : obstacles.where((o) => o.id == 'gate').toList();
    final intact = crates.where((c) => !c.broken).toList();
    return (px, pz, py) =>
        gates.any((o) => o.overlaps(px, pz, .37, py)) ||
        intact.any(
          (c) => py < 1 && (c.x - px).abs() < .82 && (c.z - pz).abs() < .82,
        );
  }

  EnemyNavigation? _memoryNavigation(Enemy e, double dt) {
    final target = _navigationTarget(e);
    e.memoryFlowTime -= dt;
    final flow = e.memoryNavigation ??= prepareNavigation().fork();
    if (e.memoryFlowTime <= 0) {
      e.memoryFlowTime = 1.2;
      final dynamicBlocked = _dynamicNavigationCollision();
      flow.update(target.x, target.y, target.z, dynamicBlocked);
      if (e.awareness == EnemyAwareness.returning &&
          flow.waypoint(e.x, e.y, e.z) == null) {
        // A closed gate or a new obstacle can disconnect the post. Search only
        // the guard's reachable component and choose its closest point to home.
        // This fallback never uses the last search spot as a new home.
        final origin = flow.nearest(e.x, e.y, e.z, blocked: dynamicBlocked);
        if (origin != null) {
          var best = origin;
          var score =
              math.pow(origin.x - e.homeX, 2) + math.pow(origin.z - e.homeZ, 2);
          final pending = <int>[origin.id], visited = <int>{origin.id};
          for (var i = 0; i < pending.length; i++) {
            final p = flow.points[pending[i]]!;
            final d = math.pow(p.x - e.homeX, 2) + math.pow(p.z - e.homeZ, 2);
            if (d < score) {
              best = p;
              score = d;
            }
            for (final id in p.links) {
              if (visited.contains(id)) continue;
              final q = flow.points[id]!;
              if (dynamicBlocked(q.x, q.z, q.y)) continue;
              visited.add(id);
              pending.add(id);
            }
          }
          e.returnTarget = vm.Vector3(best.x, best.y, best.z);
          flow.update(best.x, best.y, best.z, dynamicBlocked);
        }
      }
    }
    return flow;
  }

  StealthFeedback get stealthFeedback {
    final engaged = enemies.where((e) => e.alive && e.active).toList();
    final chasing = engaged
        .where((e) => e.alerted && (e.seesPlayer || e.boss && e.hasBeenAlerted))
        .toList();
    final searching = engaged
        .where((e) => !e.boss && e.alerted && e.searchRemaining > 0)
        .toList();
    final suspicious = engaged
        .where(
          (e) =>
              !e.alerted && e.notice > 0 && (e.visibleToPlayer || e.discovered),
        )
        .toList();
    final returning = engaged
        .where(
          (e) =>
              e.awareness == EnemyAwareness.returning && e.returnRemaining > 0,
        )
        .toList();
    Enemy? cue;
    String phase = 'calm';
    double remaining = 0, duration = 0, suspicion = 0;
    if (chasing.isNotEmpty) {
      phase = 'chasing';
      cue = chasing.first;
    } else if (searching.isNotEmpty) {
      searching.sort((a, b) => b.searchRemaining.compareTo(a.searchRemaining));
      phase = 'searching';
      cue = searching.first;
      remaining = cue.searchRemaining;
      duration = math.max(cue.searchDuration, remaining + cue.searchTime);
    } else if (suspicious.isNotEmpty) {
      suspicious.sort((a, b) => b.notice.compareTo(a.notice));
      phase = 'suspicious';
      cue = suspicious.first;
      suspicion = cue.notice;
    } else if (returning.isNotEmpty) {
      returning.sort((a, b) => b.returnRemaining.compareTo(a.returnRemaining));
      phase = 'returning';
      cue = returning.first;
      remaining = cue.returnRemaining;
      duration = 8;
    }
    final bearing = cue?.visibleToPlayer == true
        ? math.atan2(cue!.x - x, cue.z - z)
        : cue?.discovered == true && cue?.lastSeenByPlayerX != null
        ? math.atan2(cue!.lastSeenByPlayerX! - x, cue.lastSeenByPlayerZ! - z)
        : null;
    return StealthFeedback(
      phase: phase,
      remaining: remaining,
      duration: duration,
      suspicion: suspicion,
      bearing: bearing,
      reason: cue?.feedbackReason ?? '',
    );
  }

  Enemy? get stealthTarget {
    if (!running || actionLocked || aiming || reloading > 0 || hurtTime > .2) {
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
    'knowledgeSource': e.knowledgeSource,
    'knowledgeTime': e.knowledgeTime,
    'uncertainty': e.uncertainty,
    'searchRemaining': e.searchRemaining,
    'searchDuration': e.searchDuration,
    'searchRole': e.searchRole,
    'searchIndex': e.searchIndex,
    'searchPoints': [
      for (final p in e.searchPoints) [p.x, p.y, p.z],
    ],
    'navigationTarget': [
      _navigationTarget(e).x,
      _navigationTarget(e).y,
      _navigationTarget(e).z,
    ],
    'home': [e.homeX, e.homeZ],
    'returnRemaining': e.returnRemaining,
    'lureAttention': e.lureAttention,
    'lureHold': e.lureHold,
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
    'feedback': {
      'phase': stealthFeedback.phase,
      'remaining': stealthFeedback.remaining,
      'duration': stealthFeedback.duration,
      'reason': stealthFeedback.reason,
    },
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
