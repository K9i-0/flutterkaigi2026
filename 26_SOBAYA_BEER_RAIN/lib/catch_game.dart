import 'dart:math' as math;

import 'balance.dart';
import 'character.dart';

enum Phase { ready, countdown, playing, result }

enum CanKind { superTry, light, happoshu }

enum ItemEffect { enlarge, shrink, speedUp, speedDown }

class Drop {
  Drop(
    this.id,
    this.kind,
    this.x,
    this.z,
    this.spawn, {
    this.facing = 0,
    this.fallSeconds = 3.1,
  });
  final int id;
  final CanKind kind;
  final double x, z, spawn, facing, fallSeconds;
  bool resolved = false, caught = false;
  double get landing => spawn + fallSeconds;
  double height(double time) {
    final p = ((time - spawn) / fallSeconds).clamp(0.0, 1.0);
    return resolved && !caught
        ? math.max(.35, 1.15 - (time - landing) * 4)
        : 1.15 + 4.7 * (1 - math.pow(p, 1.25));
  }

  bool visible(double time) => time >= spawn && time < landing + .65 && !caught;
}

class ItemDrop {
  ItemDrop(
    this.id,
    this.effect,
    this.x,
    this.spawn, {
    this.z = 0,
    this.fallSeconds = 3.1,
  });
  final int id;
  final ItemEffect effect;
  final double x, z, spawn, fallSeconds;
  double get landing => spawn + fallSeconds;
  double height(double time) {
    final p = ((time - spawn) / fallSeconds).clamp(0.0, 1.0);
    return 1.15 + 4.7 * (1 - math.pow(p, 1.25));
  }

  bool visible(double time) => time >= spawn && time < landing + .65;
}

class CatchGame {
  static const duration = 20.0, halfX = 3.9, halfZ = 2.8;

  /// Salt for the sobaya lane-item stream. Kept off the can RNG.
  static int itemSeed(int seed) => (seed & 0x7fffffff) ^ 0x6974656d;
  Balance balance = Balance.defaults();
  int seed = 1;
  CatchCharacter _selectedCharacter = CatchCharacter.sobaya;
  CatchCharacter get selectedCharacter => _selectedCharacter;
  CatchCharacter _roundCharacter = CatchCharacter.sobaya;
  CatchCharacter get roundCharacter => _roundCharacter;
  double _baseMoveSpeed = 2.6, _baseCatchRadius = .72;
  double get baseMoveSpeed => _baseMoveSpeed;
  double get baseCatchRadius => _baseCatchRadius;
  // Future item multipliers apply to these round bases, never to each other.
  double get moveSpeed => lane ? baseMoveSpeed : 3.5;
  double get catchRadius => lane ? baseCatchRadius : balance['catchRadius'];
  bool selectCharacter(CatchCharacter character) {
    if (phase != Phase.ready && phase != Phase.result) return false;
    _selectedCharacter = character;
    return true;
  }

  double get roundSeconds => balance['roundSeconds'];
  bool lane = false;
  Phase phase = Phase.ready;
  double time = 0,
      countdown = 0,
      x = 0,
      z = 1,
      vx = 0,
      vz = 0,
      yaw = 0,
      targetYaw = 0;
  int score = 0, combo = 0, caught = 0, bad = 0, missed = 0, eventId = 0;
  String message = 'ビールだけ、持ってこい。';
  double messageUntil = 0;
  final drops = <Drop>[];
  final items = <ItemDrop>[];
  final events = <Map<String, Object>>[];
  void start({int seed = 1}) {
    this.seed = seed;
    _roundCharacter = lane ? selectedCharacter : CatchCharacter.sobaya;
    _baseMoveSpeed = lane ? roundCharacter.moveSpeed : 3.5;
    _baseCatchRadius = lane
        ? roundCharacter.catchRadius
        : balance['catchRadius'];
    phase = Phase.countdown;
    time = 0;
    countdown = 2;
    x = 0;
    z = lane ? 0 : 1;
    vx = 0;
    vz = 0;
    yaw = 0;
    targetYaw = 0;
    score = 0;
    combo = 0;
    caught = 0;
    bad = 0;
    missed = 0;
    eventId = 0;
    events.clear();
    drops.clear();
    items.clear();
    message = 'ビールだけ、持ってこい。';
    messageUntil = 2;
    final r = math.Random(seed);
    for (
      var i = 0;
      i * balance['spawnInterval'] <= roundSeconds - balance['fallSeconds'] - 1;
      i++
    ) {
      final kind =
          ((i + 1) * balance['badRatio']).floor() >
              (i * balance['badRatio']).floor()
          ? CanKind.happoshu
          : i % 3 == 1
          ? CanKind.light
          : CanKind.superTry;
      drops.add(
        Drop(
          i,
          kind,
          (r.nextDouble() - .5) * 6.2,
          lane ? 0 : (r.nextDouble() - .5) * 4.2,
          i * balance['spawnInterval'],
          fallSeconds: balance['fallSeconds'],
          facing: lane
              ? ((r.nextDouble() < .5 ? -1 : 1) *
                    (balance['facingMin'] +
                        r.nextDouble() *
                            (balance['facingMax'] - balance['facingMin'])) *
                    math.pi /
                    180)
              : 0,
        ),
      );
    }
    if (!lane) return;
    final itemRandom = math.Random(itemSeed(seed));
    final count = 2 + itemRandom.nextInt(2);
    final latestSpawn = math.max(0.0, roundSeconds - balance['fallSeconds']);
    for (var i = 0; i < count; i++) {
      final effect =
          ItemEffect.values[itemRandom.nextInt(ItemEffect.values.length)];
      items.add(
        ItemDrop(
          i,
          effect,
          (itemRandom.nextDouble() - .5) * 6.2,
          itemRandom.nextDouble() * latestSpawn,
          fallSeconds: balance['fallSeconds'],
        ),
      );
    }
  }

  void rotate(int direction) {
    targetYaw +=
        direction.sign *
        (lane ? balance['cameraStep'] * math.pi / 180 : math.pi / 4);
    if (lane) {
      targetYaw = targetYaw.clamp(
        -balance['cameraLimit'] * math.pi / 180,
        balance['cameraLimit'] * math.pi / 180,
      );
    }
  }

  /// Input x is screen right; y is screen up (away from the camera).
  static ({double x, double z}) toWorld(double x, double y, double yaw) => (
    x: -math.cos(yaw) * x - math.sin(yaw) * y,
    z: math.sin(yaw) * x - math.cos(yaw) * y,
  );
  static ({double x, double y}) toScreen(double x, double z, double yaw) => (
    x: -math.cos(yaw) * x + math.sin(yaw) * z,
    y: -math.sin(yaw) * x - math.cos(yaw) * z,
  );
  void tick(double dt, {double inputX = 0, double inputY = 0}) {
    if (!dt.isFinite || dt <= 0 || !inputX.isFinite || !inputY.isFinite) return;
    var left = math.min(dt, .25);
    while (left > 1e-8) {
      final h = math.min(left, 1 / 60);
      left -= h;
      _step(h, inputX, inputY);
    }
  }

  void _step(double dt, double ix, double iy) {
    yaw += (targetYaw - yaw) * (1 - math.exp(-7 * dt));
    if (phase == Phase.countdown) {
      countdown -= dt;
      if (countdown <= 0) phase = Phase.playing;
      return;
    }
    if (phase != Phase.playing) return;
    time += dt;
    if (lane) iy = 0;
    final len = math.sqrt(ix * ix + iy * iy);
    if (len > 1) {
      ix /= len;
      iy /= len;
    }
    final dir = lane ? (x: -ix, z: 0.0) : toWorld(ix, iy, yaw),
        a = 1 - math.exp(-balance['acceleration'] * dt);
    vx += (dir.x * moveSpeed - vx) * a;
    vz += (dir.z * 3.5 - vz) * a;
    final previousX = x, previousZ = z;
    x = (x + vx * dt).clamp(-halfX, halfX);
    z = (z + vz * dt).clamp(-halfZ, halfZ);
    // Animation uses actual displacement, including the end stops.
    if (lane) {
      vx = (x - previousX) / dt;
      vz = (z - previousZ) / dt;
    }
    for (final d in drops) {
      if (d.resolved || time < d.landing) continue;
      d.resolved = true;
      d.caught =
          math.pow(d.x - x, 2) + math.pow(d.z - z, 2) <
          math.pow(catchRadius, 2);
      if (d.caught) {
        eventId++;
        if (d.kind == CanKind.happoshu) {
          bad++;
          score -= balance['penalty'].round();
          combo = 0;
          message = 'これ、発泡酒やないか！  −${balance['penalty'].round()}';
        } else {
          caught++;
          combo++;
          final points =
              balance['beerPoints'].round() +
              math.min(combo - 1, 4) * balance['comboBonus'].round();
          score += points;
          message = 'ナイスキャッチ！  +$points';
        }
        messageUntil = time + 1.4;
        events.add({
          'time': time,
          'id': d.id,
          'kind': d.kind.name,
          'score': score,
          'x': x,
          'z': z,
        });
      } else if (d.kind != CanKind.happoshu) {
        missed++;
        combo = 0;
      }
    }
    if (time >= roundSeconds) {
      time = roundSeconds;
      phase = Phase.result;
      vx = 0;
      vz = 0;
    }
  }

  Map<String, Object> inspect() => {
    'balance': balance.values,
    'seed': seed,
    'selectedCharacter': selectedCharacter.id,
    'roundCharacter': roundCharacter.id,
    'baseMoveSpeed': baseMoveSpeed,
    'baseCatchRadius': baseCatchRadius,
    'moveSpeed': moveSpeed,
    'catchRadius': catchRadius,
    'vx': vx,
    'vz': vz,
    'dropCount': drops.length,
    'itemCount': items.length,
    'items': items
        .map(
          (d) => {
            'id': d.id,
            'effect': d.effect.name,
            'x': d.x,
            'z': d.z,
            'spawn': d.spawn,
            'landing': d.landing,
          },
        )
        .toList(),
    'mode': lane ? 'lane' : 'plane',
    'phase': phase.name,
    'time': time,
    'x': x,
    'z': z,
    'yaw': yaw,
    'score': score,
    'combo': combo,
    'caught': caught,
    'happoshu': bad,
    'missed': missed,
    'activeCans': drops
        .where((d) => d.visible(time))
        .map(
          (d) => {
            'id': d.id,
            'kind': d.kind.name,
            'facing': d.facing,
            'x': d.x,
            'z': d.z,
            'height': d.height(time),
            'landing': d.landing,
          },
        )
        .toList(),
    'events': events,
  };

  /// A recording controller supplies only movement/camera inputs, never scores.
  ({double x, double y}) demoInput() {
    final candidates =
        drops
            .where(
              (d) =>
                  !d.resolved &&
                  d.spawn <= time &&
                  (d.kind != CanKind.happoshu || d.id == 3),
            )
            .toList()
          ..sort((a, b) => a.landing.compareTo(b.landing));
    if (candidates.isEmpty) return (x: 0, y: 0);
    final d = candidates.first;
    if (lane) return (x: -(d.x - x) * 2.6, y: 0);
    return toScreen((d.x - x) * 2.6, (d.z - z) * 2.6, yaw);
  }
}
