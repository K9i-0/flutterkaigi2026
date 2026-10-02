import 'dart:math' as math;

enum Phase { ready, countdown, playing, result }

enum CanKind { superTry, light, happoshu }

class Drop {
  Drop(this.id, this.kind, this.x, this.z, this.spawn);
  final int id;
  final CanKind kind;
  final double x, z, spawn;
  bool resolved = false, caught = false;
  double get landing => spawn + 3.1;
  double height(double time) {
    final p = ((time - spawn) / 3.1).clamp(0.0, 1.0);
    return resolved && !caught
        ? math.max(.35, 1.15 - (time - landing) * 4)
        : 1.15 + 4.7 * (1 - math.pow(p, 1.25));
  }

  bool visible(double time) => time >= spawn && time < landing + .65 && !caught;
}

class CatchGame {
  static const duration = 20.0, halfX = 3.9, halfZ = 2.8;
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
  final events = <Map<String, Object>>[];
  void start({int seed = 1}) {
    phase = Phase.countdown;
    time = 0;
    countdown = 2;
    x = 0;
    z = 1;
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
    message = 'ビールだけ、持ってこい。';
    messageUntil = 2;
    final r = math.Random(seed);
    for (var i = 0; i < 16; i++) {
      final kind = i % 4 == 3
          ? CanKind.happoshu
          : i % 3 == 1
          ? CanKind.light
          : CanKind.superTry;
      drops.add(
        Drop(
          i,
          kind,
          (r.nextDouble() - .5) * 6.2,
          (r.nextDouble() - .5) * 4.2,
          i * 1.03,
        ),
      );
    }
  }

  void rotate(int direction) => targetYaw += direction.sign * math.pi / 4;

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
    final len = math.sqrt(ix * ix + iy * iy);
    if (len > 1) {
      ix /= len;
      iy /= len;
    }
    final dir = toWorld(ix, iy, yaw), a = 1 - math.exp(-12 * dt);
    vx += (dir.x * 3.5 - vx) * a;
    vz += (dir.z * 3.5 - vz) * a;
    x = (x + vx * dt).clamp(-halfX, halfX);
    z = (z + vz * dt).clamp(-halfZ, halfZ);
    for (final d in drops) {
      if (d.resolved || time < d.landing) continue;
      d.resolved = true;
      d.caught = math.pow(d.x - x, 2) + math.pow(d.z - z, 2) < .72 * .72;
      if (d.caught) {
        eventId++;
        if (d.kind == CanKind.happoshu) {
          bad++;
          score -= 200;
          combo = 0;
          message = 'これ、発泡酒やないか！  −200';
        } else {
          caught++;
          combo++;
          final points = 100 + math.min(combo - 1, 4) * 25;
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
    if (time >= duration) {
      time = duration;
      phase = Phase.result;
      vx = 0;
      vz = 0;
    }
  }

  Map<String, Object> inspect() => {
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
    return toScreen((d.x - x) * 2.6, (d.z - z) * 2.6, yaw);
  }
}
