import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_voice.dart';
import 'package:sobaya_hazard_lab/game/game_events.dart';

class FakeVoice implements VoicePort {
  FakeVoice(this.complete, {this.gate, this.fail = false});
  final void Function() complete;
  final Completer<void>? gate;
  final bool fail;
  final calls = <String>[];
  @override
  Future<void> load(String asset) async {
    calls.add('load:$asset');
    await gate?.future;
    if (fail) throw StateError('missing asset');
  }

  @override
  Future<void> volume(double gain) async => calls.add('volume:$gain');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> dispose() async => calls.add('dispose');
}

void main() {
  test(
    'unresponsive audio backend cannot hold a cutscene indefinitely',
    () async {
      final gate = Completer<void>();
      late FakeVoice port;
      final voice = VoiceSession(
        (done) => port = FakeVoice(done, gate: gate),
        loadTimeout: const Duration(milliseconds: 10),
      );
      voice.sync(const VoiceCue('slow', 'slow.wav'), paused: false, volume: 1);
      await voice.idle;
      expect(voice.loading, false);
      expect(voice.errors.single, contains('TimeoutException'));
      gate.complete();
      await voice.dispose();
      expect(port.calls, isNot(contains('resume')));
    },
  );
  test('skipping a slow load never starts the obsolete line', () async {
    final gate = Completer<void>(), players = <FakeVoice>[];
    final voice = VoiceSession((done) {
      final p = FakeVoice(done, gate: players.isEmpty ? gate : null);
      players.add(p);
      return p;
    });
    voice.sync(const VoiceCue('old', 'old.wav'), paused: false, volume: 1);
    expect(voice.loading, true);
    voice.sync(const VoiceCue('new', 'new.wav'), paused: false, volume: 1);
    gate.complete();
    await voice.idle;
    expect(players.first.calls, isNot(contains('resume')));
    expect(players.first.calls.last, 'dispose');
    expect(players.last.calls.last, 'resume');
    players.first.complete();
    expect(voice.speaking, true);
    players.last.complete();
    expect(voice.speaking, false);
    await voice.dispose();
  });
  test(
    'pause preserves clip; changing volume never replays a finished line',
    () async {
      final players = <FakeVoice>[];
      final voice = VoiceSession((done) {
        final p = FakeVoice(done);
        players.add(p);
        return p;
      });
      const cue = VoiceCue('one', 'one.wav');
      voice.sync(cue, paused: false, volume: 1);
      await voice.idle;
      voice.sync(cue, paused: true, volume: 1);
      await voice.idle;
      expect(players.single.calls.last, 'pause');
      voice.sync(cue, paused: false, volume: .5);
      await voice.idle;
      expect(players.single.calls.last, 'resume');
      players.single.complete();
      final resumes = players.single.calls.where((x) => x == 'resume').length;
      voice.sync(cue, paused: false, volume: .2);
      await voice.idle;
      expect(players.single.calls.where((x) => x == 'resume').length, resumes);
      await voice.dispose();
      expect(players.single.calls.last, 'dispose');
    },
  );
  test('dispose during load cancels playback and releases player', () async {
    final gate = Completer<void>();
    late FakeVoice port;
    final voice = VoiceSession((done) => port = FakeVoice(done, gate: gate));
    voice.sync(const VoiceCue('a', 'a.wav'), paused: false, volume: 1);
    final disposed = voice.dispose();
    gate.complete();
    await disposed;
    expect(port.calls, isNot(contains('resume')));
    expect(port.calls.last, 'dispose');
    expect(voice.loading, false);
  });
  test(
    'load failure releases cinematic clock and preserves subtitle timing',
    () async {
      final voice = VoiceSession((done) => FakeVoice(done, fail: true));
      voice.sync(
        const VoiceCue('missing', 'missing.wav'),
        paused: false,
        volume: 1,
      );
      await voice.idle;
      expect(voice.loading, false);
      expect(voice.speaking, false);
      expect(voice.errors, hasLength(1));
      await voice.dispose();
    },
  );
  test('cutscene allows full voice duration plus breathing room', () {
    final d = HazardDirector('opening', voiceSeconds: {'event:opening:1': 9.2});
    d.next();
    expect(d.duration, 9.7);
    for (var i = 0; i < 180; i++) {
      d.tick(.05);
    }
    expect(d.index, 1);
    expect(d.progress, lessThan(1));
    for (var i = 0; i < 15; i++) {
      d.tick(.05);
    }
    expect(d.index, 2);
  });
}
