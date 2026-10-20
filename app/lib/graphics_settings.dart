import 'package:flutter/material.dart';

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

class GraphicsDialog extends StatefulWidget {
  const GraphicsDialog({super.key, required this.initial});
  final GraphicsSettings initial;
  @override
  State<GraphicsDialog> createState() => _GraphicsDialogState();
}

class _GraphicsDialogState extends State<GraphicsDialog> {
  late GraphicsSettings settings = widget.initial;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('画質設定'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('graphics_standard'),
                    onPressed: () =>
                        setState(() => settings = GraphicsSettings.standard),
                    child: const Text('標準'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('graphics_high'),
                    onPressed: () =>
                        setState(() => settings = GraphicsSettings.highQuality),
                    child: const Text('高画質'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('graphics_light'),
                    onPressed: () =>
                        setState(() => settings = GraphicsSettings.light),
                    child: const Text('軽量'),
                  ),
                ),
              ],
            ),
            for (final option in const [
              ('shadows', '太陽の影', '昼の建物・キャラクターの影'),
              ('reflections', 'ガラス・金属の反射', '空と街明かりの映り込み'),
              ('surfaceDetail', '表面の凹凸', '鉄骨・路面の細かな質感'),
              ('bloom', '夜景の光のにじみ', '夜の照明を柔らかく'),
              ('fullResolution', '高精細描画', 'オンで細部と遠くの影を優先。オフでなめらかさを優先'),
            ])
              SwitchListTile(
                key: ValueKey('graphics_${option.$1}'),
                contentPadding: EdgeInsets.zero,
                title: Text(option.$2),
                subtitle: Text(option.$3),
                value: settings.toMap()[option.$1]!,
                onChanged: (v) => setState(
                  () => settings = settings.withOption(option.$1, v),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('キャンセル'),
      ),
      FilledButton(
        key: const ValueKey('graphics_apply'),
        onPressed: () => Navigator.pop(context, settings),
        child: const Text('適用'),
      ),
    ],
  );
}
