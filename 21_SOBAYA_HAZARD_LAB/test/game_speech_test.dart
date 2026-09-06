import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_speech.dart';
import 'package:sobaya_hazard_lab/game/game_voice.dart';

class ClockVoice implements VoicePort, VoicePositionClock {
  ClockVoice(this.complete);
  final void Function() complete;
  double? position;
  @override
  double? get playbackSeconds => position;
  @override
  Future<void> load(String asset) async {}
  @override
  Future<void> volume(double gain) async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  final samples = SpeechEnvelopes({
    'hz': 50,
    'clips': [
      {
        'asset': 'a.wav',
        'open': [0, 1, .5, 0, 0],
      },
    ],
  });
  test('envelopes interpolate and close outside the clip', () {
    expect(samples.sample('a.wav', .01), closeTo(.5, .00001));
    expect(samples.sample('a.wav', .03), closeTo(.75, .00001));
    expect(samples.sample('a.wav', -.1), 0);
    expect(samples.sample('a.wav', double.nan), 0);
    expect(samples.sample('a.wav', 5), 0);
    expect(samples.sample('missing', .02), 0);
  });
  test(
    'only the active speaker follows observed audio; pauses and skips close',
    () async {
      late ClockVoice port;
      final voice = VoiceSession((done) => port = ClockVoice(done));
      const cue = VoiceCue('a', 'a.wav', speaker: '福ちゃん');
      voice.sync(cue, paused: false, volume: 1);
      await voice.idle;
      expect(samples.opening(voice, '福ちゃん'), 0);
      port.position = .02;
      expect(samples.opening(voice, '福ちゃん'), 1);
      expect(samples.opening(voice, 'やめ太郎'), 0);
      voice.sync(cue, paused: true, volume: 1);
      expect(samples.opening(voice, '福ちゃん'), 0);
      await voice.idle;
      voice.sync(cue, paused: false, volume: 0);
      await voice.idle;
      // Muting audio does not erase the character's articulation.
      expect(samples.opening(voice, '福ちゃん'), 1);
      port.complete();
      expect(samples.opening(voice, '福ちゃん'), 0);
      voice.sync(
        const VoiceCue('b', 'missing', speaker: 'やめ太郎'),
        paused: false,
        volume: 1,
      );
      await voice.idle;
      port.position = .02;
      expect(samples.opening(voice, '福ちゃん'), 0);
      expect(samples.opening(voice, 'やめ太郎'), 0);
      await voice.dispose();
    },
  );
  test(
    'bundled envelopes cover exact speech files and use finite bounded values',
    () {
      final manifest = jsonDecode(
        File('assets/audio/voice-manifest.json').readAsStringSync(),
      );
      final data = jsonDecode(
        File('assets/audio/speech-envelopes.json').readAsStringSync(),
      );
      final speech = (manifest['clips'] as List).where(
        (c) => c['kind'] == 'speech',
      );
      expect(data['clips'].length, speech.length);
      for (final clip in speech) {
        final envelope = (data['clips'] as List).singleWhere(
          (c) => c['asset'] == clip['asset'],
        );
        expect(envelope['sha256'], clip['sha256']);
        expect(envelope['speaker'], clip['speaker']);
        expect(envelope['seconds'], closeTo(clip['seconds'], .001));
        final values = (envelope['open'] as List).cast<num>();
        expect(values.every((v) => v.isFinite && v >= 0 && v <= 1), true);
        expect(values.any((v) => v > .2), true);
        expect(values.last, 0);
      }
    },
  );
}
