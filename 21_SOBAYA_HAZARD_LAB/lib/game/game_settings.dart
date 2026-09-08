import 'dart:convert';

enum HazardDifficulty { casual, standard, tense }

/// Preferences live outside checkpoints so loading progress never resets them.
class HazardSettings {
  HazardSettings({
    this.difficulty = HazardDifficulty.standard,
    this.volume = 1,
    this.voiceVolume = 1,
    this.environmentVolume = 1,
    this.musicVolume = 1,
    this.effectsVolume = 1,
    this.sensitivity = 1,
    this.touchSensitivity = 1,
    this.touchControls = false,
    this.renderScale = .85,
    this.muted = false,
    this.cinematicLighting = true,
  });
  HazardDifficulty difficulty;
  double volume,
      voiceVolume,
      environmentVolume,
      musicVolume,
      effectsVolume,
      sensitivity,
      touchSensitivity,
      renderScale;
  bool muted, cinematicLighting, touchControls;
  double get damageScale => switch (difficulty) {
    HazardDifficulty.casual => .65,
    HazardDifficulty.standard => 1,
    HazardDifficulty.tense => 1.25,
  };
  double get enemySpeedScale => switch (difficulty) {
    HazardDifficulty.casual => .85,
    HazardDifficulty.standard => 1,
    HazardDifficulty.tense => 1.15,
  };
  String get difficultyLabel => switch (difficulty) {
    HazardDifficulty.casual => '気軽に探索',
    HazardDifficulty.standard => '標準',
    HazardDifficulty.tense => '最高難度・補給必須',
  };
  String encode() => jsonEncode({
    'difficulty': difficulty.name,
    'volume': volume,
    'voiceVolume': voiceVolume,
    'environmentVolume': environmentVolume,
    'musicVolume': musicVolume,
    'effectsVolume': effectsVolume,
    'sensitivity': sensitivity,
    'touchSensitivity': touchSensitivity,
    'touchControls': touchControls,
    'renderScale': renderScale,
    'muted': muted,
    'cinematicLighting': cinematicLighting,
  });
  factory HazardSettings.decode(String? encoded, {bool mobileDevice = false}) {
    // Only the caller's native device class selects first-launch quality;
    // saved choices and desktop window resizing never change the preference.
    final defaultRenderScale = mobileDevice ? .65 : .85;
    final s = HazardSettings(renderScale: defaultRenderScale);
    if (encoded == null) return s;
    try {
      final j = jsonDecode(encoded) as Map;
      s.difficulty =
          HazardDifficulty.values
              .where((d) => d.name == j['difficulty'])
              .firstOrNull ??
          HazardDifficulty.standard;
      double bounded(String key, double lo, double hi, double fallback) {
        final value = j[key];
        return value is num && value.isFinite
            ? value.toDouble().clamp(lo, hi)
            : fallback;
      }

      s.volume = bounded('volume', 0, 1, 1);
      s.voiceVolume = bounded('voiceVolume', 0, 1, 1);
      s.environmentVolume = bounded('environmentVolume', 0, 1, 1);
      s.musicVolume = bounded('musicVolume', 0, 1, s.environmentVolume);
      s.effectsVolume = bounded('effectsVolume', 0, 1, 1);
      s.sensitivity = bounded('sensitivity', .5, 2, 1);
      s.touchSensitivity = bounded('touchSensitivity', .5, 2, 1);
      s.touchControls = j['touchControls'] == true;
      s.renderScale = [.65, .85, 1.0].contains(j['renderScale'])
          ? (j['renderScale'] as num).toDouble()
          : defaultRenderScale;
      s.muted = j['muted'] == true;
      s.cinematicLighting = j['cinematicLighting'] != false;
    } catch (_) {
      /* Damaged preferences use the playable defaults. */
    }
    return s;
  }
}
