part of 'game_state.dart';

class HazardThrownBeer {
  HazardThrownBeer(this.origin, this.velocity, {this.age = 0})
    : position = origin.clone();
  final vm.Vector3 origin, velocity;
  vm.Vector3 position;
  double age;
  vm.Vector3 at(double t) =>
      origin + velocity * t - vm.Vector3(0, 4.9 * t * t, 0);
}

class BeerSplash {
  BeerSplash(this.position);
  final vm.Vector3 position;
  double age = 0;
}

class BeerThrowPlan {
  BeerThrowPlan(
    this.origin,
    this.velocity,
    this.points,
    this.landing,
    this.duration,
    this.wallHit,
  );
  final vm.Vector3 origin, velocity, landing;
  final List<vm.Vector3> points;
  final double duration;
  final bool wallHit;
}

extension HazardBeerThrow on HazardGameState {
  void restoreBeerFlights(List<dynamic> rows) {
    if (rows.length > 4) throw const FormatException('Too many thrown beers');
    vm.Vector3 vector(dynamic row, double limit) {
      if (row is! List ||
          row.length != 3 ||
          row.any((v) => v is! num || !v.isFinite || v.abs() > limit)) {
        throw const FormatException('Invalid beer trajectory');
      }
      return vm.Vector3(
        (row[0] as num).toDouble(),
        (row[1] as num).toDouble(),
        (row[2] as num).toDouble(),
      );
    }

    for (final row in rows) {
      final age = row['age'];
      if (age is! num || !age.isFinite || age < 0 || age > 3) {
        throw const FormatException('Invalid throw age');
      }
      final b = HazardThrownBeer(
        vector(row['origin'], 60),
        vector(row['velocity'], 12),
        age: age.toDouble(),
      );
      b.position = b.at(b.age);
      beerFlights.add(b);
    }
  }

  List<String> get availableWeapons => [
    'handgun',
    if (hasShotgun) 'shotgun',
    if (beers > 0 || weapon == 'beer') 'beer',
    if (hasRocket) 'rocket',
  ];

  String get weaponLabel => switch (weapon) {
    'handgun' => 'ハンドガン',
    'shotgun' => 'ショットガン',
    'beer' => 'ビール',
    _ => 'ロケットランチュア',
  };

  void cycleWeapon() {
    final choices = availableWeapons;
    equip(choices[(choices.indexOf(weapon) + 1) % choices.length]);
  }

  vm.Vector3 get beerThrowOrigin {
    final f = vm.Vector3(-math.sin(yaw), 0, -math.cos(yaw));
    final right = vm.Vector3(-math.cos(yaw), 0, math.sin(yaw));
    return vm.Vector3(x, y + 1.25, z) + f * .36 + right * .20;
  }

  vm.Vector3 _beerVelocity(vm.Vector3 direction) {
    final horizontal = vm.Vector3(direction.x, 0, direction.z);
    if (horizontal.length2 < .001) {
      horizontal.setValues(-math.sin(yaw), 0, -math.cos(yaw));
    }
    horizontal.normalize();
    return horizontal * 6.2 +
        vm.Vector3(0, (2.8 + direction.y * 5).clamp(.8, 5.2), 0);
  }

  /// Preview and live motion use the same swept arc and floor test. Impact
  /// shatters the thrown mug, so a wall can be used as a deliberate noise source.
  ({vm.Vector3 point, bool wall})? _beerImpact(vm.Vector3 from, vm.Vector3 to) {
    final delta = to - from;
    final distance = delta.length;
    if (distance > .000001) {
      final hit = sightDistance(from, delta / distance, distance);
      if (hit < distance - .00001) {
        return (
          point: from + delta / distance * math.max(0, hit - .025),
          wall: true,
        );
      }
    }
    final floor = floorHeight(to.x, to.z, from.y);
    if (to.y <= floor + .06) {
      final fraction =
          ((from.y - floor - .06) / math.max(.00001, from.y - to.y)).clamp(
            0.0,
            1.0,
          );
      final point = from + delta * fraction;
      point.y = floor + .06;
      return (point: point, wall: false);
    }
    return null;
  }

  BeerThrowPlan planBeerThrow(vm.Vector3 direction) {
    final origin = beerThrowOrigin, velocity = _beerVelocity(direction);
    final flight = HazardThrownBeer(origin, velocity);
    final points = <vm.Vector3>[origin.clone()];
    var previous = origin;
    for (var i = 1; i <= 180; i++) {
      final seconds = i / 60;
      final next = flight.at(seconds);
      final impact = _beerImpact(previous, next);
      if (impact != null) {
        points.add(impact.point);
        return BeerThrowPlan(
          origin,
          velocity,
          points,
          impact.point,
          seconds,
          impact.wall,
        );
      }
      if (i % 4 == 0) points.add(next);
      previous = next;
    }
    return BeerThrowPlan(origin, velocity, points, previous, 3, false);
  }

  void throwBeer(vm.Vector3 direction) {
    if (!running ||
        !aiming ||
        actionLocked ||
        reloading > 0 ||
        hurtTime > .2 ||
        fireCooldown > 0) {
      return;
    }
    if (beers <= 0) {
      say('投げるビールがない。');
      emitSound('empty');
      fireCooldown = .25;
      return;
    }
    final plan = planBeerThrow(direction);
    final fromBody = plan.origin - vm.Vector3(x, y + 1.25, z);
    if (sightDistance(
          vm.Vector3(x, y + 1.25, z),
          fromBody.normalized(),
          fromBody.length,
        ) <
        fromBody.length - .01) {
      say('壁から少し離れて投げよう。');
      return;
    }
    beers--;
    beersThrown++;
    beerThrowTime = .45;
    fireCooldown = .85;
    beerFlights.add(HazardThrownBeer(plan.origin, plan.velocity));
    emitSound('beer_throw');
    checkpointRequested = true;
  }

  void tickThrownBeer(double dt) {
    beerThrowTime = math.max(0, beerThrowTime - dt);
    for (final splash in beerSplashes) {
      splash.age += dt;
    }
    beerSplashes.removeWhere((splash) => splash.age > 1.4);
    for (final flight in List<HazardThrownBeer>.of(beerFlights)) {
      final targetAge = flight.age + dt;
      var landed = false;
      while (flight.age < targetAge - .000001) {
        flight.age = math.min(targetAge, flight.age + 1 / 60);
        final next = flight.at(flight.age);
        final impact = _beerImpact(flight.position, next);
        flight.position = impact?.point ?? next;
        if (impact != null || flight.age >= 3) {
          landed = true;
          break;
        }
      }
      if (!landed) continue;
      beerFlights.remove(flight);
      beerSplashes.add(BeerSplash(flight.position.clone()));
      emitNoise(
        'beer_lure',
        radius: 8,
        sourceX: flight.position.x,
        sourceY: flight.position.y + .15,
        sourceZ: flight.position.z,
      );
      emitSound(
        'beer_land',
        x: flight.position.x,
        y: flight.position.y,
        z: flight.position.z,
      );
      checkpointRequested = true;
    }
  }
}
