import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_ippai/tilt_input.dart';

void main() {
  test('held pose calibrates, either roll direction pours, return stops', () {
    var now = DateTime(2026);
    final input = TiltInput(now: () => now);
    void hold(double degrees) {
      for (var i = 0; i < 100; i++) {
        now = now.add(const Duration(milliseconds: 16));
        final a = degrees * math.pi / 180;
        input.sample(math.sin(a) * 9.81, math.cos(a) * 9.81, 0);
      }
    }

    hold(10);
    input.calibrate();
    expect(input.value, closeTo(0, .001));
    hold(40);
    expect(input.value, closeTo(.5, .01));
    hold(-20);
    expect(input.value, closeTo(.5, .01));
    hold(10);
    expect(input.value, closeTo(0, .001));
  });
  test('sensor drop-out and invalid samples cannot leave the tap running', () {
    var now = DateTime(2026);
    final input = TiltInput(now: () => now);
    input.sample(0, 9.81, 0);
    now = now.add(const Duration(seconds: 1));
    input.sample(8, 4, 0);
    expect(input.value, greaterThan(.8));
    now = now.add(const Duration(milliseconds: 650));
    expect(input.available, false);
    expect(input.value, 0);
    input.sample(double.nan, 0, 0);
    expect(input.value, 0);
    input.sample(0, 0, 0);
    expect(input.available, false);
  });
}
