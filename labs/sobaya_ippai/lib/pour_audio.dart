import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Serializes platform messages; a missing audio device never blocks play.
class PourAudio {
  final _pour = AudioPlayer(), _effect = AudioPlayer();
  Future<void> _pending = Future.value();
  bool enabled = true, _playing = false, _disposed = false;
  int _level = -1;
  void _queue(Future<void> Function() action) {
    _pending = _pending
        .then((_) async {
          if (!_disposed) await action();
        })
        .catchError((Object _) {});
  }

  void flow(double amount) {
    final level = enabled ? (amount.clamp(0, 1) * 5).round() : 0;
    if (level == _level) return;
    _level = level;
    _queue(() async {
      if (level == 0) {
        if (_playing) await _pour.pause();
        _playing = false;
        return;
      }
      await _pour.setVolume(level / 5 * .55);
      if (!_playing) {
        await _pour.setReleaseMode(ReleaseMode.loop);
        await _pour.play(AssetSource('audio/pour.wav'));
        _playing = true;
      }
    });
  }

  void finish(bool failed) {
    flow(0);
    if (enabled) {
      _queue(
        () => _effect.play(
          AssetSource(failed ? 'audio/spill.wav' : 'audio/clink.wav'),
        ),
      );
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(
      _pending.whenComplete(() async {
        await _pour.dispose();
        await _effect.dispose();
      }),
    );
  }
}
