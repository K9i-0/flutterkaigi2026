import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_benchmark.dart';

Map<String, Object?> thermal(String state) => {
  'status': 'available',
  'available': true,
  'platform': 'ios',
  'environment': 'physicalDevice',
  'source': 'ProcessInfo',
  'thermalState': state,
  'isLowPowerModeEnabled': false,
  'systemUptime': 123.0,
};

class DiagnosticClock {
  int micros = 0;
  int renders = 100;
  final epoch = DateTime.utc(2026, 9, 12);

  void advance(int seconds, {int callsPerSecond = 30}) {
    micros += Duration(seconds: seconds).inMicroseconds;
    renders += seconds * callsPerSecond;
  }

  GameBenchmarkDiagnostics diagnostics(
    Future<Map<String, Object?>> Function() read,
  ) => GameBenchmarkDiagnostics(
    renderCount: () => renders,
    elapsedMicroseconds: () => micros,
    readThermal: read,
    utcNow: () => epoch.add(Duration(microseconds: micros)),
  );
}

Future<void> flushReads() => Future<void>.delayed(Duration.zero);

void main() {
  group('benchmark configuration', () {
    test('defaults preserve the short 60 limit and eight-second profile', () {
      final config = GameBenchmarkConfig.parse();
      expect(config.frameRateLimit, 60);
      expect(config.seconds, 8);
      expect(config.deadlineSeconds, 30);
    });

    test('accepts only 30 or 60 and integer durations from 8 through 300', () {
      expect(GameBenchmarkConfig.parse(fps: '30').frameRateLimit, 30);
      expect(GameBenchmarkConfig.parse(seconds: '300').seconds, 300);
      expect(GameBenchmarkConfig.parse(seconds: '180').deadlineSeconds, 202);
      for (final value in ['', '0', '120', '60.0', ' 60', 'unlimited']) {
        expect(
          () => GameBenchmarkConfig.parse(fps: value),
          throwsArgumentError,
        );
      }
      for (final value in ['', '7', '301', '8.0', '+8', ' 8', '1e2', '-8']) {
        expect(
          () => GameBenchmarkConfig.parse(seconds: value),
          throwsArgumentError,
        );
      }
    });

    test('waits for requested duration and keeps semantic and frame gates', () {
      final config = GameBenchmarkConfig.parse();
      bool finish(int milliseconds, int samples, bool ready) =>
          config.shouldFinish(
            Duration(milliseconds: milliseconds),
            samples: samples,
            semanticReady: ready,
          );
      expect(finish(7999, 240, true), isFalse);
      expect(finish(8000, 240, true), isTrue);
      expect(finish(8000, 239, true), isFalse);
      expect(finish(29999, 240, false), isFalse);
      expect(finish(30000, 10, false), isTrue);
    });

    test('three-minute case cannot finish early; deadline is 202 seconds', () {
      final config = GameBenchmarkConfig.parse(fps: '30', seconds: '180');
      bool finish(int seconds, bool ready) => config.shouldFinish(
        Duration(seconds: seconds),
        samples: 240,
        semanticReady: ready,
      );
      expect(finish(179, true), isFalse);
      expect(finish(180, true), isTrue);
      expect(finish(201, false), isFalse);
      expect(finish(202, false), isTrue);
    });
  });

  group('per-case diagnostics', () {
    test(
      'three-minute fake run records real-time call rate and thermal peak',
      () async {
        final clock = DiagnosticClock();
        var reads = 0;
        final diagnostics = clock.diagnostics(() async {
          reads++;
          return thermal(clock.micros == 20000000 ? 'serious' : 'nominal');
        });
        await diagnostics.beginCase();
        for (var seconds = 10; seconds <= 180; seconds += 10) {
          clock.advance(10);
          diagnostics.poll();
          await flushReads();
        }
        final result = (await diagnostics.finishCase())!;
        expect(
          reads,
          19,
        ); // Initial, every ten seconds, and no duplicate end read.
        expect(result['sceneRenderCountStart'], 100);
        expect(result['sceneRenderCountEnd'], 5500);
        expect(result['sceneRenderCalls'], 5400);
        expect(result['sceneRenderMeasurementSeconds'], 180.0);
        expect(result['sceneRenderCallsPerSecond'], 30.0);
        expect(result['sceneRenderMeasurement'], contains('not presented FPS'));
        expect(result['sceneRenderMeasurement'], contains('GPU completion'));
        final snapshots = result['thermal']! as Map<String, Object?>;
        expect(snapshots['status'], 'available');
        expect(snapshots['peakState'], 'serious');
        expect(snapshots['peakRecordedAtUtc'], '2026-09-12T00:00:20.000Z');
        expect((snapshots['start']! as Map)['caseElapsedMs'], 0.0);
        expect((snapshots['end']! as Map)['caseElapsedMs'], 180000.0);
        expect((snapshots['samples']! as List).length, 19);
      },
    );

    test(
      'short case takes an end snapshot and includes read latency in rate',
      () async {
        final clock = DiagnosticClock();
        var reads = 0;
        final diagnostics = clock.diagnostics(() async {
          if (++reads == 2) clock.advance(1);
          return thermal('fair');
        });
        await diagnostics.beginCase();
        clock.advance(8);
        final result = (await diagnostics.finishCase())!;
        expect(reads, 2);
        expect(result['sceneRenderCalls'], 270);
        expect(result['sceneRenderMeasurementSeconds'], 9.0);
        expect(result['sceneRenderCallsPerSecond'], 30.0);
        final end = (result['thermal']! as Map)['end'] as Map;
        expect(end['caseElapsedMs'], 8000.0);
        expect(end['completedCaseElapsedMs'], 9000.0);
        expect(end['requestedAtUtc'], '2026-09-12T00:00:08.000Z');
        expect(end['completedAtUtc'], '2026-09-12T00:00:09.000Z');
      },
    );

    test('repeated polls never overlap an outstanding OS read', () async {
      final clock = DiagnosticClock();
      final pending = Completer<Map<String, Object?>>();
      var reads = 0;
      final diagnostics = clock.diagnostics(() {
        reads++;
        return reads == 1 ? pending.future : Future.value(thermal('fair'));
      });
      final initial = diagnostics.beginCase();
      clock.advance(10);
      diagnostics.poll();
      clock.advance(10);
      diagnostics.poll();
      expect(reads, 1);
      pending.complete(thermal('nominal'));
      await initial;
      diagnostics.poll();
      await flushReads();
      expect(reads, 2);
      diagnostics.poll();
      expect(reads, 2);
      diagnostics.stop();
    });

    test(
      'case switch discards late prior result and samples new case promptly',
      () async {
        final clock = DiagnosticClock();
        final oldRead = Completer<Map<String, Object?>>();
        var reads = 0;
        final diagnostics = clock.diagnostics(() {
          reads++;
          return reads == 1 ? oldRead.future : Future.value(thermal('nominal'));
        });
        final oldCase = diagnostics.beginCase();
        clock.advance(2);
        final newCase = diagnostics.beginCase();
        expect(reads, 1);
        oldRead.complete(thermal('critical'));
        await oldCase;
        await newCase;
        expect(reads, 2);
        clock.advance(8);
        final result = (await diagnostics.finishCase())!;
        expect(result['sceneRenderCountStart'], 160);
        expect(result['sceneRenderCalls'], 240);
        final snapshots = result['thermal']! as Map;
        expect(snapshots['peakState'], 'nominal');
        expect((snapshots['samples'] as List).length, 2);
        expect((snapshots['start'] as Map)['caseElapsedMs'], 0.0);
      },
    );

    test(
      'switching while a case finishes cannot return an old record',
      () async {
        final clock = DiagnosticClock();
        final oldRead = Completer<Map<String, Object?>>();
        var reads = 0;
        final diagnostics = clock.diagnostics(() {
          reads++;
          return reads == 1 ? oldRead.future : Future.value(thermal('nominal'));
        });
        final initial = diagnostics.beginCase();
        clock.advance(8);
        final closing = diagnostics.finishCase();
        final newCase = diagnostics.beginCase();
        oldRead.complete(thermal('critical'));
        await initial;
        expect(await closing, isNull);
        await newCase;
        diagnostics.stop();
      },
    );

    test(
      'stop invalidates pending samples and prevents subsequent polling',
      () async {
        final clock = DiagnosticClock();
        final pending = Completer<Map<String, Object?>>();
        var reads = 0;
        final diagnostics = clock.diagnostics(() {
          reads++;
          return pending.future;
        });
        final initial = diagnostics.beginCase();
        clock.advance(8);
        final finishing = diagnostics.finishCase();
        diagnostics.stop();
        pending.complete(thermal('critical'));
        await initial;
        expect(await finishing, isNull);
        clock.advance(20);
        diagnostics.poll();
        expect(reads, 1);
        expect(await diagnostics.finishCase(), isNull);
      },
    );

    test(
      'unsupported and failed reads remain unavailable with timestamps',
      () async {
        final clock = DiagnosticClock();
        var reads = 0;
        final diagnostics = clock.diagnostics(() async {
          if (++reads == 2) throw StateError('test read failure');
          return {
            'status': 'unavailable',
            'available': false,
            'platform': 'macOS',
            'reason': 'unsupportedPlatform',
          };
        });
        await diagnostics.beginCase();
        clock.advance(8);
        final result = (await diagnostics.finishCase())!;
        final snapshots = result['thermal']! as Map;
        expect(snapshots['status'], 'unavailable');
        expect(snapshots['peakState'], isNull);
        expect((snapshots['start'] as Map)['reason'], 'unsupportedPlatform');
        expect((snapshots['end'] as Map)['reason'], 'readFailed');
        expect((snapshots['end'] as Map)['requestedAtUtc'], isNotEmpty);
      },
    );

    test(
      'partial thermal evidence does not hide a later unavailable reading',
      () async {
        final clock = DiagnosticClock();
        var reads = 0;
        final diagnostics = clock.diagnostics(
          () async => ++reads == 1
              ? thermal('fair')
              : {
                  'status': 'unavailable',
                  'available': false,
                  'reason': 'timeout',
                },
        );
        await diagnostics.beginCase();
        clock.advance(8);
        final snapshots = (await diagnostics.finishCase())!['thermal']! as Map;
        expect(snapshots['status'], 'partial');
        expect(snapshots['peakState'], 'fair');
        expect((snapshots['end'] as Map)['reason'], 'timeout');
      },
    );

    test(
      'zero elapsed time and a reset render counter never invent a rate',
      () async {
        final clock = DiagnosticClock();
        final diagnostics = clock.diagnostics(() async => thermal('nominal'));
        await diagnostics.beginCase();
        expect(
          (await diagnostics.finishCase())!['sceneRenderCallsPerSecond'],
          isNull,
        );
        await diagnostics.beginCase();
        clock.advance(8);
        clock.renders = 0;
        final reset = (await diagnostics.finishCase())!;
        expect(reset['sceneRenderCalls'], isNull);
        expect(reset['sceneRenderCallsPerSecond'], isNull);
      },
    );
  });
}
