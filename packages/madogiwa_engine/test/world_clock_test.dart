import 'package:flutter_test/flutter_test.dart';
import 'package:madogiwa_engine/madogiwa_engine.dart';

void main() {
  test('Snapshot restores fractional advancement and paused state', () {
    final clock = WorldClock(hour: 0)..speed = .25;
    clock.advance(const Duration(microseconds: 3));
    final restored = WorldClock.fromSnapshot(clock.snapshot());
    clock.advance(const Duration(microseconds: 1));
    restored.advance(const Duration(microseconds: 1));
    expect(restored.snapshot(), clock.snapshot());
    expect(restored.snapshot()['elapsedMicros'], 1);
    clock.paused = true;
    expect(WorldClock.fromSnapshot(clock.snapshot()).paused, isTrue);
    expect(
      () => WorldClock.fromSnapshot({...clock.snapshot(), 'fraction': 1}),
      throwsFormatException,
    );
  });

  test('Fifteen minutes completes a day independently of tick partition', () {
    final one = WorldClock(hour: 0)..advance(const Duration(minutes: 15));
    final many = WorldClock(hour: 0);
    for (var i = 0; i < 9000; i++) {
      many.advance(const Duration(milliseconds: 100));
    }
    expect(one.inspect(), many.inspect());
    expect(one.day, 1);
    expect(one.hour, 0);
  });
  test(
    'Pause, speed and debug hour preserve explicit simulation semantics',
    () {
      final clock = WorldClock(hour: 6)..paused = true;
      clock.advance(const Duration(minutes: 15));
      expect(clock.hour, 6);
      clock.paused = false;
      clock.speed = 2;
      clock.advance(const Duration(seconds: 450));
      expect(clock.day, 1);
      expect(clock.hour, 6);
      clock.setHour(18);
      expect(clock.day, 1);
      expect(clock.hour, 18);
      clock.speed = 0;
      clock.advance(const Duration(days: 1));
      expect(clock.hour, 18);
    },
  );
  test('Invalid settings fail before changing clock state', () {
    final clock = WorldClock();
    final before = clock.inspect();
    expect(() => clock.setHour(double.nan), throwsArgumentError);
    expect(() => clock.setHour(24), throwsArgumentError);
    expect(() => clock.speed = double.infinity, throwsArgumentError);
    expect(
      () => clock.advance(const Duration(seconds: -1)),
      throwsArgumentError,
    );
    expect(() => WorldClock(dayLength: Duration.zero), throwsArgumentError);
    expect(clock.inspect(), before);
  });
}
