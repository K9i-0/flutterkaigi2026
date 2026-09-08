import 'dart:math' as math;

import 'game_voice.dart';
import 'game_voice_player.dart';

/// Continuous exploration, pursuit and unmetered suspense layers. The AI's
/// public feedback owns threat state: proximity alone must never reveal an enemy.
class HazardSoundscape {
  HazardSoundscape({VoicePort Function(void Function())? createPort})
    : ambience = VoiceSession(createPort ?? _loop),
      exploration = VoiceSession(createPort ?? _loop),
      tension = VoiceSession(createPort ?? _loop),
      searching = VoiceSession(createPort ?? _loop);
  static VoicePort _loop(void Function() done) =>
      AssetVoicePort(done, loop: true);
  final VoiceSession ambience, exploration, tension, searching;
  double intensity = 0, duck = 1, impactDuck = 1;
  double pursuitMix = 0, suspenseMix = 0, shelterMix = 0;
  double _impactHold = 0, _pursuitHold = 0, _safeTime = 0;
  bool _encounter = false;
  String _zone = 'village', _phase = 'calm';

  /// Clear encounter pressure on a fresh run without reloading the loops.
  void resetEncounter() {
    intensity = pursuitMix = suspenseMix = shelterMix = 0;
    duck = impactDuck = 1;
    _impactHold = _pursuitHold = _safeTime = 0;
    _encounter = false;
    _phase = 'calm';
  }

  /// Briefly make room for a loud weapon's attack, then recover smoothly.
  void accentImpact(double audibility) {
    if (!audibility.isFinite || audibility < .08) return;
    impactDuck = math.min(impactDuck, 1 - .42 * audibility.clamp(0.0, 1.0));
    _impactHold = .10;
  }

  void pause() {
    for (final (session, cue) in [
      (ambience, VoiceCue(_zone, 'audio/soundscape/$_zone.wav')),
      (
        exploration,
        const VoiceCue('exploration', 'audio/soundscape/exploration.wav'),
      ),
      (tension, const VoiceCue('tension', 'audio/soundscape/tension.wav')),
      (
        searching,
        const VoiceCue('searching', 'audio/soundscape/searching.wav'),
      ),
    ]) {
      session.sync(cue, paused: true, volume: 0);
    }
  }

  /// Accent once per encounter, including any chase/search/reacquisition cycles.
  /// A sustained return to safety rearms it; pause and brief state gaps do not.
  bool tick(
    double dt, {
    required String zone,
    required bool active,
    required String phase,
    required bool speaking,
    required double volume,
    double musicVolume = 1,
    double suspicion = 0,
    double shelter = 0,
  }) {
    _zone = zone;
    final step = active && dt.isFinite ? dt.clamp(0.0, .05) : 0.0;
    if (active) {
      _phase = switch (phase) {
        'suspicious' || 'chasing' || 'searching' || 'returning' => phase,
        _ => 'calm',
      };
    }
    final chasing = _phase == 'chasing';
    final newAlert = active && chasing && !_encounter;
    if (newAlert) _encounter = true;
    if (_phase == 'calm' || _phase == 'returning') {
      _safeTime += step;
      if (_safeTime >= 3) _encounter = false;
    } else {
      _safeTime = 0;
    }
    _pursuitHold = active && chasing ? .65 : math.max(0, _pursuitHold - step);
    final pursuit = chasing || _pursuitHold > 0;
    final pressure = suspicion.isFinite ? suspicion.clamp(0.0, 1.0) : 0.0;
    final enclosed = shelter.isFinite ? shelter.clamp(0.0, 1.0) : 0.0;
    double approach(double current, double target, double seconds) =>
        current + (target - current) * (1 - math.exp(-step / seconds));
    shelterMix = approach(shelterMix, enclosed, .55);
    final desiredIntensity = pursuit
        ? 1.0
        : switch (_phase) {
            'searching' => .56,
            'suspicious' => pressure * .28,
            'returning' => .12,
            _ => 0.0,
          };
    intensity = approach(
      intensity,
      desiredIntensity,
      desiredIntensity > intensity ? .28 : 2.4,
    );
    // The rhythmic score leaves promptly after the short occlusion hold. The
    // separate, beat-free bed preserves tension while exposing spatial Foley.
    pursuitMix = approach(pursuitMix, pursuit ? 1 : 0, pursuit ? .23 : .38);
    final suspense = switch (_phase) {
      'chasing' => .45,
      'searching' => .74,
      'suspicious' => .16 + pressure * .30,
      'returning' => .18,
      _ => 0.0,
    };
    suspenseMix = approach(
      suspenseMix,
      suspense,
      suspense > suspenseMix ? .55 : 2.4,
    );
    duck = approach(duck, speaking ? .26 : 1, speaking ? .12 : .8);
    _impactHold = math.max(0, _impactHold - step);
    if (_impactHold == 0) impactDuck = approach(impactDuck, 1, .32);
    double gain(double v) =>
        v.isFinite ? (v.clamp(0.0, 1.0) * 100).round() / 100 : 0;
    ambience.sync(
      VoiceCue(zone, 'audio/soundscape/$zone.wav'),
      paused: !active,
      volume: gain(
        .20 * volume * duck * (1 - .62 * shelterMix) * (1 - .30 * intensity),
      ),
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
      volume: gain(.50 * musicVolume * pursuitMix * duck * impactDuck),
    );
    searching.sync(
      const VoiceCue('searching', 'audio/soundscape/searching.wav'),
      paused: !active,
      volume: gain(
        .22 *
            musicVolume *
            suspenseMix *
            (1 - .50 * pursuitMix) *
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
    searching.dispose(),
  ]);
  Map<String, dynamic> inspect() => {
    'phase': _phase,
    'intensity': intensity,
    'pursuitMix': pursuitMix,
    'suspenseMix': suspenseMix,
    'encounter': _encounter,
    'safeTime': _safeTime,
    'duck': duck,
    'impactDuck': impactDuck,
    'releaseHold': _pursuitHold,
    'shelterMix': shelterMix,
    'ambience': ambience.inspect(),
    'exploration': exploration.inspect(),
    'tension': tension.inspect(),
    'searching': searching.inspect(),
  };
}
