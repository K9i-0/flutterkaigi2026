import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_story.dart';
import 'package:sobaya_hazard_lab/game/game_campaign.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';
import 'package:sobaya_hazard_lab/game/game_journal.dart';

import 'game_companion_test.dart' show encounter, advance;

Map<String, Map<String, dynamic>> maps() => {
  for (final id in ['village', 'farm', 'mountain'])
    id: jsonDecode(File('assets/$id.json').readAsStringSync()),
};

void main() {
  test('all memos can be collected with normal interaction on their floor', () {
    for (final m in villageMemos) {
      final s = HazardGameState(maps()[m.zone]!);
      for (final e in s.enemies) {
        e.active = false;
      }
      var found = false;
      for (var dx = -1.0; dx <= 1; dx += .25) {
        for (var dz = -1.0; dz <= 1; dz += .25) {
          s.x = m.x + dx;
          s.z = m.z + dz;
          s.y = s.floorHeight(s.x, s.z, m.y);
          if (s.blocked(s.x, s.z, s.y) || (s.y - m.y).abs() > .3) continue;
          s.interact();
          if (s.foundMemos.contains(m.id)) {
            found = true;
            break;
          }
        }
        if (found) break;
      }
      expect(found, true, reason: 'Unreachable memo ${m.id}');
      expect(s.checkpointRequested, true);
      expect(
        s.phase,
        PlayPhase.playing,
        reason: 'Reading must be optional during combat',
      );
    }
  });
  test('notes survive round trip and save, reset posters independently, support legacy saves', () {
    final c = HazardCampaign(maps(), collection: {'wanted'});
    c.state.foundMemos.add('proposal');
    void travel(int exit) {
      c.state.exitRequested = Map<String, dynamic>.from(
        (c.state.map['exits'] as List)[exit],
      );
      c.state.phase = PlayPhase.transition;
      expect(c.traverse(), true);
    }

    travel(0);
    c.state.foundMemos.add('returns');
    travel(0);
    expect(c.state.zoneId, 'village');
    final loaded = HazardCampaign.restore(c.checkpoint(), maps(), {'wanted'});
    expect(loaded.state.foundMemos, {'proposal', 'returns'});
    loaded.resetCollection();
    expect(loaded.state.foundMemos, {'proposal', 'returns'});
    expect(loaded.state.collected, isEmpty);
    final legacy = loaded.state.checkpoint()..remove('foundMemos');
    expect(
      restoreHazardCheckpoint(legacy, maps()['village']!, {}).foundMemos,
      isEmpty,
    );
    legacy['foundMemos'] = ['unknown'];
    expect(
      () => restoreHazardCheckpoint(legacy, maps()['village']!, {}),
      throwsFormatException,
    );
    loaded.restart();
    expect(loaded.state.foundMemos, isEmpty);
  });
  test('evidence discussion unlocks only after finding its actual memo', () {
    for (final id in ['yametaro', 'takosan']) {
      final s = HazardGameState(maps()['village']!)
        ..talkingTo = id
        ..dialogueOwner = id
        ..dialogueTopic = 'greeting'
        ..phase = PlayPhase.dialogue;
      s.chooseDialogue('evidence');
      expect(s.dialogueTopic, 'greeting');
      s.foundMemos.add(id == 'yametaro' ? 'campaign' : 'returns');
      s.chooseDialogue('evidence');
      expect(s.dialogueTopic, 'evidence');
      expect(s.dialogueLines.length, greaterThan(1));
    }
  });
  test('real companion impacts emit character cries; fatal cry preempts a playing line', () {
    for (final region in ['village', 'farm']) {
      final s = encounter(region);
      advance(s, 1);
      expect(s.reaction?.speaker, region == 'village' ? 'やめ太郎' : 'たこさん');
      expect(s.reactionTime, greaterThan(0));
      expect(s.phase, PlayPhase.playing);
      final first = s.reactionSerial;
      advance(s, 4.8);
      expect(s.fallenCompanion, isNotNull);
      expect(s.reactionSerial, greaterThan(first));
      expect(s.reaction!.text, contains('福ちゃん'));
    }
  });
  test(
    'engine topic follows discovered information, including backtracking',
    () {
      final s = HazardGameState(maps()['village']!)
        ..talkingTo = 'yametaro'
        ..dialogueTopic = 'greeting'
        ..phase = PlayPhase.dialogue;
      expect(s.knowsEngine, false);
      s.chooseDialogue('engine');
      expect(s.dialogueTopic, 'greeting');
      s.foundMemos.add('night_shift');
      s.chooseDialogue('engine');
      expect(s.dialogueTopic, 'engine');
      s.foundMemos.clear();
      s.seenEvents.add('farm');
      expect(s.knowsEngine, true);
    },
  );
  test('entering safe dialogue clears an old combat cry', () {
    final s = HazardGameState(maps()['village']!);
    for (final e in s.enemies) {
      e.active = false;
    }
    s.companionHealth['yametaro'] = 40;
    s.reactToCompanionHit('yametaro');
    final npc = s.npcs.first;
    s.x = (npc['x'] as num).toDouble();
    s.z = (npc['z'] as num).toDouble() - .8;
    s.startDialogue('yametaro');
    expect(s.phase, PlayPhase.dialogue);
    expect(s.reaction, isNull);
    expect(s.reactionTime, 0);
  });
  testWidgets(
    'journal hides unknown lore and opens a collected memo without overflow',
    (tester) async {
      final s = HazardCampaign(maps()).state..foundMemos.add('proposal');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(color: Colors.black, child: HazardJournal(s)),
          ),
        ),
      );
      expect(find.text('03｜動力用クローン・飼育台帳'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('journal-memo-proposal')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('journal-reader-text')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('journal-reader-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('journal-reader-text')), findsNothing);
    },
  );
}
