import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';

HazardGameState arena() {
  final s = HazardGameState(
    jsonDecode(File('assets/village.json').readAsStringSync()),
  );
  s.obstacles.clear();
  s.crates.clear();
  s.x = 0;
  s.z = -20;
  s.invulnerable = 100;
  for (final e in s.enemies) {
    e.active = false;
  }
  return s;
}

void advance(HazardGameState s, double seconds) {
  for (var i = 0; i < (seconds * 60).ceil(); i++) {
    s.tick(1 / 60);
  }
}

void main() {
  test('two approach sides spread out and run in open ground', () {
    final s = arena();
    for (final i in [1, 2]) {
      s.enemies[i]
        ..x = 0
        ..z = -12
        ..active = true
        ..alerted = true;
    }
    advance(s, 1.5);
    final a = s.enemies[1], b = s.enemies[2];
    expect(a.x * b.x, lessThan(0));
    expect((a.x - b.x).abs(), greaterThan(1));
    expect(a.z, lessThan(-14));
    expect(b.z, lessThan(-14));
    expect(a.runningApproach && b.runningApproach, true);
    expect(a.hp, 100);
  });
  test('cover cancels direct flanking and preserves solid collision', () {
    final s = arena();
    s.obstacles.add(
      Obstacle({
        'x': 0.0,
        'z': -16.0,
        'w': 8.0,
        'd': .4,
        'bottom': 0.0,
        'top': 3.0,
      }),
    );
    final e = s.enemies[1]
      ..x = 0
      ..z = -12
      ..active = true
      ..alerted = true;
    advance(s, 1);
    expect(e.approachX, isNull);
    expect(e.runningApproach, false);
    expect(e.z, greaterThan(-15.3));
    expect(s.blocked(e.x, e.z, e.y, radius: .37), false);
  });
  test(
    'mug contact and damage share one clock, then hold a punishable recovery',
    () {
      final s = arena()..invulnerable = 0;
      // Exercise the mug branch while the separate grab is on cooldown.
      final e = s.enemies.first
        ..grabCooldown = 7
        ..x = 0
        ..z = -19.1
        ..active = true
        ..alerted = true;
      s.tick(1 / 60);
      advance(s, .8);
      expect(s.health, 100);
      expect(e.meleeClipTime, lessThan(.77));
      advance(s, .07);
      expect(s.health, 85);
      expect(e.meleeClipTime, greaterThanOrEqualTo(.77));
      expect(e.meleeRecovery, greaterThan(0));
      final x = e.x, z = e.z;
      advance(s, .35);
      expect(e.x, x);
      expect(e.z, z);
      expect(s.health, 85);
      expect(e.meleeClipTime, greaterThan(.9));
    },
  );
  test(
    'village residents start visible and old hidden reinforcements migrate',
    () {
      final map = jsonDecode(
        File('assets/village.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final s = HazardGameState(map);
      expect(s.enemies.every((e) => e.active), true);
      expect(s.enemies.every((e) => !e.alerted), true);
      s.enemies[5].active = false;
      s.enemies[1]
        ..meleeRecovery = .4
        ..approachHeading = 1.2;
      final current = s.checkpoint();
      final restored = restoreHazardCheckpoint(current, map, {});
      expect(restored.enemies[5].active, false);
      expect(restored.enemies[1].meleeRecovery, .4);
      expect(restored.enemies[1].approachHeading, 1.2);
      current.remove('encounterVersion');
      expect(restoreHazardCheckpoint(current, map, {}).enemies[5].active, true);
    },
  );
}
