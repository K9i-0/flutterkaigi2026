import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_audio.dart';
import 'package:sobaya_hazard_lab/game/game_fx_palette.dart';
import 'package:sobaya_hazard_lab/game/game_soundscape.dart';

import 'game_score_test.dart' show LoopPort;

void main() {
  test('fresh detection accents once; pauses and short threat gaps do not repeat it', () async {
    final music = HazardSoundscape(createPort: (_) => LoopPort());
    int advance(double seconds, {bool threat = true, bool active = true}) {
      var accents = 0;
      for (var t = 0.0; t < seconds; t += .02) {
        if (music.tick(
          .02,
          zone: 'village',
          active: active,
          threat: threat,
          speaking: false,
          volume: 1,
        )) {
          accents++;
        }
      }
      return accents;
    }

    expect(advance(.1, active: false), 0);
    expect(advance(.5), 1);
    expect(music.intensity, greaterThan(.8));
    expect(advance(5), 0);
    final intensity = music.intensity;
    expect(advance(5, active: false), 0);
    expect(music.intensity, intensity);
    expect(advance(1, threat: false), 0);
    expect(advance(1), 0);
    expect(advance(12, threat: false), 0);
    expect(advance(.1), 1);
    music.resetEncounter();
    expect(music.intensity, 0);
    expect(advance(.1), 1);
    await music.dispose();
  });

  test('weapon accent leaves dialogue duck intact and recovers without restarting music', () async {
    final music = HazardSoundscape(createPort: (_) => LoopPort());
    void tick({bool speaking = false, bool active = true}) => music.tick(
      .02,
      zone: 'village',
      active: active,
      threat: true,
      speaking: speaking,
      volume: 1,
    );
    for (var i = 0; i < 100; i++) {
      tick();
    }
    final before = music.tension.inspect()['volume'] as double;
    music.accentImpact(.01);
    expect(music.impactDuck, 1);
    music.accentImpact(1);
    tick();
    expect(music.tension.inspect()['volume'], lessThan(before * .65));
    final gain = music.impactDuck;
    for (var i = 0; i < 50; i++) {
      tick(active: false);
    }
    expect(music.impactDuck, gain);
    for (var i = 0; i < 100; i++) {
      tick(speaking: true);
    }
    expect(music.impactDuck, greaterThan(.99));
    expect(music.tension.inspect()['volume'], lessThan(.14));
    for (var i = 0; i < 200; i++) {
      tick();
    }
    expect(music.tension.inspect()['volume'], closeTo(before, .01));
    await music.dispose();
  });

  test(
    'launcher and blast rotate independently; spoken lines retain mix priority',
    () {
      final palette = HazardFxPalette();
      for (var i = 0; i < 4; i++) {
        expect(
          palette.select('rocket_launch', i * 2),
          'rocket_launch_${i % 3}',
        );
        expect(
          palette.select('rocket_blast', i * 2 + 1),
          'rocket_blast_${i % 3}',
        );
      }
      expect(
        HazardFxPalette.sourceGain('rocket_launch'),
        greaterThan(HazardFxPalette.sourceGain('shotgun')),
      );
      expect(
        HazardFxPalette.sourceGain('enemy', speaking: true),
        lessThan(.16),
      );
      expect(
        HazardFxPalette.sourceGain('mug_swing', speaking: true),
        greaterThan(.3),
      );
    },
  );

  test('large blasts remain audible at range and through cover without full-volume distance cheats', () {
    const blast = HazardSound('rocket_blast', x: 0, z: 0);
    const voice = HazardSound('enemy', x: 0, z: 0);
    expect(blast.gain(0, 0), 1);
    expect(blast.gain(15, 0), greaterThan(voice.gain(15, 0) * 3));
    expect(blast.gain(15, 0, occluded: true), lessThan(blast.gain(15, 0)));
    expect(blast.gain(25, 0), greaterThan(.1));
    expect(blast.gain(45, 0), 0);
  });

  test('all new effect variants resolve to adopted PCM assets', () {
    for (final cue in [
      'alert',
      for (var i = 0; i < 3; i++) ...['rocket_launch_$i', 'rocket_blast_$i'],
    ]) {
      final bytes = File('assets/audio/combat/$cue.wav').readAsBytesSync();
      expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
      expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE');
      expect(bytes.length, greaterThan(100000));
    }
  });
}
