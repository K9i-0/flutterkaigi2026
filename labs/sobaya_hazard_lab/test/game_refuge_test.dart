import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_campaign.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';
import 'package:sobaya_hazard_lab/game/game_settings.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_window.dart';
import 'package:vector_math/vector_math.dart' as vm;

Map<String, Map<String, dynamic>> worlds() => {
  for (final id in ['village', 'farm', 'mountain'])
    id: jsonDecode(File('assets/$id.json').readAsStringSync()),
};
HazardGameState mountain({bool hardest = false}) {
  final s = HazardGameState(
    worlds()['mountain']!,
    difficulty: hardest ? HazardDifficulty.tense : HazardDifficulty.standard,
  );
  // Freeze unrelated combat without changing the alive flags used by the rule.
  for (final e in s.enemies) {
    e.active = false;
  }
  return s;
}

void defeatedFixture(HazardGameState s, Enemy e) {
  if (!e.alive) return;
  e
    ..hp = 0
    ..alive = false
    ..dropped = true;
  s.kills++;
}

void finishWithBullet(HazardGameState s, Enemy e) {
  e
    ..hp = 1
    ..x = 12
    ..z = 4
    ..y = 0
    ..active = true
    ..stun = 30;
  s
    ..phase = PlayPhase.playing
    ..x = 6
    ..z = 4
    ..y = 0
    ..aiming = true
    ..fireCooldown = 0
    ..pistolLoaded = 10;
  s.equip('handgun');
  final origin = vm.Vector3(6, 1.25, 4);
  s.shoot(origin, vm.Vector3(12, e.headHeight, 4) - origin);
  expect(e.alive, false);
}

void openStandardHouse(HazardGameState s) {
  finishWithBullet(s, s.enemies.singleWhere((e) => e.boss));
  expect(s.refugeUnlocked, true);
}

void approach(HazardGameState s, String who) {
  final npc = s.npcs.singleWhere((n) => n['id'] == who);
  s
    ..x = (npc['x'] as num).toDouble()
    ..z = (npc['z'] as num).toDouble() - 1.2
    ..y = 0;
  s.stopInput();
  expect(s.insideRefuge, true);
  s.startDialogue(who);
  expect(s.phase, PlayPhase.dialogue);
}

void finishLines(HazardGameState s) {
  while (!s.dialogueChoices) {
    s.advanceDialogue();
  }
}

void report(HazardGameState s, String who) {
  approach(s, who);
  finishLines(s);
  s.chooseDialogue('leave');
  expect(s.phase, PlayPhase.playing);
}

Map<String, dynamic> saved(HazardGameState s) =>
    jsonDecode(jsonEncode(s.checkpoint()));
HazardCampaign campaignAtMountain({bool hardest = false}) {
  final c = HazardCampaign(worlds());
  for (var chapter = 0; chapter < 2; chapter++) {
    c.state.exitRequested = Map<String, dynamic>.from(
      (c.state.map['exits'] as List).singleWhere((e) => e['id'] == 'forward'),
    );
    c.state.phase = PlayPhase.transition;
    expect(c.traverse(), true);
  }
  c.difficulty = hardest ? HazardDifficulty.tense : HazardDifficulty.standard;
  for (final region in c.regions.values) {
    region.difficulty = c.difficulty;
    for (final e in region.enemies) {
      e.active = false;
    }
  }
  return c;
}

void backToFarm(HazardCampaign c) {
  c.state.exitRequested = Map<String, dynamic>.from(
    (c.state.map['exits'] as List).singleWhere((e) => e['id'] == 'back'),
  );
  c.state.phase = PlayPhase.transition;
  expect(c.traverse(), true);
  expect(c.state.zoneId, 'farm');
}

void main() {
  test('standard boss kill opens the doorway; entering alone is not clear', () {
    final s = mountain();
    expect(s.blocked(13, 9.5, 0), true);
    expect(s.npcs, isEmpty);
    openStandardHouse(s);
    expect(s.livingEnemies, 5);
    expect(s.blocked(13, 9.5, 0), false);
    expect(s.seenEvents, contains('refuge_ready'));
    s
      ..x = 13
      ..z = 8.4;
    s.stopInput();
    for (var i = 0; i < 90; i++) {
      s.move(0, 1, 1 / 60);
      s.tick(1 / 60);
    }
    expect(s.insideRefuge, true);
    expect(s.seenEvents, contains('refuge_entered'));
    expect(s.refugeReports, isEmpty);
    expect(s.refugeComplete, false);
    expect(s.phase, PlayPhase.playing);
  });
  for (final bossLast in [false, true]) {
    test(
      'highest difficulty unlocks on the final kill (bossLast=$bossLast)',
      () {
        final s = mountain(hardest: true);
        final boss = s.enemies.singleWhere((e) => e.boss);
        final normal = s.enemies.where((e) => !e.boss).toList();
        if (bossLast) {
          for (final e in normal) {
            defeatedFixture(s, e);
          }
        } else {
          finishWithBullet(s, boss);
          expect(s.refugeUnlocked, false);
          expect(s.evacuationStarted, false);
          expect(s.npcs, isEmpty);
          for (final e in normal.take(normal.length - 1)) {
            defeatedFixture(s, e);
          }
        }
        expect(s.livingEnemies, 1);
        s.refreshRefuge();
        expect(s.blocked(13, 9.5, 0), true);
        s.checkpointRequested = false;
        finishWithBullet(s, bossLast ? boss : normal.last);
        expect(s.livingEnemies, 0);
        expect(s.refugeUnlocked, true);
        expect(s.checkpointRequested, true);
        expect(
          s.npcs.map((n) => n['id']),
          containsAll(['yametaro', 'takosan']),
        );
        expect(s.blocked(13, 9.5, 0), false);
        expect(s.refugeComplete, false);
      },
    );
  }
  test(
    'farm shop stays available until the highest-difficulty house opens',
    () {
      final c = campaignAtMountain(hardest: true);
      final m = c.state;
      finishWithBullet(m, m.enemies.singleWhere((e) => e.boss));
      c.syncRefuge();
      expect(m.refugeUnlocked, false);
      expect(c.regions['farm']!.npcs.map((n) => n['id']), contains('takosan'));
      backToFarm(c);
      final farm = c.state
        ..beers = 4
        ..x = -13
        ..z = -19;
      farm.startDialogue('takosan');
      expect(farm.phase, PlayPhase.dialogue);
      finishLines(farm);
      farm.chooseDialogue('trade:ammo');
      expect(farm.beers, 2);
      expect(farm.tradePurchases['ammo'], 1);
      farm.endDialogue();
      for (final e in m.enemies.where((e) => e.alive)) {
        defeatedFixture(m, e);
      }
      c.syncRefuge();
      expect(m.refugeUnlocked, true);
      expect(c.regions['farm']!.npcs, isEmpty);
      expect(c.regions['village']!.npcs, isEmpty);
      expect(m.npcs.length, 2);
    },
  );
  test('closed house blocks walking and its old window', () {
    final s = mountain();
    expect(s.enemies.every((e) => !s.refugeContains(e.x, e.z)), true);
    s
      ..x = 13
      ..z = 8;
    for (var i = 0; i < 120; i++) {
      s.move(0, 1, 1 / 60);
    }
    expect(s.refugeContains(s.x, s.z), false);
    s.interact();
    expect(s.refugeUnlocked, false);
    final w = s.windows.single;
    s
      ..x = w.x
      ..z = w.entryZ(true);
    s.interact();
    expect(s.vault, isNull);
    expect(s.usableWindows, isEmpty);
    expect(
      s.wallDistance(vm.Vector3(w.x, 1.5, 8), vm.Vector3(0, 0, 1), 3),
      lessThan(2),
    );
    s
      ..x = 16
      ..z = 16.3;
    s.startDialogue('yametaro');
    expect(s.phase, PlayPhase.playing);
    expect(s.refugeReports, isEmpty);
  });
  test('remaining enemies stay outside an unlocked refuge', () {
    final s = mountain();
    openStandardHouse(s);
    final e = s.enemies.firstWhere((e) => !e.boss)
      ..active = true
      ..alerted = true
      ..x = 13
      ..z = 8
      ..stun = 0;
    s
      ..x = 13
      ..z = 11
      ..aiming = false;
    final before = (s.health, Map<String, double>.from(s.companionHealth));
    for (var i = 0; i < 360; i++) {
      s.tick(1 / 60);
      expect(s.refugeContains(e.x, e.z), false);
      expect(e.vault, isNull);
    }
    expect(s.health, before.$1);
    expect(s.companionHealth, before.$2);
  });
  for (final first in ['yametaro', 'takosan']) {
    test(
      'both report orders complete after leaving the second conversation ($first first)',
      () {
        final s = mountain();
        openStandardHouse(s);
        final second = first == 'yametaro' ? 'takosan' : 'yametaro';
        report(s, first);
        expect(s.refugeReports, {first});
        expect(s.refugeComplete, false);
        approach(s, second);
        finishLines(s);
        expect(s.refugeComplete, false);
        expect(s.dialogueLeaveLabel, contains('クリア'));
        s.chooseDialogue('leave');
        expect(s.refugeReports, {'yametaro', 'takosan'});
        expect(s.refugeComplete, true);
        expect(
          s.phase,
          PlayPhase.playing,
        ); // Controller saves before the movie.
        expect(s.checkpointRequested, true);
        s.endDialogue();
        expect(s.refugeReports.length, 2);
        final restored = restoreHazardCheckpoint(saved(s), s.map, {});
        expect(restored.refugeComplete, true);
        expect(restored.refugeReports.length, 2);
      },
    );
  }
  test('early exit and repeat NPC visits cannot count as two reports', () {
    final s = mountain();
    openStandardHouse(s);
    approach(s, 'yametaro');
    s.chooseDialogue('leave');
    expect(s.phase, PlayPhase.dialogue);
    s.endDialogue(); // Esc may close an unfinished conversation.
    expect(s.refugeReports, isEmpty);
    report(s, 'yametaro');
    report(s, 'yametaro');
    expect(s.refugeReports, {'yametaro'});
    expect(s.refugeComplete, false);
    approach(s, 'takosan');
    s.advanceDialogue();
    s.endDialogue();
    expect(s.refugeReports, {'yametaro'});
    expect(s.refugeComplete, false);
  });
  for (final affordable in [false, true]) {
    test(
      'shopping preserves report without clearing during shop (affordable=$affordable)',
      () {
        final s = mountain();
        openStandardHouse(s);
        report(s, 'yametaro');
        s.beers = affordable ? 10 : 0;
        approach(s, 'takosan');
        s.buySupplies('ammo');
        expect(s.tradePurchases, isEmpty);
        finishLines(s);
        s.chooseDialogue('trade:ammo');
        expect(s.beers, affordable ? 8 : 0);
        expect(s.tradePurchases['ammo'], affordable ? 1 : null);
        expect(s.refugeComplete, false);
        expect(s.phase, PlayPhase.dialogue);
        finishLines(s);
        s.chooseDialogue('route');
        finishLines(s);
        s.endDialogue();
        expect(s.refugeReports, {'yametaro', 'takosan'});
        expect(s.refugeComplete, true);
        expect(s.phase, PlayPhase.playing);
      },
    );
  }
  test(
    'old optional reunion flags do not satisfy the new clear requirement',
    () {
      final s = mountain();
      openStandardHouse(s);
      s.seenEvents.addAll(['reunion_yametaro', 'reunion_takosan']);
      final restored = restoreHazardCheckpoint(saved(s), s.map, {});
      expect(restored.refugeReports, isEmpty);
      expect(restored.refugeComplete, false);
      approach(restored, 'takosan');
      expect(restored.dialogueTopic, 'reunion');
    },
  );
  test('one report survives save without repeating it', () {
    final s = mountain();
    openStandardHouse(s);
    report(s, 'yametaro');
    final restored = restoreHazardCheckpoint(saved(s), s.map, {});
    expect(restored.refugeReports, {'yametaro'});
    expect(restored.refugeComplete, false);
    approach(restored, 'yametaro');
    expect(restored.dialogueTopic, 'greeting');
    restored.endDialogue();
    report(restored, 'takosan');
    expect(restored.refugeComplete, true);
  });
  test(
    'legacy indoor player and enemy positions migrate without losing progress',
    () {
      final s = mountain()
        ..x = 13
        ..z = 12
        ..beers = 7
        ..health = 63
        ..gateOpen = true;
      s.foundMemos.add('diary_end');
      final e = s.enemies.singleWhere((e) => e.id == 5)
        ..x = 10
        ..z = 13
        ..hp = 60
        ..active = true
        ..alerted = true
        ..companionTarget = 'yametaro'
        ..attackPending = true
        ..windup = .3;
      final restored = restoreHazardCheckpoint(saved(s), s.map, {'wanted'});
      expect(restored.refugeUnlocked, false);
      expect(restored.refugeContains(restored.x, restored.z), false);
      expect(restored.blocked(restored.x, restored.z, restored.y), false);
      final migrated = restored.enemies.singleWhere((v) => v.id == e.id);
      expect(restored.refugeContains(migrated.x, migrated.z), false);
      expect(migrated.hp, 60);
      expect(migrated.companionTarget, isNull);
      expect(migrated.attackPending, false);
      expect(restored.health, 63);
      expect(restored.beers, 7);
      expect(restored.foundMemos, {'diary_end'});
      expect(restored.collected, {'wanted'});
      expect(restored.refugeReports, isEmpty);
    },
  );
  for (final enemyTraversal in [false, true]) {
    test(
      'legacy window traversal is safely cancelled (enemy=$enemyTraversal)',
      () {
        final s = mountain();
        final w = s.windows.single;
        final t = WindowTraversal(
          w,
          true,
          w.x,
          w.entryZ(true),
          enemy: enemyTraversal,
        )..elapsed = .9;
        if (enemyTraversal) {
          final e = s.enemies.singleWhere((e) => e.id == 5)
            ..vault = t
            ..active = true
            ..x = t.x
            ..y = t.y
            ..z = t.z;
          expect(e.alive, true);
        } else {
          s
            ..vault = t
            ..x = t.x
            ..y = t.y
            ..z = t.z;
        }
        final restored = restoreHazardCheckpoint(saved(s), s.map, {});
        expect(restored.vault, isNull);
        expect(restored.enemies.every((e) => e.vault == null), true);
        expect(restored.refugeContains(restored.x, restored.z), false);
        expect(
          restored.enemies.every((e) => !restored.refugeContains(e.x, e.z)),
          true,
        );
      },
    );
  }
  test(
    'restore applies highest difficulty before house access and relocation',
    () {
      final c = campaignAtMountain();
      openStandardHouse(c.state);
      c.syncRefuge();
      c.state
        ..x = 13
        ..z = 12;
      final checkpoint =
          jsonDecode(jsonEncode(c.checkpoint())) as Map<String, dynamic>;
      final hard = HazardCampaign.restore(
        checkpoint,
        worlds(),
        {},
        difficulty: HazardDifficulty.tense,
      );
      expect(hard.state.difficulty, HazardDifficulty.tense);
      expect(hard.state.refugeUnlocked, false);
      expect(hard.state.insideRefuge, false);
      expect(hard.state.refugeContains(hard.state.x, hard.state.z), false);
      expect(hard.state.npcs, isEmpty);
      expect(
        hard.regions['farm']!.npcs.map((n) => n['id']),
        contains('takosan'),
      );
      final standard = HazardCampaign.restore(checkpoint, worlds(), {});
      expect(standard.state.refugeUnlocked, true);
      expect(standard.state.insideRefuge, true);
      expect(standard.regions['farm']!.npcs, isEmpty);
    },
  );
  test(
    'difficulty change invalidates stale refuge-ready flags and retains supply',
    () {
      final c = campaignAtMountain();
      openStandardHouse(c.state);
      c.syncRefuge();
      expect(c.regions['farm']!.npcs, isEmpty);
      c.state
        ..x = 13
        ..z = 12;
      for (final region in c.regions.values) {
        region.difficulty = HazardDifficulty.tense;
        region.normalizeRefugeOccupants();
      }
      c.syncRefuge();
      expect(c.state.refugeUnlocked, false);
      expect(c.state.refugeContains(c.state.x, c.state.z), false);
      expect(c.regions['farm']!.npcs.map((n) => n['id']), contains('takosan'));
      expect(c.state.seenEvents, isNot(contains('refuge_ready')));
    },
  );
  test('completed standard reports cannot bypass a newly selected highest difficulty', () {
    final s = mountain();
    openStandardHouse(s);
    report(s, 'yametaro');
    report(s, 'takosan');
    expect(s.refugeComplete, true);
    final harder = restoreHazardCheckpoint(
      saved(s),
      s.map,
      {},
      difficulty: HazardDifficulty.tense,
    );
    expect(harder.livingEnemies, greaterThan(0));
    expect(harder.refugeUnlocked, false);
    expect(harder.refugeComplete, false);
    // Preserve the completed conversations while combat requirements are unmet.
    expect(harder.refugeReports, {'yametaro', 'takosan'});
  });
  for (final difficulty in [
    HazardDifficulty.standard,
    HazardDifficulty.tense,
  ]) {
    test(
      'legacy farm save at evacuated merchant position restores ($difficulty)',
      () {
        final c = campaignAtMountain();
        openStandardHouse(c.state);
        backToFarm(c);
        expect(c.state.npcs, isEmpty);
        c.state
          ..x = -13
          ..z = -17.8
          ..health = 71
          ..beers = 4;
        final legacy =
            jsonDecode(jsonEncode(c.checkpoint())) as Map<String, dynamic>;
        for (final region in (legacy['regions'] as Map).values) {
          (region['seenEvents'] as List).remove('refuge_ready');
          expect(region['seenEvents'], contains('giant_defeated'));
        }
        final restored = HazardCampaign.restore(
          legacy,
          worlds(),
          {},
          difficulty: difficulty,
        );
        final farm = restored.state;
        expect(farm.zoneId, 'farm');
        expect(farm.difficulty, difficulty);
        expect(farm.blocked(farm.x, farm.z, farm.y), false);
        expect(farm.health, 71);
        expect(farm.beers, 4);
        final dead = restored.regions.values.fold<int>(
          0,
          (count, region) =>
              count + region.enemies.where((e) => !e.alive).length,
        );
        expect(dead, 1);
        expect(farm.kills, dead);
        expect(restored.regions['mountain']!.bossAlive, false);
        expect(restored.regions['mountain']!.livingEnemies, 5);
        if (difficulty == HazardDifficulty.standard) {
          expect(farm.npcs, isEmpty);
          expect((farm.x, farm.z), (-13.0, -17.8));
          expect(restored.regions['mountain']!.refugeUnlocked, true);
        } else {
          expect(farm.npcs.map((n) => n['id']), contains('takosan'));
          expect(farm.x, -13);
          expect(farm.z, closeTo(-19.1, .0001));
          expect(restored.regions['mountain']!.refugeUnlocked, false);
          // The migrated position must permit actual replenishment immediately.
          farm.startDialogue('takosan');
          expect(farm.phase, PlayPhase.dialogue);
          finishLines(farm);
          farm.chooseDialogue('trade:ammo');
          expect(farm.beers, 2);
          expect(farm.tradePurchases['ammo'], 1);
          farm.endDialogue();
        }
        final savedAgain = HazardCampaign.restore(
          jsonDecode(jsonEncode(restored.checkpoint())),
          worlds(),
          {},
          difficulty: difficulty,
        );
        expect(savedAgain.state.kills, 1);
        expect(
          savedAgain.state.blocked(savedAgain.state.x, savedAgain.state.z, 0),
          false,
        );
        expect(savedAgain.state.x, farm.x);
        expect(savedAgain.state.z, farm.z);
        expect(savedAgain.state.beers, farm.beers);
      },
    );
  }
}
