import 'dart:async';

import 'game_controller.dart';

/// Bounded native-rendering checks driven through the same controller methods
/// as the UI. Does not synthesize keyboard/pointer input or fast-forward time.
Future<Map<String, Object?>> probeConversation(
  HazardGameController game,
) async {
  final snapshots = <Map<String, Object?>>[];
  final clock = Stopwatch()..start();
  int? epoch;
  Map<String, Object?> snapshot(String stage) => {
    'stage': stage,
    'wallMs': clock.elapsedMilliseconds,
    'ticks': game.renderedTicks,
    'foreground': game.foreground,
    'shot': game.director?.index,
    'paused': game.director?.paused,
    'voice': game.voice.inspect(),
    'faces': game.inspectSpeechFaces(),
  };
  void checkSession() {
    if (game.disposed || game.runEpoch != epoch) {
      throw StateError('Probe cancelled: run or app changed');
    }
    if (!game.foreground) {
      throw StateError(
        'Game is in the background; activate its window and retry',
      );
    }
    if (clock.elapsedMilliseconds > 12000) {
      throw TimeoutException('Probe exceeded 12 seconds');
    }
  }

  Future<void> until(bool Function() condition) async {
    do {
      checkSession();
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    } while (true);
  }

  Future<void> observeSpeaker(String speaker, int shot) async {
    final openings = <double>[];
    final initialTicks = game.renderedTicks;
    await until(
      () =>
          game.director?.index == shot &&
          game.voice.speaking &&
          game.voice.activeCue?.speaker == speaker &&
          (game.voice.playbackSeconds ?? 0) > .2 &&
          (game.speechWeights[speaker] ?? 0) > .08 &&
          game.renderedTicks > initialTicks + 2,
    );
    for (var i = 0; i < 7; i++) {
      snapshots.add(snapshot('$speaker:$i'));
      openings.add(game.speechWeights[speaker] ?? 0);
      final face = game.inspectSpeechFaces()[speaker] as Map;
      final applied = (face['weights'] as List).first as double;
      if ((applied - openings.last).abs() > .00001) {
        throw StateError('Morph weight did not reach the scene node');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      checkSession();
    }
    final other = speaker == '福ちゃん' ? 'やめ太郎' : '福ちゃん';
    if (game.speechWeights[other] != 0) {
      throw StateError('Silent actor moved: $other');
    }
    openings.sort();
    if (openings.last - openings.first < .02) {
      throw StateError('No observed articulation change for $speaker');
    }
  }

  Future<void> pauseAndCheck(String stage) async {
    game.setEventPaused(true);
    await game.voice.idle.timeout(const Duration(seconds: 2));
    checkSession();
    if (game.voice.speaking || game.speechWeights.values.any((v) => v != 0)) {
      throw StateError('Speech or mouth movement remained after pause');
    }
    snapshots.add(snapshot(stage));
  }

  try {
    if (!game.ready || !game.foreground || game.disposed) {
      throw StateError('Ready foreground game required; no run was reset');
    }
    game.restart();
    epoch = game.runEpoch;
    game.startEvent('opening');
    game.advanceEvent();
    await observeSpeaker('やめ太郎', 1);
    final pausedPosition = game.voice.playbackSeconds!;
    await pauseAndCheck('paused-yametaro');
    game.setEventPaused(false);
    await until(
      () => game.voice.speaking && game.voice.playbackSeconds != null,
    );
    if (game.voice.playbackSeconds! + .05 < pausedPosition) {
      throw StateError('Audio rewound after resume');
    }
    snapshots.add(snapshot('resumed-yametaro'));
    game.advanceEvent();
    await observeSpeaker('福ちゃん', 2);
    await pauseAndCheck('paused-fukuchan');
    return {
      'success': true,
      'probe': 'conversation',
      'scope': 'Actual native frames/audio and controller transitions; not a keyboard/gesture test',
      'durationMs': clock.elapsedMilliseconds,
      'pausedClock': pausedPosition,
      'snapshots': snapshots,
    };
  } catch (error) {
    return {
      'success': false,
      'probe': 'conversation',
      'error': '$error',
      'durationMs': clock.elapsedMilliseconds,
      'snapshots': snapshots,
    };
  } finally {
    if (epoch != null && game.runEpoch == epoch && !game.disposed) {
      game.setEventPaused(true);
    }
  }
}
