import 'package:flutter_test/flutter_test.dart';
import 'package:madogiwa_engine/madogiwa_engine.dart';

void main() {
  test(
    '30 and 120 Hz preserve travel and gait phase through start and stop',
    () {
      (double, double, double) simulate(int fps) {
        final speed = LocomotionSpeed(acceleration: 20, braking: 15);
        final motion = MotionController({
          'Walk': const MotionSpec(duration: .8, groundSpeed: 2),
        }, initial: 'Walk');
        var distance = 0.0;
        for (var i = 0; i < fps * 2; i++) {
          final step = speed.advance(1 / fps, target: i < fps ? 3 : 0);
          distance += step;
          motion.advance(1 / fps, groundSpeed: step * fps);
        }
        return (distance, speed.speed, motion.phase);
      }

      final a = simulate(30), b = simulate(120);
      // .15 s acceleration triangle, .85 s cruise, .2 s brake triangle.
      expect(a.$1, closeTo(.225 + 2.55 + .3, 1e-10));
      expect(a.$1, closeTo(b.$1, 1e-10));
      expect(a.$2, 0);
      expect(b.$2, 0);
      expect(a.$3, closeTo(b.$3, 1e-10));
    },
  );
  test('interruption, zero delta and reset do not add phantom travel', () {
    final speed = LocomotionSpeed(acceleration: 10, braking: 20);
    expect(speed.advance(.1, target: 4), closeTo(.05, 1e-12));
    expect(speed.advance(0, target: 0), 0);
    expect(speed.speed, 1);
    expect(speed.advance(.2, target: 0), closeTo(.025, 1e-12));
    expect(speed.speed, 0);
    speed.reset(2);
    expect(speed.advance(.1, target: 2), closeTo(.2, 1e-12));
    speed.reset();
    expect(speed.speed, 0);
  });
  test('invalid parameters are rejected without corrupting state', () {
    for (final invalid in [-1.0, double.nan, double.infinity]) {
      expect(
        () => LocomotionSpeed(acceleration: invalid, braking: 1),
        throwsArgumentError,
      );
      final speed = LocomotionSpeed(acceleration: 1, braking: 1)..reset(2);
      expect(() => speed.advance(.1, target: invalid), throwsArgumentError);
      expect(() => speed.advance(invalid, target: 0), throwsArgumentError);
      expect(speed.speed, 2);
    }
  });
}
