import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_dialogue.dart';
import 'package:sobaya_hazard_lab/game/game_events.dart';
import 'package:sobaya_hazard_lab/game/game_tutorial_text.dart';
import 'package:sobaya_hazard_lab/game/game_voice.dart';

void main() {
  final manifest = jsonDecode(
    File('assets/audio/voice-manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final catalog = VoiceCatalog(manifest);
  final clips = (manifest['clips'] as List).cast<Map<String, dynamic>>();
  final exported = (jsonDecode(
    File('../04_GAME_ASSETS/audio/hazard/voice-lines.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();

  void expectSpeech(String speaker, String text, String usage) {
    // Check the manifest itself: cue() has an intentional generic response
    // fallback for Takosan that must never pass an authored-dialogue audit.
    final exact = clips.where(
      (clip) => clip['speaker'] == speaker && clip['text'] == text,
    );
    expect(exact, hasLength(1), reason: 'Missing exact speech: $usage');
    final clip = exact.single;
    expect(clip['kind'], 'speech');
    expect(clip['uses'], contains(usage));
    expect(clip['seconds'], greaterThan(.5));
    expect(File('assets/${clip['asset']}').existsSync(), true);
    expect(catalog.cue(usage, speaker, text)!.asset, clip['asset']);
    expect(
      exported
          .where((row) => row['speaker'] == speaker && row['text'] == text)
          .single['uses'],
      contains(usage),
    );
  }

  test('every tutorial step has its exact canonical spoken coaching', () {
    expect(tutorialCoachLines.keys, [
      'move',
      'aim',
      'shoot',
      'reload',
      'sneak',
      'escape',
      'complete',
    ]);
    for (final entry in tutorialCoachLines.entries) {
      expectSpeech('やめ太郎', entry.value, 'tutorial:${entry.key}');
    }
  });

  test('farm mission request and both completion states have exact speech', () {
    for (final entry in farmMissionDialogue.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        final line = entry.value[i];
        expectSpeech(
          line.speaker,
          line.text,
          'dialogue:farm_mission:${entry.key}:$i',
        );
      }
    }
  });

  test('restructured chapter event indices retain matching audio clocks', () {
    for (final event in ['opening', 'chapter1intro', 'farm']) {
      final shots = hazardEvents[event]!;
      for (var i = 0; i < shots.length; i++) {
        final shot = shots[i], usage = 'event:$event:$i';
        expectSpeech(shot.voiceSpeaker, shot.text, usage);
        expect(
          catalog.eventSeconds[usage],
          catalog.seconds(shot.voiceSpeaker, shot.text),
        );
      }
    }
  });
}
