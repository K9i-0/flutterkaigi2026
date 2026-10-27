/// Visual-only options. Turning effects off never changes the simulation.
class GraphicsSettings {
  const GraphicsSettings({
    this.shadows = true,
    this.reflections = true,
    this.surfaceDetail = true,
    this.bloom = true,
    this.fullResolution = false,
  });
  static const standard = GraphicsSettings();
  static const highQuality = GraphicsSettings(fullResolution: true);
  static const light = GraphicsSettings(
    shadows: false,
    reflections: false,
    surfaceDetail: false,
    bloom: false,
    fullResolution: false,
  );
  final bool shadows, reflections, surfaceDetail, bloom, fullResolution;
  // Cap the 3D image, not the Flutter UI. Smaller displays stay native.
  double renderScaleFor(double longestSide) =>
      fullResolution || longestSide <= 1440 ? 1 : 1440 / longestSide;
  int get shadowCascades => fullResolution ? 3 : 1;
  double get shadowDistance => fullResolution ? 85 : 24;
  Map<String, bool> toMap() => {
    'shadows': shadows,
    'reflections': reflections,
    'surfaceDetail': surfaceDetail,
    'bloom': bloom,
    'fullResolution': fullResolution,
  };
  factory GraphicsSettings.fromMap(Map<String, dynamic> map) {
    bool read(String name) => map[name] is bool ? map[name] as bool : true;
    return GraphicsSettings(
      shadows: read('shadows'),
      reflections: read('reflections'),
      surfaceDetail: read('surfaceDetail'),
      bloom: read('bloom'),
      fullResolution: map['fullResolution'] == true,
    );
  }
  GraphicsSettings withOption(String key, bool value) =>
      GraphicsSettings.fromMap({...toMap(), key: value});
  @override
  bool operator ==(Object other) =>
      other is GraphicsSettings &&
      shadows == other.shadows &&
      reflections == other.reflections &&
      surfaceDetail == other.surfaceDetail &&
      bloom == other.bloom &&
      fullResolution == other.fullResolution;
  @override
  int get hashCode =>
      Object.hash(shadows, reflections, surfaceDetail, bloom, fullResolution);
}
