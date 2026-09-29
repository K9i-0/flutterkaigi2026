import 'dart:math' as math;

import 'package:madogiwa_engine/madogiwa_engine.dart';

class Guard {
  Guard(this.route) : position = route.first;
  final List<Point2> route;
  Point2 position;
  int waypoint = 1, health = 100;
  double yaw = 0, speed = 0, attackCooldown = 0;
  final awareness = Awareness();
}

class HazardGame {
  HazardGame(Map<String, dynamic> data) {
    Point2 point(List<dynamic> p) =>
        Point2((p[0] as num).toDouble(), (p[1] as num).toDouble());
    player = point(data['player']);
    terminal = point(data['terminal']);
    exit = point(data['exit']);
    guards = [
      for (final route in data['guards'])
        Guard([for (final p in route) point(p)]),
    ];
    world = CollisionWorld([
      for (final row in data['cover'])
        SolidBox(
          (row[0] as num).toDouble(),
          (row[1] as num).toDouble(),
          (row[2] as num).toDouble(),
          (row[3] as num).toDouble(),
        ),
      const SolidBox(-12, 0, .4, 36),
      const SolidBox(12, 0, .4, 36),
      const SolidBox(0, -18, 24, .4),
      const SolidBox(0, 18, 24, .4),
    ]);
  }
  late final CollisionWorld world;
  late Point2 player, terminal, exit;
  late final List<Guard> guards;
  double yaw = math.pi,
      forward = 0,
      strafe = 0,
      speed = 0,
      elapsed = 0,
      cooldown = 0,
      reloadTime = 0,
      flash = 0;
  bool crouching = false, unlocked = false, won = false;
  int health = 100, ammo = 6, reserve = 18, shots = 0;
  String message = '制御盤で搬出口を開ける';
  Point2 get facing => Point2(math.sin(yaw), math.cos(yaw));
  bool get ended => won || health <= 0;
  void reload() {
    if (ended || reloadTime > 0 || ammo == 6 || reserve == 0) return;
    reloadTime = 1.3;
    message = '装填中';
  }

  void interact() {
    if (!ended && (player - terminal).length < 1.8) {
      unlocked = true;
      message = '搬出口が開いた。緑の出口へ';
    }
  }

  void fire() {
    if (ended || cooldown > 0 || reloadTime > 0) return;
    if (ammo == 0) {
      reload();
      return;
    }
    ammo--;
    shots++;
    cooldown = .28;
    flash = .12;
    var nearest = world.ray(player, facing, 25) ?? 25.0;
    Guard? target;
    for (final g in guards.where((g) => g.health > 0)) {
      final delta = g.position - player, along = delta.dot(facing);
      final perpendicular2 = math.max(0, delta.dot(delta) - along * along);
      if (perpendicular2 > .45 * .45) continue;
      final hit = along - math.sqrt(.45 * .45 - perpendicular2);
      if (hit >= 0 && hit < nearest) {
        nearest = hit;
        target = g;
      }
    }
    if (target != null) {
      target.health = math.max(0, target.health - 50);
      message = target.health == 0 ? '追跡者を倒した' : '命中';
    } else {
      message = '銃声が響いた';
    }
    for (final g in guards.where((g) => g.health > 0)) {
      final radius = world.visible(player, g.position) ? 20 : 10;
      if ((g.position - player).length < radius) {
        g.awareness.hear(player, memory: 8);
      }
    }
  }

  void tick(double dt) {
    if (!dt.isFinite || dt < 0 || dt > .1) {
      throw ArgumentError('Use bounded simulation steps');
    }
    if (ended) return;
    elapsed += dt;
    cooldown = math.max(0, cooldown - dt);
    flash = math.max(0, flash - dt);
    if (reloadTime > 0) {
      reloadTime = math.max(0, reloadTime - dt);
      if (reloadTime == 0) {
        final n = math.min(6 - ammo, reserve);
        ammo += n;
        reserve -= n;
        message = '装填完了';
      }
    }
    final input =
        (facing * forward + Point2(-facing.z, facing.x) * strafe).normalized;
    final previous = player;
    player = world.move(player, input * (dt * (crouching ? 1.35 : 3.1)));
    speed = dt == 0 ? 0 : (player - previous).length / dt;
    for (final g in guards.where((g) => g.health > 0)) {
      final delta = player - g.position,
          direction = Point2(math.sin(g.yaw), math.cos(g.yaw));
      final sees =
          delta.length < 11 &&
          delta.normalized.dot(direction) > .55 &&
          world.visible(g.position, player);
      g.awareness.update(
        dt,
        seesTarget: sees,
        target: player,
        detectionSeconds: crouching ? 1.4 : .7,
      );
      if (speed > 0 &&
          !crouching &&
          delta.length < 3.8 &&
          g.awareness.mode != AwarenessMode.chase) {
        g.awareness.hear(player, memory: 3);
      }
      var goal = g.awareness.lastKnown;
      if (g.awareness.mode == AwarenessMode.patrol) {
        goal = g.route[g.waypoint];
        if ((goal - g.position).length < .25) {
          g.waypoint = (g.waypoint + 1) % g.route.length;
          goal = g.route[g.waypoint];
        }
      }
      final before = g.position;
      if (goal != null && (goal - g.position).length > .15) {
        final to = (goal - g.position).normalized;
        g.yaw = math.atan2(to.x, to.z);
        g.position = world.move(
          g.position,
          to * (dt * (g.awareness.mode == AwarenessMode.chase ? 2.7 : 1.1)),
          radius: .4,
        );
      }
      g.speed = dt == 0 ? 0 : (g.position - before).length / dt;
      g.attackCooldown = math.max(0, g.attackCooldown - dt);
      if ((g.position - player).length < 1.05 &&
          sees &&
          g.attackCooldown == 0) {
        health = math.max(0, health - 20);
        g.attackCooldown = 1.2;
        message = '攻撃された。遮蔽物へ逃げる';
      }
    }
    if (unlocked && (player - exit).length < 1.5) {
      won = true;
      message = '脱出成功';
    }
  }

  Map<String, Object?> inspect() => {
    'player': player.toJson(),
    'yaw': yaw,
    'health': health,
    'ammo': ammo,
    'reserve': reserve,
    'crouching': crouching,
    'unlocked': unlocked,
    'won': won,
    'shots': shots,
    'elapsed': elapsed,
    'guards': [
      for (final g in guards)
        {
          'position': g.position.toJson(),
          'health': g.health,
          'awareness': g.awareness.mode.name,
          'suspicion': g.awareness.suspicion,
          'lastKnown': g.awareness.lastKnown?.toJson(),
        },
    ],
  };
}
