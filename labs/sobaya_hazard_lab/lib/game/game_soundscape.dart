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
  double intensity = 0, duck = 1, impactDuck = 1, _hold = 0;
  double _impactHold = 0, _alertCooldown = 0;
  String _zone = 'village';

  /// Clear encounter pressure on a fresh run without reloading the loops.
  void resetEncounter() {
    intensity = 0;
    duck = impactDuck = 1;
    _hold = _impactHold = _alertCooldown = 0;
  }

  /// Briefly make room for a loud weapon's attack, then recover smoothly.
  void accentImpact(double audibility) {
    if (audibility < .08) return;
    impactDuck = math.min(impactDuck, 1 - .42 * audibility.clamp(0.0, 1.0));
    _impactHold = .10;
  }

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

  /// Returns true only for a fresh audible encounter, never once per enemy.
  bool tick(
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
    _alertCooldown = math.max(0, _alertCooldown - step);
    final newAlert =
        active &&
        threat &&
        _hold <= 0 &&
        intensity < .15 &&
        _alertCooldown <= 0;
    if (newAlert) _alertCooldown = 10;
    _hold = active && threat ? 3.5 : math.max(0, _hold - step);
    final alerted = threat || _hold > 0;
    intensity +=
        ((alerted ? 1.0 : 0.0) - intensity) *
        (1 - math.exp(-step / (alerted ? .28 : 2.4)));
    duck +=
        ((speaking ? .26 : 1) - duck) *
        (1 - math.exp(-step / (speaking ? .12 : .8)));
    _impactHold = math.max(0, _impactHold - step);
    if (_impactHold == 0) {
      impactDuck += (1 - impactDuck) * (1 - math.exp(-step / .32));
    }
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
        .40 *
            musicVolume *
            math.cos(intensity * math.pi / 2) *
            duck *
            impactDuck,
      ),
    );
    tension.sync(
      const VoiceCue('tension', 'audio/soundscape/tension.wav'),
      paused: !active,
      volume: gain(
        .50 *
            musicVolume *
            math.sin(intensity * math.pi / 2) *
            duck *
            impactDuck,
      ),
    );
    return newAlert;
  }

  Future<void> dispose() => Future.wait([
    ambience.dispose(),
    exploration.dispose(),
    tension.dispose(),
  ]);
  Map<String, dynamic> inspect() => {
    'intensity': intensity,
    'duck': duck,
    'impactDuck': impactDuck,
    'alertCooldown': _alertCooldown,
    'releaseHold': _hold,
    'ambience': ambience.inspect(),
    'exploration': exploration.inspect(),
    'tension': tension.inspect(),
  };
}
