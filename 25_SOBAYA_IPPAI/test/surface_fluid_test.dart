import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_ippai/surface_fluid.dart';

void main() {
  test('jet makes a depression and propagates waves without adding volume', () {
    final s = SurfaceFluid();
    for (var i = 0; i < 120; i++) {
      s.step(1 / 120, flow: 1, agitation: 0, depth: .1);
    }
    expect(s.at(.007, 0), lessThan(0));
    expect(s.peak, greaterThan(.00001));
    expect(s.height.fold(0.0, (a, b) => a + b).abs(), lessThan(1e-8));
    expect(s.height.every((v) => v.isFinite && v.abs() < .01), true);
  });
  test('surface disturbance dissipates after shutting the tap', () {
    final s = SurfaceFluid();
    for (var i = 0; i < 120; i++) {
      s.step(1 / 120, flow: 1, agitation: .4, depth: .1);
    }
    final initial = s.height.fold(0.0, (a, b) => a + b * b);
    for (var i = 0; i < 600; i++) {
      s.step(1 / 120, flow: 0, agitation: 0, depth: .1);
    }
    final finalEnergy = s.height.fold(0.0, (a, b) => a + b * b);
    expect(finalEnergy, lessThan(initial * .05));
  });
}
