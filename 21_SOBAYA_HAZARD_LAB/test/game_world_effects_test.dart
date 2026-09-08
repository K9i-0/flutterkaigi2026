import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_world_effects.dart';

void main() {
  test('fire point light fades smoothly before its distance cutoff', () {
    expect(hazardFireLightDistanceGain(0), 1);
    expect(hazardFireLightDistanceGain(10), 1);
    expect(hazardFireLightDistanceGain(11.5), .5);
    expect(hazardFireLightDistanceGain(13), 0);
    expect(hazardFireLightDistanceGain(40), 0);
    var previous = 1.0;
    for (var i = 0; i <= 300; i++) {
      final gain = hazardFireLightDistanceGain(10 + i / 100);
      expect(gain, inInclusiveRange(0, previous));
      expect(previous - gain, lessThan(.006));
      previous = gain;
    }
  });

  test(
    'particle opacity has transparent borders and a tapered flame silhouette',
    () {
      const size = 64;
      for (final flame in [false, true]) {
        final pixels = hazardParticlePixels(flame: flame);
        int alpha(int x, int y) => pixels[(y * size + x) * 4 + 3];
        for (var i = 0; i < size; i++) {
          expect(alpha(i, 0), 0);
          expect(alpha(i, size - 1), 0);
          expect(alpha(0, i), 0);
          expect(alpha(size - 1, i), 0);
        }
        expect(alpha(32, 32), greaterThan(240));
        if (flame) {
          int width(int y) =>
              [for (var x = 0; x < size; x++) alpha(x, y)]
                  .where((value) => value > 30)
                  .length;
          expect(width(16), lessThan(width(48)));
        }
      }
    },
  );

  test(
    'fire flicker stays bounded and deterministic over long play sessions',
    () {
      for (final time in [0.0, .01, .2, 1.0, 10.0, 1000.0, 86400.0]) {
        final intensity = hazardFireIntensity(time);
        expect(intensity, inInclusiveRange(.8, 1.2));
        expect(hazardFireIntensity(time), intensity);
        expect(
          (hazardFireIntensity(time + .016) - intensity).abs(),
          lessThan(.04),
        );
      }
    },
  );
}
