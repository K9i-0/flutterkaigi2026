import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_soundscape.dart';
import 'package:sobaya_hazard_lab/game/game_audio.dart';

import 'game_score_test.dart' show LoopPort;

void main() {
  HazardSoundscape music() => HazardSoundscape(createPort: (_) => LoopPort());
  int advance(
    HazardSoundscape score,
    double seconds,
    String phase, {
    bool active = true,
    bool speaking = false,
    double suspicion = 1,
  }) {
    var accents = 0;
    for (var tick = 0; tick < (seconds / .02).round(); tick++) {
      if (score.tick(
        .02,
        zone: 'village',
        active: active,
        phase: phase,
        speaking: speaking,
        volume: 1,
        suspicion: suspicion,
      )) {
        accents++;
      }
    }
    return accents;
  }

  test('search exposes spatial sounds by removing percussion, without dropping suspense', () async {
    final score = music();
    expect(advance(score, 3, 'chasing'), 1);
    expect(score.tension.inspect()['volume'], .5);
    advance(score, 2.5, 'searching');
    expect(score.tension.inspect()['volume'], lessThan(.01));
    expect(score.searching.inspect()['volume'], greaterThan(.14));
    expect(score.intensity, greaterThan(.6));
    expect(score.ambience.inspect()['volume'], lessThan(.17));
    advance(score, 1, 'searching', speaking: true);
    expect(score.searching.inspect()['volume'], lessThan(.05));
    await score.dispose();
  });

  test('long search and reacquisition remain one encounter; sustained safety rearms accent', () async {
    final score = music();
    expect(advance(score, 2, 'chasing'), 1);
    expect(advance(score, 22, 'searching'), 0);
    expect(advance(score, 3, 'chasing'), 0);
    expect(advance(score, 2, 'returning'), 0);
    expect(advance(score, 1, 'chasing'), 0);
    advance(score, 4, 'returning');
    expect(advance(score, .1, 'chasing'), 1);
    await score.dispose();
  });

  test(
    'brief occlusion and paused safety cannot retrigger or restart music',
    () async {
      final ports = <LoopPort>[];
      final score = HazardSoundscape(
        createPort: (_) {
          final port = LoopPort();
          ports.add(port);
          return port;
        },
      );
      expect(advance(score, 2, 'chasing'), 1);
      final rhythm = score.pursuitMix;
      advance(score, .3, 'searching');
      expect(score.pursuitMix, greaterThanOrEqualTo(rhythm));
      expect(advance(score, .3, 'chasing'), 0);
      final beforePause = score.inspect();
      advance(score, 20, 'calm', active: false);
      expect(score.inspect()['phase'], beforePause['phase']);
      expect(score.inspect()['safeTime'], beforePause['safeTime']);
      expect(advance(score, .3, 'chasing'), 0);
      await Future.wait([
        score.ambience.idle,
        score.exploration.idle,
        score.tension.idle,
        score.searching.idle,
      ]);
      expect(ports, hasLength(4));
      for (final port in ports) {
        expect(
          port.calls.where((call) => call.startsWith('load:')),
          hasLength(1),
        );
      }
      await score.dispose();
    },
  );

  test('calm ignores suspicion data; only public suspicious feedback introduces unease', () async {
    final score = music();
    expect(advance(score, 10, 'calm', suspicion: 1), 0);
    expect(score.intensity, 0);
    expect(score.tension.inspect()['volume'], 0);
    expect(score.searching.inspect()['volume'], 0);
    expect(advance(score, 5, 'suspicious'), 0);
    expect(score.searching.inspect()['volume'], greaterThan(.08));
    expect(score.tension.inspect()['volume'], 0);
    expect(score.intensity, closeTo(.28, .001));
    await score.dispose();
  });

  test('stealth Foley assets resolve and enemy footsteps remain spatial behind cover', () {
    for (final cue in ['enemy_step', 'beer_throw', 'beer_land']) {
      final bytes = File('assets/audio/combat/$cue.wav').readAsBytesSync();
      final pcm = ByteData.sublistView(bytes);
      expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
      expect(pcm.getUint16(22, Endian.little), 1);
      expect(pcm.getUint32(24, Endian.little), 24000);
      expect(bytes.length, greaterThan(17000));
    }
    const step = HazardSound('enemy_step', x: 0, y: .1, z: 0);
    expect(step.gain(3, 0), greaterThan(step.gain(9, 0)));
    expect(
      step.gain(3, 0, occluded: true),
      closeTo(step.gain(3, 0) * .35, .0001),
    );
    expect(step.gain(25, 0), 0);
  });

  test(
    'search score is adopted stereo PCM with a quiet continuous loop seam',
    () {
      final manifest = jsonDecode(
        File('../04_GAME_ASSETS/audio/hazard/search-score-manifest.json')
            .readAsStringSync(),
      );
      final row = manifest['files'].first;
      final bytes = File('assets/audio/${row['file']}').readAsBytesSync();
      final pcm = ByteData.sublistView(bytes);
      expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
      expect(pcm.getUint16(22, Endian.little), 2);
      expect(pcm.getUint32(24, Endian.little), 44100);
      expect(pcm.getUint16(34, Endian.little), 16);
      expect(bytes.length - 44, 48 * 44100 * 4);
      var seam = 0;
      var peak = 0;
      for (var channel = 0; channel < 2; channel++) {
        final delta =
            (pcm.getInt16(44 + channel * 2, Endian.little) -
                    pcm.getInt16(bytes.length - 4 + channel * 2, Endian.little))
                .abs();
        if (delta > seam) seam = delta;
      }
      for (var i = 44; i < bytes.length; i += 2) {
        final value = pcm.getInt16(i, Endian.little).abs();
        if (value > peak) peak = value;
      }
      expect(seam, lessThan(100));
      expect(peak, lessThan(30000));
      expect(manifest['music']['percussion'], false);
    },
  );
}
