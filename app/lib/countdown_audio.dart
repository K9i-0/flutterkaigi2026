import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Beeps for the round countdown. Calls are queued so platform messages never
/// overlap, and a missing audio device never blocks the game.
class CountdownAudio {
  final _tick = AudioPlayer(), _go = AudioPlayer();
  Future<void> _pending = Future.value();
  bool enabled = true, _disposed = false;

  void _queue(Future<void> Function() action) {
    if (!enabled || _disposed) return;
    _pending = _pending
        .then((_) async {
          if (!_disposed) await action();
        })
        .catchError((Object _) {});
  }

  /// One of the "3, 2, 1" counts.
  void tick() => _queue(() async {
    await _tick.stop();
    await _tick.play(
      AssetSource('audio/countdown_tick.wav'),
      mode: PlayerMode.lowLatency,
    );
  });

  /// The round starts.
  void go() => _queue(
    () => _go.play(
      AssetSource('audio/countdown_go.wav'),
      mode: PlayerMode.lowLatency,
    ),
  );

  void dispose() {
    _disposed = true;
    unawaited(
      _pending.whenComplete(() async {
        await _tick.dispose();
        await _go.dispose();
      }),
    );
  }
}
