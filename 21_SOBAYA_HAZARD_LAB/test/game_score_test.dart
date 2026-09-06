import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_soundscape.dart';
import 'package:sobaya_hazard_lab/game/game_voice.dart';
import 'package:sobaya_hazard_lab/game/game_fx_palette.dart';
import 'package:sobaya_hazard_lab/game/game_settings.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';

class LoopPort implements VoicePort {
  final calls = <String>[];
  @override
  Future<void> load(String asset) async {
    calls.add('load:$asset');
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
  }

  @override
  Future<void> volume(double gain) async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  test(
    'alert crossfade holds briefly, fades back and never reloads the score',
    () async {
      final ports = <LoopPort>[];
      final music = HazardSoundscape(
        createPort: (_) {
          final p = LoopPort();
          ports.add(p);
          return p;
        },
      );
      void advance(
        double seconds, {
        bool threat = false,
        bool speaking = false,
        bool active = true,
      }) {
        for (var t = 0.0; t < seconds; t += .02) {
          music.tick(
            .02,
            zone: 'village',
            active: active,
            threat: threat,
            speaking: speaking,
            volume: 1,
            musicVolume: 1,
          );
        }
      }

      advance(.1);
      await Future.wait([
        music.ambience.idle,
        music.exploration.idle,
        music.tension.idle,
      ]);
      expect(music.exploration.inspect()['volume'], .4);
      expect(music.tension.inspect()['paused'], false);
      advance(4, threat: true);
      expect(music.intensity, greaterThan(.98));
      advance(2);
      expect(music.intensity, greaterThan(.98));
      advance(12);
      expect(music.intensity, lessThan(.015));
      advance(1, speaking: true);
      expect(music.duck, lessThan(.34));
      final clock = music.intensity;
      advance(4, active: false);
      expect(music.intensity, clock);
      expect(music.exploration.inspect()['paused'], true);
      advance(.1);
      await Future.wait([
        music.ambience.idle,
        music.exploration.idle,
        music.tension.idle,
      ]);
      expect(ports.length, 3);
      expect(
        ports.every(
          (p) => p.calls.where((c) => c.startsWith('load:')).length == 1,
        ),
        true,
      );
      await music.dispose();
    },
  );
  test('effects rotate variants; beer moans do not stack and restart clock resets gate', () {
    final p = HazardFxPalette();
    expect(
      [for (var i = 0; i < 4; i++) p.select('shot', i.toDouble())],
      ['shot_0', 'shot_1', 'shot_2', 'shot_0'],
    );
    expect(p.select('enemy', 5), 'enemy_0');
    expect(p.select('enemy', 5.1), null);
    expect(p.select('mug_hit', 5.2), 'mug_hit_0');
    expect(p.select('enemy', 8.3), 'enemy_1');
    expect(p.select('enemy', 0), 'enemy_2');
  });
  test(
    'legacy environment gain maps to music; independent gains roundtrip',
    () {
      final s = HazardSettings.decode('{"environmentVolume":0.3}');
      expect(s.musicVolume, .3);
      s.effectsVolume = .4;
      s.musicVolume = .7;
      final restored = HazardSettings.decode(s.encode());
      expect(restored.effectsVolume, .4);
      expect(restored.musicVolume, .7);
      expect(restored.environmentVolume, .3);
    },
  );
  test('mug movement starts before contact; impact only sounds on a hit', () {
    HazardGameState game() {
      final s = HazardGameState(
        jsonDecode(File('assets/village.json').readAsStringSync()),
      );
      for (final e in s.enemies) {
        e.active = false;
      }
      s.enemies[1]
        ..active = true
        ..alerted = true
        ..x = 0
        ..z = -20;
      s.drainSounds();
      return s;
    }

    for (final dodge in [false, true]) {
      final s = game();
      s.tick(.02);
      expect(s.drainSounds().any((e) => e.name == 'mug_ready'), true);
      for (var i = 0; i < 36; i++) {
        s.tick(.02);
      }
      expect(s.drainSounds().any((e) => e.name == 'mug_swing'), false);
      s.tick(.02);
      expect(s.drainSounds().any((e) => e.name == 'mug_swing'), true);
      if (dodge) {
        s.x = 4;
      }
      for (var i = 0; i < 7; i++) {
        s.tick(.02);
      }
      expect(s.drainSounds().any((e) => e.name == 'mug_hit'), !dodge);
    }
  });
}
