import 'dart:async';
import 'dart:math' as math;

import 'game_controller.dart';
import 'game_state.dart';

/// Native frames and controller inputs on the authored village collision map.
/// The initial single-enemy fixture isolates escape behaviour from crowd luck.
Future<Map<String, Object?>> probeStealthHorror(HazardGameController g) async {
  if (!g.ready || !g.foreground) throw StateError('Foreground game required');
  g.restart();
  g.posePreview = false;
  g.director = null;
  final epoch = g.runEpoch, s = g.state!;
  s.seenEvents.addAll(['opening', 'farm', 'last_order', 'ending']);
  s.phase = PlayPhase.playing;
  s.x = -10.5;
  s.z = 12.5;
  s.yaw = 0;
  s.heading = math.pi;
  for (final e in s.enemies) {
    e.active = false;
  }
  final e = Enemy(0, -10.5, 6.5);
  s.enemies[0] = e;
  e.active = true;
  e.x = -10.5;
  e.z = 6.5;
  e.heading = 0;
  e.ambientDance = null;
  final watch = Stopwatch()..start(), snapshots = <Map<String, Object?>>[];
  final phases = <String>{}, musicPhases = <String>{};
  double? lostAt, releasedAt;
  double maxSearchVolume = 0, maxPursuitMix = 0;
  int stage = 0;
  final route = [
    (-10.5, 15.7, false),
    (-8.6, 15.7, false),
    (-4.0, 15.7, false),
    (-4.0, 12.2, false),
    (-6.4, 12.2, true),
  ];
  String previousPhase = '';
  try {
    while (watch.elapsedMilliseconds < 55000) {
      if (!g.foreground || g.runEpoch != epoch || g.disposed) {
        throw StateError('Probe interrupted');
      }
      final f = s.stealthFeedback, audio = g.soundscape.inspect();
      phases.add(f.phase);
      musicPhases.add(audio['phase'] as String);
      maxSearchVolume = math.max(
        maxSearchVolume,
        ((audio['searching'] as Map)['volume'] as num).toDouble(),
      );
      maxPursuitMix = math.max(
        maxPursuitMix,
        (audio['pursuitMix'] as num).toDouble(),
      );
      if (f.phase == 'searching') lostAt ??= s.time;
      if (lostAt != null && !e.alerted) releasedAt ??= s.time;
      if (f.phase != previousPhase) {
        snapshots.add({
          'time': s.time,
          'phase': f.phase,
          'remaining': f.remaining,
          'audio': audio['phase'],
          'player': [s.x, s.z],
          'enemy': [e.x, e.z],
          'health': s.health,
          'ticks': g.renderedTicks,
        });
        previousPhase = f.phase;
      }
      if (s.time > .65 && stage < route.length) {
        final target = route[stage], dx = target.$1 - s.x, dz = target.$2 - s.z;
        final distance = math.sqrt(dx * dx + dz * dz);
        if (distance < .15) {
          stage++;
          s.stopInput();
        } else {
          s.sprint = !target.$3;
          s.sneaking = target.$3;
          s.inputX = -dx / distance;
          s.inputY = -dz / distance;
        }
      } else {
        s.stopInput();
      }
      if (s.health <= 0) throw StateError('Escape fixture died');
      final homeDistance = math.sqrt(
        math.pow(e.x - e.homeX, 2) + math.pow(e.z - e.homeZ, 2),
      );
      if (releasedAt != null &&
          homeDistance < .8 &&
          e.awareness == EnemyAwareness.idle) {
        return {
          'success':
              phases.containsAll(['chasing', 'searching', 'returning']) &&
              maxPursuitMix > .1 &&
              maxSearchVolume > 0,
          'probe': 'stealthHorror',
          'mode': 'native rendered controller input',
          'wallMs': watch.elapsedMilliseconds,
          'health': s.health,
          'phases': phases.toList(),
          'musicPhases': musicPhases.toList(),
          'lostAt': lostAt,
          'releasedAt': releasedAt,
          'homeDistance': homeDistance,
          'maxPursuitMix': maxPursuitMix,
          'maxSearchVolume': maxSearchVolume,
          'snapshots': snapshots,
          'frames': g.frames.toJson(),
        };
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    throw TimeoutException(
      'Native escape did not complete: ${e.awareness.name}, ${s.x},${s.z}, ${e.x},${e.z}',
    );
  } finally {
    s.stopInput();
    g.toggle(PlayPhase.paused);
  }
}
