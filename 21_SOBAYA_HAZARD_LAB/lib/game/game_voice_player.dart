import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'game_voice.dart';

class AssetVoicePort implements VoicePort, VoiceTelemetry {
  AssetVoicePort(
    void Function() complete, {
    this.loop = false,
    AudioPlayer? backend,
  }) : player = backend ?? AudioPlayer() {
    // Voice progress needs a few updates per second, not a platform call on
    // every rendered frame. Configure before subscribing to positionStream.
    _positions = TimerPositionUpdater(
      interval: const Duration(milliseconds: 200),
      getPosition: player.getCurrentPosition,
    );
    player.positionUpdater = _positions;
    _completion = player.onPlayerComplete.listen((_) {
      if (!loop) {
        complete();
      } else {
        loopCompletions++;
        // audioplayers 6.8.1 stops its position updater on every completion,
        // including ReleaseMode.loop. Darwin itself seeks and keeps playing.
        // Restore observation only; do not seek/restart the native sound.
        if (_playing) _positions.start();
      }
    });
    _positionEvents = player.onPositionChanged.listen((p) => position = p);
    _durationEvents = player.onDurationChanged.listen((d) => duration = d);
  }
  final bool loop;
  final AudioPlayer player;
  late final TimerPositionUpdater _positions;
  bool _playing = false;
  int loopCompletions = 0;
  late final StreamSubscription<void> _completion;
  late final StreamSubscription<Duration> _positionEvents, _durationEvents;
  Duration position = Duration.zero, duration = Duration.zero;
  @override
  Map<String, dynamic> get playback => {
    'state': player.state.name,
    'positionMs': position.inMilliseconds,
    'durationMs': duration.inMilliseconds,
    'loop': loop,
    'loopCompletions': loopCompletions,
    'playbackRequested': _playing,
    'positionUpdateMs': 200,
  };
  @override
  Future<void> load(String asset) async {
    await player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    await player.setSource(AssetSource(asset));
  }

  @override
  Future<void> volume(double gain) => player.setVolume(gain);
  @override
  Future<void> resume() {
    _playing = true;
    return player.resume();
  }

  @override
  Future<void> pause() {
    _playing = false;
    return player.pause();
  }

  @override
  Future<void> dispose() async {
    _playing = false;
    await _completion.cancel();
    await _positionEvents.cancel();
    await _durationEvents.cancel();
    await player.dispose();
  }
}
