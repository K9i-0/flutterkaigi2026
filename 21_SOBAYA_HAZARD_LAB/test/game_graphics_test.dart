import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_settings.dart';

void main() {
  test('old and corrupt preferences migrate to the native device budget', () {
    expect(HazardSettings().frameRateLimit, 60);
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
      for (final mobile in [false, true]) {
        expect(
          HazardSettings.decode(encoded, mobileDevice: mobile).frameRateLimit,
          60,
          reason: '$encoded keeps the 60fps default on mobile=$mobile',
        );
      }
    }
  });

  test('saved effects survive moving between native device classes', () {
    for (final preset in HazardGraphicsPreset.values) {
      for (final scale in [.65, .85, 1.0]) {
        for (final fps in [30, 60]) {
          final original = HazardSettings(
            graphicsPreset: preset,
            renderScale: scale,
            cinematicLighting: false,
            volume: .4,
            frameRateLimit: fps,
          );
          expect(jsonDecode(original.encode())['frameRateLimit'], fps);
          for (final mobile in [false, true]) {
            final restored = HazardSettings.decode(
              original.encode(),
              mobileDevice: mobile,
            );
            expect(restored.frameRateLimit, fps);
            expect(
              jsonDecode(restored.encode()),
              jsonDecode(original.encode()),
            );
          }
        }
      }
    }
  });

  test('unsupported or damaged frame limits use 60 without resetting other graphics choices', () {
    for (final value in <Object?>[
      null,
      0,
      -30,
      1,
      29,
      31,
      45,
      59,
      61,
      90,
      120,
      30.5,
      '30',
      '60',
      'broken',
      true,
      false,
      [],
      {},
    ]) {
      final encoded = jsonEncode({
        'frameRateLimit': value,
        'graphicsPreset': 'showcase',
        'renderScale': 1.0,
        'cinematicLighting': false,
      });
      for (final mobile in [false, true]) {
        final restored = HazardSettings.decode(encoded, mobileDevice: mobile);
        expect(restored.frameRateLimit, 60, reason: '$value on mobile=$mobile');
        expect(restored.graphicsPreset, HazardGraphicsPreset.showcase);
        expect(restored.renderScale, 1);
        expect(restored.cinematicLighting, isFalse);
      }
    }
    expect(HazardSettings.decode('{"frameRateLimit":NaN}').frameRateLimit, 60);
    expect(HazardSettings.decode('{"frameRateLimit":').frameRateLimit, 60);
  });

  test(
    'changing the effects budget preserves resolution and sound choices',
    () {
      final settings = HazardSettings(
        renderScale: 1,
        graphicsPreset: HazardGraphicsPreset.balanced,
        voiceVolume: .25,
        touchControls: true,
        frameRateLimit: 30,
      );
      for (var i = 0; i < HazardGraphicsPreset.values.length; i++) {
        settings.graphicsPreset = settings.graphicsPreset.next;
        final restored = HazardSettings.decode(settings.encode());
        expect(restored.renderScale, 1);
        expect(restored.voiceVolume, .25);
        expect(restored.touchControls, isTrue);
        expect(restored.frameRateLimit, 30);
        expect(restored.graphicsPreset, settings.graphicsPreset);
      }
      expect(settings.graphicsPreset, HazardGraphicsPreset.balanced);
      for (final fps in [60, 30]) {
        settings.frameRateLimit = fps;
        final restored = HazardSettings.decode(settings.encode());
        expect(restored.frameRateLimit, fps);
        expect(restored.graphicsPreset, HazardGraphicsPreset.balanced);
        expect(restored.renderScale, 1);
        expect(restored.voiceVolume, .25);
        expect(restored.touchControls, isTrue);
      }
    },
  );
}
