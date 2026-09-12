/// Fixed feature budgets; these never infer hardware speed from window size.
/// Resolution stays a separate preference so changing effects preserves it.
enum HazardGraphicsPreset {
  balanced,
  quality,
  showcase;

  String get label => switch (this) {
    balanced => 'バランス',
    quality => '高画質',
    showcase => '最高画質',
  };

  String get description => switch (this) {
    balanced => '建物と陰影をくっきり保ち、描画負荷を抑える',
    quality => '遠景のちらつきを抑え、会話の光とぼけを豊かに',
    showcase => '高精細な影と動的な間接光を加える',
  };

  HazardGraphicsPreset get next => values[(index + 1) % values.length];

  bool get temporalAntiAliasing => this != balanced;
  bool get dynamicGlobalIllumination => this == showcase;
  bool get cinematicFocus => this != balanced;
  int get shadowMapResolution => this == showcase ? 2048 : 1024;
  double get shadowMaxDistance => this == showcase ? 40 : 32;
  int get ambientOcclusionSamples => this == showcase ? 12 : 8;

  static HazardGraphicsPreset decode(
    Object? value, {
    HazardGraphicsPreset fallback = quality,
  }) => values.where((preset) => preset.name == value).firstOrNull ?? fallback;
}
