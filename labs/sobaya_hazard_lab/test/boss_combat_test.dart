import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';

HazardGameState arena() {
  final s = HazardGameState(
    jsonDecode(File('assets/mountain.json').readAsStringSync()),
  );
  s.obstacles.clear();
  s.crates.clear();
  for (final e in s.enemies) {
    e.active = false;
  }
  s.x = 8;
  s.z = 4;
  s.enemies.firstWhere((e) => e.boss)
    ..x = 8
    ..z = 10
    ..active = true
    ..alerted = true;
  return s;
}

Enemy boss(HazardGameState s) => s.enemies.firstWhere((e) => e.boss);
void advance(HazardGameState s, double seconds) {
  for (var i = 0; i < (seconds * 60).ceil(); i++) {
    s.tick(1 / 60);
  }
}

void main() {
  test(
    'charge locks direction, lateral movement escapes and creates recovery',
    () {
      final s = arena();
      final b = boss(s);
      s.tick(1 / 60);
      expect(b.bossMove, BossMove.chargeWindup);
      final heading = b.heading;
      s.inputX = -1;
      s.sprint = true;
      advance(s, 1.15);
      s.inputX = 0;
      advance(s, 1.2);
      expect(b.heading, heading);
      expect(b.bossMove, BossMove.recovery);
      expect(s.health, 100);
    },
  );
  test('charge hits once, cover stops travel and rewards a longer opening', () {
    final s = arena();
    advance(s, 2.3);
    expect(s.health, 75);
    advance(s, .7);
    expect(s.health, 75);
    final t = arena();
    t.tick(1 / 60);
    t.obstacles.add(
      Obstacle({
        'x': 8.0,
        'z': 7.0,
        'w': 4.0,
        'd': .5,
        'bottom': 0.0,
        'top': 3.0,
      }),
    );
    advance(t, 1.8);
    expect(boss(t).bossMove, BossMove.recovery);
    expect(boss(t).z, greaterThan(7.6));
    expect(boss(t).bossTimer, greaterThan(2));
    expect(t.health, 100);
  });
  test('committed attack takes bullet damage without restarting its tell', () {
    final s = arena();
    s.tick(1 / 60);
    s.aiming = true;
    s.shoot(vm.Vector3(8, 1.2, 4), vm.Vector3(0, 0, 1));
    expect(boss(s).hp, 870);
    expect(boss(s).bossMove, BossMove.chargeWindup);
    advance(s, 1.17);
    expect(boss(s).bossMove, BossMove.charging);
  });
  test(
    'second-phase slam has an escape window and cannot hit through a wall',
    () {
      for (final cover in [false, true]) {
        final s = arena();
        boss(s)
          ..z = 6
          ..hp = 170
          ..bossSequence = 1;
        s.tick(1 / 60);
        expect(boss(s).bossMove, BossMove.slamWindup);
        if (cover) {
          s.obstacles.add(
            Obstacle({
              'x': 8.0,
              'z': 5.0,
              'w': 4.0,
              'd': .2,
              'bottom': 0.0,
              'top': 3.0,
            }),
          );
        } else {
          s.yaw = 0;
          s.inputY = 1;
          s.sprint = true;
        }
        advance(s, 1.3);
        expect(s.health, 100);
        expect(boss(s).bossMove, BossMove.recovery);
      }
    },
  );
  test('checkpoint keeps a charge direction and one-hit state', () {
    final s = arena();
    final b = boss(s)
      ..bossMove = BossMove.charging
      ..bossTimer = .4
      ..heading = math.pi
      ..chargeHit = true
      ..bossSequence = 2;
    final restored = restoreHazardCheckpoint(s.checkpoint(), s.map, {});
    expect(boss(restored).bossMove, b.bossMove);
    expect(boss(restored).bossTimer, .4);
    expect(boss(restored).chargeHit, true);
    expect(boss(restored).heading, math.pi);
  });
  test('mountain encounter can be won with carried merchant ammo and ordinary movement', () {
    final s = HazardGameState(
      jsonDecode(File('assets/mountain.json').readAsStringSync()),
    );
    for (final e in s.enemies) {
      e.active = e.boss;
    }
    s.x = 6;
    s.z = 4;
    s.addItem('ammo', 30);
    final b = boss(s)..alerted = true;
    final moves = <BossMove>{};
    for (var i = 0; i < 60 * 150 && b.alive && s.running; i++) {
      moves.add(b.bossMove);
      s.inputX = s.inputY = 0;
      s.aiming = false;
      s.sprint = true;
      s.yaw = 0;
      if (b.bossMove == BossMove.chargeWindup) {
        // Move perpendicular to the locked charge; use the usual input mapping.
        s.inputX = -math.cos(b.heading);
        s.inputY = math.sin(b.heading);
      } else if (b.bossMove == BossMove.swipeWindup ||
          b.bossMove == BossMove.slamWindup) {
        final away = vm.Vector2(s.x - b.x, s.z - b.z).normalized();
        s.inputX = -away.x;
        s.inputY = -away.y;
      } else if (b.bossMove == BossMove.recovery) {
        s.aiming = true;
        final origin = vm.Vector3(s.x, 1.25, s.z);
        s.shoot(origin, vm.Vector3(b.x, 1.1, b.z) - origin);
        if (s.loaded == 0) s.reload();
      }
      s.tick(1 / 60);
    }
    expect(b.alive, false);
    expect(s.health, greaterThan(0));
    expect(s.shots, lessThanOrEqualTo(30));
    expect(
      moves,
      containsAll([
        BossMove.chargeWindup,
        BossMove.charging,
        BossMove.recovery,
      ]),
    );
    advance(s, 1);
    expect(s.pickups.where((p) => p.id == 'beer_${b.id}').length, 1);
  });

  test('defeated boss cancels attacks and produces exactly one beer', () {
    final s = arena();
    boss(s).hp = 30;
    s.tick(1 / 60);
    s.aiming = true;
    s.shoot(vm.Vector3(8, 1.2, 4), vm.Vector3(0, 0, 1));
    advance(s, 4);
    expect(s.health, 100);
    expect(boss(s).alive, false);
    expect(boss(s).attackPending, false);
    expect(s.pickups.where((p) => p.id == 'beer_${boss(s).id}').length, 1);
  });
}
