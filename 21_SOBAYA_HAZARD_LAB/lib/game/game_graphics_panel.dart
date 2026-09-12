import 'package:flutter/material.dart';

import 'game_settings.dart';

/// Resolution and lighting have separate costs and can be chosen independently.
class HazardGraphicsPanel extends StatelessWidget {
  const HazardGraphicsPanel({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final HazardSettings settings;
  final void Function(void Function(HazardSettings)) onChanged;

  static const _ivory = Color(0xffe6dec6);
  static const _gold = Color(0xffc8b077);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xff202925),
      border: Border.all(color: const Color(0xff4e5a50)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('映像', style: TextStyle(color: _ivory, fontSize: 18)),
        const SizedBox(height: 4),
        const Text(
          '動きのなめらかさと、風景の細やかさを調整',
          style: TextStyle(color: _gold, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('フレーム上限', style: TextStyle(color: _gold)),
            for (final fps in [30, 60])
              ChoiceChip(
                key: ValueKey('game-frame-rate-$fps'),
                label: Text('$fps fps'),
                selected: settings.frameRateLimit == fps,
                selectedColor: _gold,
                backgroundColor: const Color(0xff18201c),
                checkmarkColor: const Color(0xff18201c),
                labelStyle: TextStyle(
                  color: settings.frameRateLimit == fps
                      ? const Color(0xff18201c)
                      : _ivory,
                ),
                onSelected: (_) => onChanged((s) => s.frameRateLimit = fps),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          '60 fpsは操作のなめらかさを優先。30 fpsは描画回数を抑えます。',
          style: TextStyle(color: _gold, fontSize: 12, height: 1.6),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in HazardGraphicsPreset.values)
              ChoiceChip(
                key: ValueKey('game-graphics-${preset.name}'),
                label: Text(preset.label),
                selected: settings.graphicsPreset == preset,
                selectedColor: _gold,
                backgroundColor: const Color(0xff18201c),
                checkmarkColor: const Color(0xff18201c),
                labelStyle: TextStyle(
                  color: settings.graphicsPreset == preset
                      ? const Color(0xff18201c)
                      : _ivory,
                ),
                onSelected: (_) => onChanged((s) => s.graphicsPreset = preset),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          settings.graphicsPreset.description,
          style: const TextStyle(color: _ivory, fontSize: 12, height: 1.6),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('解像度', style: TextStyle(color: _gold)),
            for (final scale in [.65, .85, 1.0])
              ChoiceChip(
                key: ValueKey('game-resolution-${(scale * 100).round()}'),
                label: Text('${(scale * 100).round()}%'),
                selected: settings.renderScale == scale,
                selectedColor: _gold,
                backgroundColor: const Color(0xff18201c),
                checkmarkColor: const Color(0xff18201c),
                labelStyle: TextStyle(
                  color: settings.renderScale == scale
                      ? const Color(0xff18201c)
                      : _ivory,
                ),
                onSelected: (_) => onChanged((s) => s.renderScale = scale),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          '動きが重いときは「バランス」や低い解像度をお試しください。',
          style: TextStyle(color: _gold, fontSize: 12, height: 1.6),
        ),
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile.adaptive(
            key: const ValueKey('game-lighting'),
            contentPadding: EdgeInsets.zero,
            title: const Text('光と影の演出', style: TextStyle(color: _ivory)),
            value: settings.cinematicLighting,
            onChanged: (v) => onChanged((s) => s.cinematicLighting = v),
          ),
        ),
      ],
    ),
  );
}
