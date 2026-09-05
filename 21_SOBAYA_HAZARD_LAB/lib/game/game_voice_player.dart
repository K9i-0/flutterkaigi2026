import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'game_voice.dart';

class AssetVoicePort implements VoicePort, VoiceTelemetry {
  AssetVoicePort(void Function() complete, {this.loop = false}) {
    _completion = player.onPlayerComplete.listen((_) {
      if (!loop) complete();
    });
    _positionEvents = player.onPositionChanged.listen((p) => position = p);
    _durationEvents = player.onDurationChanged.listen((d) => duration = d);
  }
  final bool loop;
  final player = AudioPlayer();
  late final StreamSubscription<void> _completion;
  late final StreamSubscription<Duration> _positionEvents, _durationEvents;
  Duration position = Duration.zero, duration = Duration.zero;
  @override
  Map<String, dynamic> get playback => {
    'state': player.state.name,
    'positionMs': position.inMilliseconds,
    'durationMs': duration.inMilliseconds,
    'loop': loop,
  };
  @override
  Future<void> load(String asset) async {
    await player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    await player.setSource(AssetSource(asset));
  }

  @override
  Future<void> volume(double gain) => player.setVolume(gain);
  @override
  Future<void> resume() => player.resume();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> dispose() async {
    await _completion.cancel();
    await _positionEvents.cancel();
    await _durationEvents.cancel();
    await player.dispose();
  }
}
