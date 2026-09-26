import 'dart:ui';

import 'package:flutter/material.dart';

import 'atmosphere_settings.dart';
import 'island_atmosphere.dart';

class AtmospherePanel extends StatelessWidget {
  const AtmospherePanel({
    super.key,
    required this.atmosphere,
    required this.onClose,
  });
  final IslandAtmosphere atmosphere;
  final VoidCallback onClose;
  static const icons = [
    Icons.wb_sunny_outlined,
    Icons.cloud_outlined,
    Icons.blur_on,
    Icons.water_drop_outlined,
    Icons.thunderstorm_outlined,
  ];
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: atmosphere,
    builder: (context, _) {
      final s = atmosphere.settings;
      Widget heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: Color(0xffa3b8c5),
          ),
        ),
      );
      Widget slider(
        String label,
        double value,
        ValueChanged<double> changed, {
        double min = 0,
        double max = 1,
        String? display,
      }) => Column(
        children: [
          Row(
            children: [
              Text(label),
              const Spacer(),
              Text(
                display ?? '${(value * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xff8cddd0),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: changed,
          ),
        ],
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xff101c29).withValues(alpha: .94),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: Theme(
              data: ThemeData.dark(useMaterial3: true).copyWith(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xff8cddd0),
                  brightness: Brightness.dark,
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ISLAND ATMOSPHERE',
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 2.2,
                                  color: Color(0xff8cddd0),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '時間と天気',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('close-atmosphere'),
                          tooltip: '設定を閉じる',
                          onPressed: onClose,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: atmosphere.day > .5
                                    ? [
                                        const Color(0xff2b5262),
                                        const Color(0xff253c50),
                                      ]
                                    : [
                                        const Color(0xff242847),
                                        const Color(0xff132337),
                                      ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      AtmosphereSettings.clock(atmosphere.hour),
                                      style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.w300,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      icons[s.weather.index],
                                      size: 36,
                                      color: const Color(0xffb9dedf),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${s.weather.label}  ·  ${s.autoTime ? "時間経過中" : "時刻を固定"}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  s.weather.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          heading('時刻'),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final p in [
                                ('朝', 6.6),
                                ('昼', 13.0),
                                ('夕暮れ', 17.8),
                                ('夜', 22.0),
                              ])
                                ChoiceChip(
                                  label: Text(p.$1),
                                  selected: (s.hour - p.$2).abs() < .15,
                                  onSelected: (_) =>
                                      atmosphere.set(s.copyWith(hour: p.$2)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          slider(
                            '時間',
                            s.hour,
                            (v) => atmosphere.set(s.copyWith(hour: v)),
                            max: 23.99,
                            display: AtmosphereSettings.clock(s.hour),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                '時間を進める',
                                style: TextStyle(fontSize: 14),
                              ),
                              subtitle: const Text(
                                '太陽と影がゆっくり移動します',
                                style: TextStyle(fontSize: 11),
                              ),
                              value: s.autoTime,
                              onChanged: (v) =>
                                  atmosphere.set(s.copyWith(autoTime: v)),
                            ),
                          ),
                          if (s.autoTime)
                            slider(
                              '1日の長さ',
                              s.dayMinutes,
                              (v) => atmosphere.set(s.copyWith(dayMinutes: v)),
                              min: 5,
                              max: 120,
                              display: '${s.dayMinutes.round()}分',
                            ),
                          heading('天気'),
                          Wrap(
                            spacing: 7,
                            runSpacing: 8,
                            children: [
                              for (final w in IslandWeather.values)
                                ChoiceChip(
                                  key: ValueKey('weather-${w.name}'),
                                  avatar: Icon(icons[w.index], size: 17),
                                  label: Text(w.label),
                                  selected: s.weather == w,
                                  onSelected: (_) =>
                                      atmosphere.set(s.copyWith(weather: w)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (s.weather != IslandWeather.clear)
                            slider(
                              '天気の強さ',
                              s.strength,
                              (v) => atmosphere.set(s.copyWith(strength: v)),
                            ),
                          slider(
                            '風の強さ',
                            s.wind,
                            (v) => atmosphere.set(s.copyWith(wind: v)),
                          ),
                          heading('映像とサウンド'),
                          SegmentedButton<WeatherQuality>(
                            segments: const [
                              ButtonSegment(
                                value: WeatherQuality.balanced,
                                label: Text('軽量'),
                              ),
                              ButtonSegment(
                                value: WeatherQuality.high,
                                label: Text('高画質'),
                              ),
                            ],
                            selected: {s.quality},
                            onSelectionChanged: (v) =>
                                atmosphere.set(s.copyWith(quality: v.first)),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '描画解像度・海の反射・影・雨粒の密度を調整',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 20),
                          slider(
                            '環境音の音量',
                            s.volume,
                            (v) => atmosphere.set(s.copyWith(volume: v)),
                          ),
                          const Divider(color: Colors.white12),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () =>
                                    atmosphere.set(const AtmosphereSettings()),
                                child: const Text('初期設定に戻す'),
                              ),
                              const Spacer(),
                              const Text(
                                '変更は自動保存',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                          if (atmosphere.store.error != null)
                            const Text(
                              '設定を保存できませんでした',
                              style: TextStyle(color: Colors.orangeAccent),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
