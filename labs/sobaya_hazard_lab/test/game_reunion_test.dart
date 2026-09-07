import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_campaign.dart';
import 'package:sobaya_hazard_lab/game/game_dialogue.dart';
import 'package:sobaya_hazard_lab/game/game_settings.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_voice.dart';
import 'package:vector_math/vector_math.dart' as vm;

Map<String, Map<String, dynamic>> maps() => {
  for (final id in ['village', 'farm', 'mountain'])
    id: jsonDecode(File('assets/$id.json').readAsStringSync()),
};

HazardGameState mountain({bool defeated = true, bool hardest = false}) {
  final s = HazardGameState(
    maps()['mountain']!,
    difficulty: hardest ? HazardDifficulty.tense : HazardDifficulty.standard,
  );
  for (final e in s.enemies) {
    e.active = false;
  }
  if (defeated) {
    final boss = s.enemies.singleWhere((e) => e.boss);
    boss
      ..alive = false
      ..hp = 0
      ..dropped = true;
    s.kills = 1;
  }
  return s;
}

void talk(HazardGameState s, String who) {
  final n = s.npcs.singleWhere((n) => n['id'] == who);
  s
    ..x = (n['x'] as num).toDouble()
    ..z = (n['z'] as num).toDouble() - 1.2;
  s.startDialogue(who);
  expect(s.phase, PlayPhase.dialogue);
}

void finishLines(HazardGameState s) {
  while (!s.dialogueChoices) {
    s.advanceDialogue();
  }
}

void main() {
  test(
    'all mountain dialogue has full spoken audio, including remaining enemies',
    () {
      final catalog = VoiceCatalog(
        jsonDecode(File('assets/audio/voice-manifest.json').readAsStringSync()),
      );
      final lines = [
        for (final table in [
          mountainYametaroBefore,
          mountainYametaroAfter,
          mountainTakosanAfter,
        ])
          for (final topic in table.values) ...topic,
        mountainRemainingLine,
        mountainRemainingTakoLine,
      ];
      for (final line in lines) {
        // A generic Takosan response is not a substitute for this spoken line.
        expect(
          catalog.seconds(line.speaker, line.text),
          greaterThan(1),
          reason: line.text,
        );
        final cue = catalog.cue('reunion-qa', line.speaker, line.text)!;
        expect(File('assets/${cue.asset}').existsSync(), true);
      }
    },
    tags: ['voice-assets'],
  );

  test('Takosan appears inside the house only after the real boss kill', () {
    final s = mountain(defeated: false);
    expect(s.npcs, isEmpty);
    final boss = s.enemies.singleWhere((e) => e.boss);
    boss
      ..active = true
      ..stun = 30;
    s.addItem('rocket', 1);
    s.equip('rocket');
    s
      ..phase = PlayPhase.playing
      ..x = 6
      ..z = 4
      ..yaw = -1.5707963267948966
      ..pitch = -.27
      ..aiming = true;
    for (var shot = 0; shot < 3; shot++) {
      s.updateRocketLock(
        vm.Vector3(6, 1.25, 4),
        vm.Vector3(6, 1.75, 0),
        fovY: .8,
        aspect: 1.5,
      );
      expect(s.rocketLockId, boss.id);
      s.shoot(vm.Vector3(6, 1.25, 4), vm.Vector3(1, 0, 0));
      for (var frame = 0; frame < 100; frame++) {
        s.tick(1 / 60);
      }
    }
    expect(s.shots, 3);
    expect(boss.alive, false);
    expect(s.seenEvents, contains('giant_defeated'));
    final tako = s.npcs.singleWhere((n) => n['id'] == 'takosan');
    expect(tako['x'], inInclusiveRange(7.5, 18.5));
    expect(tako['z'], inInclusiveRange(10, 18));
    expect(
      s.blocked(
        (tako['x'] as num).toDouble(),
        (tako['z'] as num).toDouble() - 1.2,
        0,
      ),
      false,
    );
    expect(s.objective, contains('家'));
    expect(s.refugeUnlocked, true);
    expect(s.refugeComplete, false); // Both reports are still required.
  });

  test(
    'all mountain choices stay in their chapter before and after the boss',
    () {
      final before = mountain(defeated: false)
        ..x = 16
        ..z = 16.3;
      before.startDialogue('yametaro');
      expect(before.npcs, isEmpty);
      expect(before.phase, PlayPhase.playing);
      expect(before.refugeReports, isEmpty);
      for (final who in ['yametaro', 'takosan']) {
        final s = mountain();
        talk(s, who);
        expect(s.dialogueTopic, 'reunion');
        final table = who == 'takosan'
            ? mountainTakosanAfter
            : mountainYametaroAfter;
        for (final topic in s.availableDialogueTopics) {
          finishLines(s);
          s.chooseDialogue(topic);
          expect(s.dialogueLines, table[topic]);
        }
        finishLines(s);
        s.chooseDialogue('supplies');
        expect(s.dialogueTopic, 'evidence');
        s.endDialogue();
        talk(s, who);
        expect(s.dialogueTopic, 'greeting');
      }
    },
  );

  test('highest difficulty keeps the house closed until all enemies fall', () {
    final s = mountain(hardest: true);
    s.refreshRefuge();
    expect(s.refugeUnlocked, false);
    expect(s.npcs, isEmpty);
    expect(s.objective, contains('農場'));
    for (final e in s.enemies) {
      e
        ..alive = false
        ..hp = 0;
    }
    s.refreshRefuge();
    expect(s.refugeUnlocked, true);
    expect(s.npcs.map((n) => n['id']), containsAll(['yametaro', 'takosan']));
    talk(s, 'takosan');
    finishLines(s);
    s.chooseDialogue('route');
    expect(s.dialogueLines, mountainTakosanAfter['route']);
    expect(s.dialogueLine.text, isNot(contains('東の門')));
  });

  test(
    'reunion shop keeps real beer payments and successful purchase dialogue',
    () {
      final s = mountain()..beers = 10;
      talk(s, 'takosan');
      finishLines(s);
      expect(s.visibleTradeOffers.map((o) => o.id), contains('rocket'));
      s.chooseDialogue('trade:ammo');
      expect(s.beers, 8);
      expect(s.dialogueTopic, 'trade_result');
      expect(s.dialogueLine.text, purchaseLines['ammo']!.text);
      finishLines(s);
      s.chooseDialogue('route');
      expect(s.dialogueLines, mountainTakosanAfter['route']);
    },
  );

  test('legacy defeated-boss saves relocate NPCs; backtracking never duplicates them', () {
    final c = HazardCampaign(maps());
    for (var i = 0; i < 2; i++) {
      c.state.exitRequested = Map<String, dynamic>.from(
        (c.state.map['exits'] as List).last,
      );
      c.state.phase = PlayPhase.transition;
      expect(c.traverse(), true);
    }
    final boss = c.state.enemies.singleWhere((e) => e.boss);
    boss
      ..alive = false
      ..hp = 0
      ..dropped = true;
    c.state.kills = 1;
    final restored = HazardCampaign.restore(c.checkpoint(), maps(), {});
    expect(restored.state.npcs.map((n) => n['id']), contains('takosan'));
    talk(restored.state, 'takosan');
    finishLines(restored.state);
    restored.state.endDialogue();
    restored.state.exitRequested = Map<String, dynamic>.from(
      (restored.state.map['exits'] as List).first,
    );
    restored.state.phase = PlayPhase.transition;
    expect(restored.traverse(), true);
    expect(restored.state.zoneId, 'farm');
    expect(restored.state.npcs, isEmpty);
    final loaded = HazardCampaign.restore(restored.checkpoint(), maps(), {});
    expect(loaded.state.npcs, isEmpty);
    loaded.state.exitRequested = Map<String, dynamic>.from(
      (loaded.state.map['exits'] as List).last,
    );
    loaded.state.phase = PlayPhase.transition;
    expect(loaded.traverse(), true);
    talk(loaded.state, 'takosan');
    expect(loaded.state.dialogueTopic, 'greeting');
  });
}
