import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_voice_player.dart';

/// Reproduces the 6.8.1 completion contract: native looping continues while
/// the Dart player marks completed and stops position notifications.
class LoopBackend extends Fake implements AudioPlayer {
  final completions = StreamController<void>.broadcast(sync: true);
  final durations = StreamController<Duration>.broadcast();
  PositionUpdater? updater;
  int reads = 0, resumes = 0;
  @override
  PlayerState state = PlayerState.stopped;
  @override
  set positionUpdater(PositionUpdater? value) => updater = value;
  @override
  Stream<void> get onPlayerComplete => completions.stream;
  @override
  Stream<Duration> get onPositionChanged => updater!.positionStream;
  @override
  Stream<Duration> get onDurationChanged => durations.stream;
  @override
  Future<Duration?> getCurrentPosition() async =>
      Duration(milliseconds: ++reads * 200);
  @override
  Future<void> resume() async {
    resumes++;
    state = PlayerState.playing;
    updater!.start();
  }

  @override
  Future<void> pause() async {
    state = PlayerState.paused;
    updater!.stop();
  }

  void completeLoop() {
    state = PlayerState.completed;
    updater!.stop();
    completions.add(null);
  }

  @override
  Future<void> dispose() async {
    await updater!.dispose();
    await completions.close();
    await durations.close();
  }
}

void main() {
  test(
    'loop completion keeps observing native position without restarting audio',
    () async {
      final backend = LoopBackend();
      var completed = 0;
      final port = AssetVoicePort(
        () => completed++,
        loop: true,
        backend: backend,
      );
      await port.resume();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final before = backend.reads;
      backend.completeLoop();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(backend.reads, greaterThan(before));
      expect(port.loopCompletions, 1);
      expect(completed, 0);
      expect(backend.resumes, 1);
      await port.pause();
      final stopped = backend.reads;
      // A late completion after pause must not revive the timer or native sound.
      backend.completeLoop();
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(backend.reads, stopped);
      expect(backend.resumes, 1);
      await port.resume();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(backend.reads, greaterThan(stopped));
      await port.dispose().timeout(const Duration(seconds: 2));
      final disposed = backend.reads;
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(backend.reads, disposed);
    },
  );
  test('spoken line completion remains terminal', () async {
    final backend = LoopBackend();
    var completed = 0;
    final port = AssetVoicePort(() => completed++, backend: backend);
    await port.resume();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    backend.completeLoop();
    final before = backend.reads;
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(completed, 1);
    expect(backend.reads, before);
    expect(port.loopCompletions, 0);
    await port.dispose().timeout(const Duration(seconds: 2));
  });
}
