import 'dart:math' as math;

import 'game_voice.dart';
import 'game_voice_player.dart';

/// Two loop players: regional ambience and a threat-responsive original score.
/// Backend gain updates are quantized to avoid platform calls every frame.
class HazardSoundscape {
  final ambience = VoiceSession((done) => AssetVoicePort(done, loop: true));
  final tension = VoiceSession((done) => AssetVoicePort(done, loop: true));
  double intensity = 0, duck = 1;
  String _zone = 'village';
  void pause() {
    ambience.sync(
      VoiceCue(_zone, 'audio/soundscape/$_zone.wav'),
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
  }) {
    _zone = zone;
    final target = threat ? 1.0 : 0.0;
    intensity += (target - intensity) * (1 - math.exp(-dt / (threat ? .7 : 3)));
    duck +=
        ((speaking ? .38 : 1) - duck) *
        (1 - math.exp(-dt / (speaking ? .12 : .8)));
    double gain(double v) => (v * 100).round() / 100;
    ambience.sync(
      VoiceCue(zone, 'audio/soundscape/$zone.wav'),
      paused: !active,
      volume: gain(.36 * volume * duck),
    );
    tension.sync(
      const VoiceCue('tension', 'audio/soundscape/tension.wav'),
      paused: !active || intensity < .015,
      volume: gain(.28 * volume * intensity * duck),
    );
  }

  Future<void> dispose() async {
    await Future.wait([ambience.dispose(), tension.dispose()]);
  }

  Map<String, dynamic> inspect() => {
    'intensity': intensity,
    'duck': duck,
    'ambience': ambience.inspect(),
    'tension': tension.inspect(),
  };
}
