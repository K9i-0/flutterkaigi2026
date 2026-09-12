import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene/src/widgets/frame_pacer.dart';

List<Duration> pacedFrames(
  double displayHz,
  double? limit, {
  int seconds = 10,
}) {
  final pacer = SceneFramePacer();
  return [
    for (var i = 0; i < (displayHz * seconds).round(); i++)
      if (pacer.shouldAdvance(
        Duration(microseconds: (i * 1000000 / displayHz).round()),
        limit,
      ))
        Duration(microseconds: (i * 1000000 / displayHz).round()),
  ];
}

void main() {
  for (final hz in [119.88, 120.0, 90.0, 60.0, 59.94]) {
    for (final cap in [30.0, 60.0]) {
      test('$cap fps at $hz Hz keeps cadence and full elapsed time', () {
        final frames = pacedFrames(hz, cap);
        expect(frames.length, closeTo(cap * 10, 2));
        final steps = [
          for (var i = 1; i < frames.length; i++)
            (frames[i] - frames[i - 1]).inMicroseconds,
        ];
        final maxVsyncSteps = (hz / cap).ceil();
        expect(
          steps.every((dt) => dt <= maxVsyncSteps * 1000000 / hz + 2),
          true,
          reason: 'No extra skipped frame from clock rounding or drift',
        );
        expect(
          steps.fold<int>(0, (sum, dt) => sum + dt),
          frames.last.inMicroseconds,
          reason: 'Accepted deltas preserve animation/simulation elapsed time',
        );
        if (hz != 90) {
          expect(
            steps.every((dt) => dt >= (hz / cap).round() * 1000000 / hz - 2),
            true,
            reason:
                'Near-harmonic rates must not repay drift with short frames',
          );
        }
      });
    }
    test('unspecified limit preserves every $hz Hz callback', () {
      expect(pacedFrames(hz, null).length, (hz * 10).round());
    });
  }

  test('90 Hz to 60 fps alternates one and two vsync intervals', () {
    final frames = pacedFrames(90, 60, seconds: 1);
    final gaps = [
      for (var i = 1; i < frames.length; i++)
        ((frames[i] - frames[i - 1]).inMicroseconds * 90 / 1000000).round(),
    ];
    expect(gaps.toSet(), {1, 2});
    for (var i = 1; i < gaps.length; i++) {
      expect(gaps[i], isNot(gaps[i - 1]));
    }
  });

  test('small vsync jitter does not turn 60 fps into 30 fps', () {
    final pacer = SceneFramePacer();
    var accepted = 0;
    for (var i = 0; i < 600; i++) {
      final jitter = i == 0 ? 0 : (i.isOdd ? 100 : -100);
      if (pacer.shouldAdvance(
        Duration(microseconds: (i * 1000000 / 60).round() + jitter),
        60,
      )) {
        accepted++;
      }
    }
    expect(accepted, 600);
  });

  test('late frames are accepted once without catch-up bursts', () {
    final pacer = SceneFramePacer();
    final accepted = <int>[];
    for (final us in [0, 8333, 16667, 25000, 100000, 108333, 116667]) {
      if (pacer.shouldAdvance(Duration(microseconds: us), 60)) accepted.add(us);
    }
    expect(accepted, [0, 16667, 100000, 116667]);
    expect(accepted[2] - accepted[1], 83333);
  });

  test(
    'rate changes use time since the last accepted frame without a burst',
    () {
      final pacer = SceneFramePacer();
      final accepted = <int>[];
      for (final (us, cap) in <(int, double?)>[
        (0, 60),
        (8333, 60),
        (16667, 30),
        (25000, 30),
        (33333, 30),
        (41667, 60),
        (50000, 60),
        (58333, 30),
        (66667, 30),
        (75000, 30),
        (83333, 30),
        (91667, null),
      ]) {
        if (pacer.shouldAdvance(Duration(microseconds: us), cap)) {
          accepted.add(us);
        }
      }
      expect(accepted, [0, 33333, 50000, 83333, 91667]);
    },
  );

  test('a new clock and an explicit reset do not inherit old cadence debt', () {
    final pacer = SceneFramePacer();
    expect(pacer.shouldAdvance(const Duration(seconds: 5), 30), true);
    expect(
      pacer.shouldAdvance(const Duration(microseconds: 5008333), 30),
      false,
    );
    expect(pacer.shouldAdvance(Duration.zero, 30), true);
    expect(pacer.shouldAdvance(const Duration(microseconds: 8333), 30), false);
    pacer.reset();
    expect(pacer.shouldAdvance(const Duration(microseconds: 8333), 30), true);
  });
}
