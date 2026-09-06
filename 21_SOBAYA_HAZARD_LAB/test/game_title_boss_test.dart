import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_settings.dart';
import 'package:sobaya_hazard_lab/game/game_events.dart';
import 'package:sobaya_hazard_lab/game/game_voice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('title logo is bundled and preserves generated PNG alpha', () async {
    final bytes = await rootBundle.load('assets/cinematics/title_logo.png');
    expect(bytes.getUint32(0), 0x89504e47);
    expect(bytes.getUint8(25), 6); // RGBA, not an opaque checkerboard.
  });
  test(
    'title call has exact canonical spoken audio and enough playback time',
    () {
      final shot = hazardEvents['title_call']!.single;
      final catalog = VoiceCatalog(
        jsonDecode(File('assets/audio/voice-manifest.json').readAsStringSync()),
      );
      expect(shot.text, 'そば屋ハザード。');
      expect(catalog.cue('title', shot.voiceSpeaker, shot.text), isNotNull);
      final director = HazardDirector(
        'title_call',
        voiceSeconds: catalog.eventSeconds,
      );
      expect(
        director.duration,
        greaterThan(catalog.seconds(shot.voiceSpeaker, shot.text)),
      );
    },
  );
  test(
    'giant head at five metres is hittable and body hits remain body hits',
    () {
      for (final part in ShotPart.values.where((p) => p != ShotPart.mug)) {
        final s = HazardGameState(
          jsonDecode(File('assets/mountain.json').readAsStringSync()),
          difficulty: HazardDifficulty.tense,
        );
        s.obstacles.clear();
        s.crates.clear();
        for (final e in s.enemies) {
          e.active = false;
        }
        s.x = 6;
        s.z = 4;
        s.aiming = true;
        s.pistolLoaded = 2;
        final boss = s.enemies.firstWhere((e) => e.boss)..active = true;
        final aim = vm.Vector3(
          boss.x,
          part == ShotPart.head ? boss.headHeight : boss.targetHeight,
          boss.z,
        );
        s.shoot(vm.Vector3(s.x, 1.25, s.z), aim - vm.Vector3(s.x, 1.25, s.z));
        expect(s.lastShotPart, part);
        expect(boss.hp, 900 - s.bulletDamage(part));
      }
    },
  );
  test('highest difficulty village can clear with Yame supplies before first merchant', () {
    final s = HazardGameState(
      jsonDecode(File('assets/village.json').readAsStringSync()),
      difficulty: HazardDifficulty.tense,
    );
    expect(s.npcs.any((n) => n['id'] == 'takosan'), false);
    for (final e in s.enemies) {
      e.active = false;
    }
    s.x = -2.8;
    s.z = -23;
    s.startDialogue('yametaro');
    while (!s.dialogueChoices) {
      s.advanceDialogue();
    }
    s.chooseDialogue('supplies');
    expect(s.reserve, 25);
    expect(s.dialogueLine.text, contains('二十五発'));
    final free =
        s.loaded +
        s.reserve +
        s.pickups
            .where((p) => p.kind == 'ammo')
            .fold<int>(0, (n, p) => n + s.pickupAmount(p));
    expect(free, greaterThanOrEqualTo(s.enemies.length * 3));
    expect(free - 25, lessThan(s.enemies.length * 3));
  });
}
