import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_settings.dart';

void main() {
  test('old and corrupt preferences migrate to the native device budget', () {
    for (final encoded in <String?>[
      null,
      '{}',
      'broken',
      '[]',
      '{"graphicsPreset":null}',
      '{"graphicsPreset":"future-format"}',
      '{"graphicsPreset":2}',
    ]) {
      expect(
        HazardSettings.decode(encoded).graphicsPreset,
        HazardGraphicsPreset.quality,
        reason: '$encoded on desktop',
      );
      expect(
        HazardSettings.decode(encoded, mobileDevice: true).graphicsPreset,
        HazardGraphicsPreset.balanced,
        reason: '$encoded on phone',
      );
    }
  });

  test('saved effects survive moving between native device classes', () {
    for (final preset in HazardGraphicsPreset.values) {
      for (final scale in [.65, .85, 1.0]) {
        final original = HazardSettings(
          graphicsPreset: preset,
          renderScale: scale,
          cinematicLighting: false,
          volume: .4,
        );
        for (final mobile in [false, true]) {
          final restored = HazardSettings.decode(
            original.encode(),
            mobileDevice: mobile,
          );
          expect(jsonDecode(restored.encode()), jsonDecode(original.encode()));
        }
      }
    }
  });

  test(
    'changing the effects budget preserves resolution and sound choices',
    () {
      final settings = HazardSettings(
        renderScale: 1,
        graphicsPreset: HazardGraphicsPreset.balanced,
        voiceVolume: .25,
        touchControls: true,
      );
      for (var i = 0; i < HazardGraphicsPreset.values.length; i++) {
        settings.graphicsPreset = settings.graphicsPreset.next;
        final restored = HazardSettings.decode(settings.encode());
        expect(restored.renderScale, 1);
        expect(restored.voiceVolume, .25);
        expect(restored.touchControls, isTrue);
        expect(restored.graphicsPreset, settings.graphicsPreset);
      }
      expect(settings.graphicsPreset, HazardGraphicsPreset.balanced);
    },
  );
}
