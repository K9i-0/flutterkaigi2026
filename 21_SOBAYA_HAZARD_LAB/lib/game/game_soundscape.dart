import 'dart:math' as math;

import 'game_voice.dart';
import 'game_voice_player.dart';

/// Regional ambience and two original scores, with smoothed equal-power fades.
/// Keep both scores running silently so repeated alerts never restart the intro.
class HazardSoundscape {
  HazardSoundscape({VoicePort Function(void Function())? createPort})
    : ambience = VoiceSession(createPort ?? _loop),
      exploration = VoiceSession(createPort ?? _loop),
      tension = VoiceSession(createPort ?? _loop);
  static VoicePort _loop(void Function() done) =>
      AssetVoicePort(done, loop: true);
  final VoiceSession ambience, exploration, tension;
  double intensity = 0, duck = 1, _hold = 0;
  String _zone = 'village';
  void pause() {
    ambience.sync(
      VoiceCue(_zone, 'audio/soundscape/$_zone.wav'),
      paused: true,
      volume: 0,
    );
    exploration.sync(
      const VoiceCue('exploration', 'audio/soundscape/exploration.wav'),
      paused: true,
      volume: 0,
    );
    tension.sync(
      const VoiceCue('tension', 'audio/soundscape/tension.wav'),
      paused: true,
      volume: 0,
    );
  }

  void tick(
    double dt, {
    required String zone,
    required bool active,
    required bool threat,
    required bool speaking,
    required double volume,
    double musicVolume = 1,
  }) {
    _zone = zone;
    final step = active ? dt.clamp(0.0, .05) : 0.0;
    _hold = threat ? 2.5 : math.max(0, _hold - step);
    final alerted = threat || _hold > 0;
    intensity +=
        ((alerted ? 1.0 : 0.0) - intensity) *
        (1 - math.exp(-step / (alerted ? .8 : 2.4)));
    duck +=
        ((speaking ? .32 : 1) - duck) *
        (1 - math.exp(-step / (speaking ? .12 : .8)));
    double gain(double v) => (v.clamp(0.0, 1.0) * 100).round() / 100;
    ambience.sync(
      VoiceCue(zone, 'audio/soundscape/$zone.wav'),
      paused: !active,
      volume: gain(.20 * volume * duck),
    );
    exploration.sync(
      const VoiceCue('exploration', 'audio/soundscape/exploration.wav'),
      paused: !active,
      volume: gain(
        .40 * musicVolume * math.cos(intensity * math.pi / 2) * duck,
      ),
    );
    tension.sync(
      const VoiceCue('tension', 'audio/soundscape/tension.wav'),
      paused: !active,
      volume: gain(
        .46 * musicVolume * math.sin(intensity * math.pi / 2) * duck,
      ),
    );
  }

  Future<void> dispose() => Future.wait([
    ambience.dispose(),
    exploration.dispose(),
    tension.dispose(),
  ]);
  Map<String, dynamic> inspect() => {
    'intensity': intensity,
    'duck': duck,
    'releaseHold': _hold,
    'ambience': ambience.inspect(),
    'exploration': exploration.inspect(),
    'tension': tension.inspect(),
  };
}
