import 'package:flutter_test/flutter_test.dart';
import 'package:madogiwa_engine/madogiwa_engine.dart';

MotionController fixture() => MotionController({
  'Idle': const MotionSpec(duration: 2),
  'Walk': const MotionSpec(duration: 1, syncGroup: 'gait', groundSpeed: 2),
  'Run': const MotionSpec(duration: .6, syncGroup: 'gait', groundSpeed: 4),
  'Hit': const MotionSpec(duration: .5, loop: false),
}, initial: 'Idle');

void main() {
  test('fresh loop entry preserves blend and never overrides continuity', () {
    final p = fixture();
    final before = p.weights;
    p.select('Walk', entryPhase: .16);
    expect(p.phase, closeTo(.16, 1e-12));
    expect(p.weights, before);
    p.advance(.1, groundSpeed: 2);
    final walkingPhase = p.phase;
    p.select('Run', entryPhase: .16);
    expect(p.phase, closeTo(walkingPhase, 1e-12));
    p.advance(.05, groundSpeed: 4);
    final runningTime = p.seconds['Run'];
    p.select('Idle');
    p.advance(.02, groundSpeed: 0);
    p.select('Run', entryPhase: .16);
    expect(p.seconds['Run'], runningTime);
    p.select('Run', restart: true, entryPhase: .16);
    expect(p.phase, 0);
    p.select('Walk', immediate: true, entryPhase: .16);
    // Immediate isolation keeps existing gait synchronization semantics.
    expect(p.phase, 0);
    p.select('Hit', entryPhase: .16);
    expect(p.phase, 0);
  });
  test('entry proposal yields to sibling donor through idle', () {
    final p = fixture()..select('Walk', immediate: true);
    p.seekPhase(.72);
    p.select('Idle');
    p.advance(.05, groundSpeed: 0);
    p.select('Run', entryPhase: .16);
    expect(p.phase, closeTo(.72, 1e-12));
    for (final invalid in [-.1, 1.0, double.nan, double.infinity]) {
      expect(() => p.select('Walk', entryPhase: invalid), throwsArgumentError);
    }
  });

  test(
    'eased blend starts gently and completes at its configured duration',
    () {
      final player = MotionController(
        fixture().motions,
        initial: 'Idle',
        transitionSeconds: .18,
      )..select('Walk');
      player.advance(1 / 30, groundSpeed: 2);
      expect(player.weights['Walk']!, lessThan(.06));
      expect(player.weights['Walk']!, greaterThan(0));
      player.advance(.18 - 1 / 30, groundSpeed: 2);
      expect(player.weights['Walk'], closeTo(1, 1e-12));
      expect(player.weights['Idle'], closeTo(0, 1e-12));
    },
  );
  test(
    'eased interruptions preserve weights, partitioning, pause and isolation',
    () {
      MotionController make() => MotionController(
        fixture().motions,
        initial: 'Idle',
        transitionSeconds: .18,
      )..select('Walk');
      final a = make(), b = make();
      a.advance(.09);
      for (var i = 0; i < 9; i++) {
        b.advance(.01);
      }
      for (final key in a.weights.keys) {
        expect(a.weights[key], closeTo(b.weights[key]!, 1e-12));
      }
      final before = a.weights;
      a.select('Run');
      expect(a.weights, before);
      a.paused = true;
      a.advance(.5);
      expect(a.weights, before);
      a.paused = false;
      for (final motion in ['Hit', 'Walk', 'Run', 'Idle']) {
        a.select(motion);
        a.advance(.025);
        expect(a.weights.values.every((v) => v >= 0 && v <= 1), isTrue);
        expect(a.weights.values.reduce((x, y) => x + y), closeTo(1, 1e-12));
      }
      a.select('Run', immediate: true);
      a.advance(.01);
      expect(a.weights['Run'], 1);
      expect(a.weights['Walk'], 0);
    },
  );
  test('eased transition rejects invalid duration', () {
    for (final duration in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => MotionController(
          fixture().motions,
          initial: 'Idle',
          transitionSeconds: duration,
        ),
        throwsArgumentError,
      );
    }
  });

  test(
    'brief idle preserves visible gait phase when resuming a different gait',
    () {
      final player = fixture()..select('Walk');
      player.advance(.4, groundSpeed: 2);
      player.select('Idle');
      player.advance(.04, groundSpeed: 0);
      final previousWalk = player.seconds['Walk']!;
      final weights = player.weights;
      player.select('Run');
      expect(player.phase, closeTo(previousWalk, 1e-10));
      expect(player.seconds['Walk'], previousWalk);
      expect(player.weights, weights);
      player.advance(.03, groundSpeed: 4);
      expect(
        player.seconds['Run']! / .6,
        closeTo(player.seconds['Walk']!, 1e-10),
      );
    },
  );
  test('one-shot interruption does not transfer a different gait phase', () {
    final player = fixture()..select('Walk');
    player.advance(.4, groundSpeed: 2);
    player.select('Hit');
    player.advance(.04, groundSpeed: 0);
    player.select('Run');
    expect(player.phase, 0);
  });
  test('expired gait and explicit restart do not inherit a stale phase', () {
    final player = fixture()..select('Walk');
    player.advance(.4, groundSpeed: 2);
    player.select('Idle');
    player.advance(1, groundSpeed: 0);
    player.select('Run');
    expect(player.phase, 0);
    player.select('Walk');
    player.advance(.2, groundSpeed: 2);
    player.select('Idle');
    player.select('Run', restart: true);
    expect(player.phase, 0);
  });

  test('return to a still-visible loop preserves its outgoing phase', () {
    final player = fixture()..select('Walk');
    player.advance(.4, groundSpeed: 2);
    player.select('Idle');
    player.advance(.04, groundSpeed: 0);
    final phaseBefore = player.seconds['Walk'];
    final weightsBefore = player.weights;
    player.select('Walk');
    expect(player.seconds['Walk'], phaseBefore);
    expect(player.weights, weightsBefore);
    player.select('Walk', restart: true);
    expect(player.phase, 0);
  });
  test('faded loops restart, immediate poses isolate, one-shots retrigger', () {
    final player = fixture()..select('Walk');
    player.advance(.4);
    player.select('Idle');
    player.advance(1);
    expect(player.weights['Walk']!, lessThan(.0001));
    player.select('Walk');
    expect(player.phase, 0);
    player.advance(.2);
    player.select('Idle');
    player.select('Walk', immediate: true);
    expect(player.phase, 0);
    player.select('Hit');
    player.advance(.2);
    player.select('Idle');
    player.advance(.01);
    player.select('Hit');
    expect(player.phase, 0);
  });
  test(
    'immediate inspection discards outgoing blend without advancing time',
    () {
      final player = fixture()..select('Walk');
      player.advance(.02);
      player.select('Hit', immediate: true);
      player.seekPhase(.4);
      expect(player.weights, {'Idle': 0, 'Walk': 0, 'Run': 0, 'Hit': 1});
      expect(player.phase, .4);
      final before = player.inspect();
      expect(
        () => player.select('missing', immediate: true),
        throwsArgumentError,
      );
      expect(player.inspect(), before);
    },
  );
  test('gait phase survives transitions and both blend sides stay aligned', () {
    final player = fixture()..select('Walk');
    player.advance(.75, groundSpeed: 2);
    player.select('Run');
    expect(player.phase, closeTo(.75, 1e-10));
    player.advance(.15, groundSpeed: 4);
    expect(
      player.seconds['Run']! / .6,
      closeTo(player.seconds['Walk']!, 1e-10),
    );
    player.select('Hit');
    expect(player.phase, 0);
  });
  test('collision speed zero freezes gait, pause freezes weights and time', () {
    final player = fixture()..select('Walk');
    player.advance(.2, groundSpeed: 2);
    final seconds = player.seconds['Walk'];
    player.advance(1, groundSpeed: 0);
    expect(player.seconds['Walk'], seconds);
    player.paused = true;
    final before = player.inspect();
    player.advance(20, groundSpeed: 2);
    expect(player.inspect(), before);
  });
  test(
    'partitioned updates agree and interrupted weights remain normalized',
    () {
      final a = fixture()..select('Walk'), b = fixture()..select('Walk');
      a.advance(.4, groundSpeed: 1);
      for (var i = 0; i < 40; i++) {
        b.advance(.01, groundSpeed: 1);
      }
      for (final key in a.motions.keys) {
        expect(a.seconds[key], closeTo(b.seconds[key]!, 1e-10));
        expect(a.weights[key], closeTo(b.weights[key]!, 1e-10));
      }
      for (final name in ['Run', 'Hit', 'Walk', 'Idle']) {
        a.select(name);
        a.advance(.02);
        expect(a.weights.values.reduce((a, b) => a + b), closeTo(1, 1e-10));
      }
    },
  );
  test(
    'one shot clamps, explicit restart replays, external phase stays fixed',
    () {
      final player = fixture()..select('Hit');
      player.advance(2);
      expect(player.finished, true);
      player.select('Hit', restart: true);
      expect(player.phase, 0);
      player.seekPhase(.4);
      player.advance(10, sampleOnly: true);
      expect(player.phase, .4);
      final before = player.inspect();
      expect(() => player.advance(double.nan), throwsArgumentError);
      expect(() => player.select('missing'), throwsArgumentError);
      expect(player.inspect(), before);
    },
  );
}
