import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_settings.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';
import 'package:vector_math/vector_math.dart' as vm;

Map<String, dynamic> world(String id) =>
    jsonDecode(File('assets/$id.json').readAsStringSync());
HazardGameState mountain(HazardDifficulty difficulty) {
  final s = HazardGameState(world('mountain'), difficulty: difficulty);
  for (final e in s.enemies) {
    e.active = false;
  }
  return s;
}

void killBoss(HazardGameState s) {
  final boss = s.enemies.singleWhere((e) => e.boss);
  boss
    ..hp = 1
    ..active = true
    ..stun = 30;
  s
    ..x = 6
    ..z = 4
    ..y = 0
    ..aiming = true
    ..pistolLoaded = 10;
  s.shoot(
    vm.Vector3(6, 1.25, 4),
    vm.Vector3(12, boss.headHeight, 4) - vm.Vector3(6, 1.25, 4),
  );
  expect(boss.alive, false);
}

void main() {
  test('lethal damage cannot bypass confession; each beat occurs once', () {
    final s = mountain(HazardDifficulty.standard);
    expect(s.pendingDemoEvent, 'last_order');
    s.seenEvents.add('last_order');
    expect(s.pendingDemoEvent, isNull);
    killBoss(s);
    expect(s.pendingDemoEvent, 'boss_confession');
    s.seenEvents.add('boss_confession');
    expect(s.pendingDemoEvent, 'boss_defeated');
    s.seenEvents.add('boss_defeated');
    expect(s.pendingDemoEvent, isNull);
  });

  for (final difficulty in HazardDifficulty.values) {
    test('boss kill permits investigation without all kills: $difficulty', () {
      final s = mountain(difficulty);
      s
        ..x = 19.8
        ..z = 15;
      s.interact();
      expect(s.phase, isNot(PlayPhase.clear));
      killBoss(s);
      expect(s.livingEnemies, greaterThan(0));
      expect(s.refugeUnlocked, true);
      expect(s.phase, PlayPhase.playing);
      s
        ..x = 19.8
        ..z = 15
        ..aiming = false;
      s.interact();
      expect(s.seenEvents, isNot(contains('facility_discovered')));
      s.seenEvents.addAll(['boss_confession', 'boss_defeated']);
      expect(s.blocked(s.x, s.z, 0), false);
      s.interact();
      expect(s.seenEvents, contains('facility_discovered'));
      expect(s.phase, PlayPhase.clear);
    });
  }
  test('facility discovery requires proximity after boss death', () {
    final s = mountain(HazardDifficulty.standard);
    killBoss(s);
    s.seenEvents.addAll(['boss_confession', 'boss_defeated']);
    s
      ..x = 6
      ..z = 4
      ..aiming = false;
    s.interact();
    expect(s.seenEvents, isNot(contains('facility_discovered')));
  });
  test('old escape completion does not skip the new investigation', () {
    final s = mountain(HazardDifficulty.standard);
    killBoss(s);
    s
      ..x = 6
      ..z = 4
      ..aiming = false;
    final data = jsonDecode(jsonEncode(s.checkpoint())) as Map<String, dynamic>;
    data.remove('storyVersion');
    data['seenEvents'] = ['ending', 'refuge_complete'];
    final restored = restoreHazardCheckpoint(data, world('mountain'), {});
    expect(restored.seenEvents, isNot(contains('ending')));
    expect(restored.refugeComplete, false);
    expect(restored.bossAlive, false);
  });
  test('new completed discovery survives a checkpoint', () {
    final s = mountain(HazardDifficulty.standard);
    killBoss(s);
    s
      ..x = 19.8
      ..z = 15
      ..aiming = false;
    s.seenEvents.addAll(['boss_confession', 'boss_defeated']);
    s.interact();
    final restored = restoreHazardCheckpoint(
      jsonDecode(jsonEncode(s.checkpoint())),
      world('mountain'),
      {},
    );
    expect(restored.seenEvents, contains('facility_discovered'));
  });
  test(
    'shrine remains inaccessible before the boss; enemies stay outside after',
    () {
      final s = mountain(HazardDifficulty.standard);
      expect(s.blocked(13, 9.5, 0), true);
      killBoss(s);
      expect(s.blocked(13, 9.5, 0), false);
      expect(s.refugeContains(13, 14), true);
    },
  );
}
