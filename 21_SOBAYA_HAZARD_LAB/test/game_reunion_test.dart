import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_dialogue.dart';
import 'package:sobaya_hazard_lab/game/game_voice.dart';

void main() {
  test('optional shrine conversations cannot end the demo', () {
    final s = HazardGameState(
      jsonDecode(File('assets/mountain.json').readAsStringSync()),
    );
    for (final e in s.enemies) {
      e.active = false;
      if (e.boss) {
        e.alive = false;
        e.hp = 0;
        s.kills++;
      }
    }
    s.refreshRefuge();
    for (final npc in s.npcs) {
      s
        ..x = (npc['x'] as num).toDouble()
        ..z = (npc['z'] as num).toDouble() - 1.2;
      s.startDialogue(npc['id']);
      expect(s.phase, PlayPhase.dialogue);
      while (!s.dialogueChoices) {
        s.advanceDialogue();
      }
      s.endDialogue();
      expect(s.phase, PlayPhase.playing);
      expect(s.refugeComplete, false);
      expect(s.seenEvents, isNot(contains('facility_discovered')));
    }
  });
  test('shop stays in the residential quarter after the giant is defeated', () {
    final s = HazardGameState(
      jsonDecode(File('assets/farm.json').readAsStringSync()),
    );
    s.seenEvents.addAll(['giant_defeated', 'refuge_ready']);
    expect(s.npcs.any((n) => n['id'] == 'takosan'), true);
    expect(s.evacuationStarted, false);
  });
  test('shrine dialogue has matching speech and reveals no engine', () {
    final catalog = VoiceCatalog(
      jsonDecode(File('assets/audio/voice-manifest.json').readAsStringSync()),
    );
    for (final table in [
      mountainYametaroBefore,
      mountainYametaroAfter,
      mountainTakosanAfter,
    ]) {
      for (final lines in table.values) {
        for (final line in lines) {
          expect(line.text, isNot(contains('エンジン')));
          expect(catalog.seconds(line.speaker, line.text), greaterThan(0));
        }
      }
    }
  });
}
