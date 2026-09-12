import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_benchmark.dart';
import 'package:sobaya_hazard_lab/game/game_controller.dart';
import 'package:sobaya_hazard_lab/game/game_events.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';

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

Map<String, Object?> deviceSnapshot({
  required double cpu,
  required double uptime,
  int footprint = 500000000,
}) => {
  ...thermal('fair'),
  'metrics': {
    'processCpu': {
      'status': 'available',
      'available': true,
      'source': 'getrusage(RUSAGE_SELF)',
      'scope': 'processAllThreads',
      'usageConvention': 'oneCore100Percent',
      'totalSeconds': cpu,
      'sampleSystemUptimeSeconds': uptime,
    },
    'memory': {
      'status': 'available',
      'available': true,
      'physicalFootprintBytes': footprint,
    },
    'battery': {
      'status': 'available',
      'available': true,
      'state': 'unplugged',
      'level': .75,
    },
    'screenBrightness': {'status': 'available', 'available': true, 'value': .4},
    'activeProcessorCount': {
      'status': 'available',
      'available': true,
      'count': 6,
    },
  },
};

class CompletionController extends Fake implements HazardGameController {
  @override
  HazardGameState? state = HazardGameState(
    jsonDecode(File('assets/village.json').readAsStringSync()),
  );
  @override
  HazardDirector? director;
  @override
  bool disposed = false;
  final calls = <String>[];

  @override
  void toggle(PlayPhase phase) {
    calls.add('toggle:${phase.name}');
    state!.toggle(phase);
  }

  @override
  void setEventPaused(bool paused) {
    calls.add('eventPaused:$paused');
    director!.paused = paused;
  }

  @override
  void prepareStaticFrame() => calls.add('prepareStaticFrame');
}

void main() {
  group('benchmark log transport', () {
    test(
      'UTF-8 Japanese JSON survives shuffled ASCII chunks below 700 characters',
      () {
        final expected = {
          'runLabel': '村のそば屋8体・追跡🔥',
          'case': 'village-eight',
          'valid': true,
          'processCpu': {'oneCorePercent': 238.45, 'optional': null},
          'thermal': {
            'samples': List.generate(
              19,
              (i) => {
                ...deviceSnapshot(cpu: i * 25.5, uptime: 10000 + i * 10.0),
                'caseElapsedMs': i * 10000,
                    'note': '福ちゃん／そば屋、"改行"\nとタブ\tも保持',
              },
            ),
          },
        };
        final payload = jsonEncode(expected);
        final id = List.filled(64, 'a').join();
        final lines = GameBenchmarkLog.chunkLines(payload, id: id).toList();
        expect(lines.length, greaterThan(10));
        final parts = <int, String>{};
        for (final line in lines.reversed) {
          expect(line, startsWith(GameBenchmarkLog.chunkPrefix));
          expect(line.length, lessThan(700));
          expect(line.codeUnits.every((value) => value <= 127), isTrue);
          expect(line, isNot(contains('\n')));
          final envelope = jsonDecode(
            line.substring(GameBenchmarkLog.chunkPrefix.length),
          ) as Map;
          expect(
            envelope.keys,
            unorderedEquals(['id', 'part', 'total', 'data']),
          );
          expect(envelope['id'], id);
          expect(envelope['total'], lines.length);
          expect(envelope['part'], inInclusiveRange(1, lines.length));
          expect((envelope['data'] as String).length, lessThanOrEqualTo(512));
          parts[envelope['part'] as int] = envelope['data'] as String;
        }
        final encoded = [for (var i = 1; i <= lines.length; i++) parts[i]!]
            .join();
        final decoded = utf8.decode(base64Decode(encoded));
        expect(decoded, payload);
        expect(jsonDecode(decoded), expected);
      },
    );

    test('base64 boundaries and final padding preserve every payload byte', () {
      for (final length in [
        0,
        1,
        380,
        381,
        382,
        383,
        384,
        766,
        767,
        768,
        5000,
      ]) {
        final payload = jsonEncode(List.filled(length, 'x').join());
        final lines = GameBenchmarkLog.chunkLines(
          payload,
          id: 'case_0-60fps',
        ).toList();
        final encoded = base64Encode(utf8.encode(payload));
        expect(lines.length, (encoded.length + 511) ~/ 512);
        final data = <String>[];
        for (var i = 0; i < lines.length; i++) {
          final envelope = jsonDecode(
            lines[i].substring(GameBenchmarkLog.chunkPrefix.length),
          ) as Map;
          expect(envelope['part'], i + 1);
          expect(envelope['total'], lines.length);
          final chunk = envelope['data'] as String;
          if (i < lines.length - 1) {
            expect(chunk.length, 512);
            expect(chunk, isNot(contains('=')));
          }
          data.add(chunk);
        }
        expect(data.join(), encoded);
        expect(utf8.decode(base64Decode(data.join())), payload);
      }
    });

    test(
      'independent records retain identifiers without changing the JSON schema',
      () {
        final payload = jsonEncode({
          'schemaVersion': 2,
          'case': 'village-eight',
        });
        for (final id in ['run-0', 'run-1']) {
          final line = GameBenchmarkLog.chunkLines(payload, id: id).single;
          final envelope = jsonDecode(
            line.substring(GameBenchmarkLog.chunkPrefix.length),
          ) as Map;
          expect(envelope['id'], id);
          expect(envelope['part'], 1);
          expect(envelope['total'], 1);
          expect(
            utf8.decode(base64Decode(envelope['data'] as String)),
            payload,
          );
        }
      },
    );

    test('unsafe or oversized identifiers cannot expand or split a native log line', () {
      for (final id in [
        '',
        '日本語',
        'line\nbreak',
        'has space',
        'quoted"',
        List.filled(65, 'a').join(),
      ]) {
        expect(
          () => GameBenchmarkLog.chunkLines('{}', id: id).toList(),
          throwsArgumentError,
        );
      }
    });
  });

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
    test('CPU uses native elapsed deltas, allows multiple cores, and weights intervals', () async {
      final clock = DiagnosticClock();
      var reads = 0;
      final diagnostics = clock.diagnostics(() async {
        // Deliberately unlike the Dart request clock and process lifetime.
        return switch (reads++) {
          0 => deviceSnapshot(cpu: 500, uptime: 100000),
          1 => deviceSnapshot(cpu: 520, uptime: 100010),
          _ => deviceSnapshot(cpu: 522, uptime: 100014),
        };
      });
      await diagnostics.beginCase();
      clock.advance(10);
      diagnostics.poll();
      await flushReads();
      clock.advance(8);
      final result = (await diagnostics.finishCase())!;
      final cpu = result['processCpu']! as Map;
      expect(cpu['status'], 'available');
      expect(cpu['cpuSeconds'], 22.0);
      expect(cpu['elapsedSeconds'], 14.0);
      expect(cpu['oneCorePercent'], closeTo(22 / 14 * 100, 1e-9));
      expect(cpu['maximumIntervalOneCorePercent'], 200.0);
      expect((cpu['intervals'] as List).map((e) => e['oneCorePercent']), [
        200.0,
        50.0,
      ]);
      expect(cpu['startCaseElapsedMs'], 0.0);
      expect(cpu['endCaseElapsedMs'], 18000.0);
      expect(cpu['measurementWindow'], contains('no warmup exclusion'));
      expect(cpu['clock'], contains('not process lifetime'));
    });

    test(
      'CPU window begins at the first snapshot, including its native latency',
      () async {
        final clock = DiagnosticClock();
        var reads = 0;
        final diagnostics = clock.diagnostics(() async {
          clock.advance(++reads == 1 ? 2 : 1);
          return deviceSnapshot(
            cpu: 10 + clock.micros / 1e6,
            uptime: 1000 + clock.micros / 1e6,
          );
        });
        await diagnostics.beginCase();
        clock.advance(8);
        final result = (await diagnostics.finishCase())!;
        final cpu = result['processCpu']! as Map;
        expect(result['sceneRenderMeasurementSeconds'], 11.0);
        expect(cpu['elapsedSeconds'], 9.0);
        expect(cpu['cpuSeconds'], 9.0);
        expect(cpu['oneCorePercent'], 100.0);
        expect((cpu['start'] as Map)['sampleSystemUptimeSeconds'], 1002.0);
      },
    );

    test(
      'raw OS metrics and memory extrema remain in low-frequency case evidence',
      () async {
        final clock = DiagnosticClock();
        var reads = 0;
        final diagnostics = clock.diagnostics(
          () async => deviceSnapshot(
            cpu: (reads * 10).toDouble(),
            uptime: (1000 + reads++ * 10).toDouble(),
            footprint: reads == 2 ? 650000000 : 500000000,
          ),
        );
        await diagnostics.beginCase();
        clock.advance(10);
        diagnostics.poll();
        await flushReads();
        clock.advance(10);
        final result = (await diagnostics.finishCase())!;
        final metrics = result['deviceMetrics']! as Map;
        expect((metrics['memory'] as Map)['maximumSampledValue'], 650000000);
        expect((metrics['memory'] as Map)['minimumSampledValue'], 500000000);
        expect(
          ((metrics['battery'] as Map)['end'] as Map)['state'],
          'unplugged',
        );
        expect(
          ((metrics['screenBrightness'] as Map)['start'] as Map)['value'],
          .4,
        );
        expect(
          ((metrics['activeProcessorCount'] as Map)['start'] as Map)['count'],
          6,
        );
        final samples = (result['thermal'] as Map)['samples'] as List;
        expect(samples.length, 3);
        expect(samples.every((e) => e['thermalState'] == 'fair'), isTrue);
        expect(
          ((samples[1]['metrics'] as Map)['memory']
              as Map)['physicalFootprintBytes'],
          650000000,
        );
        expect(jsonDecode(jsonEncode(result)), isA<Map>());
      },
    );

    test('missing metrics keep unavailable reasons and never infer CPU from uptime', () async {
      final clock = DiagnosticClock();
      final diagnostics = clock.diagnostics(() async => thermal('nominal'));
      await diagnostics.beginCase();
      clock.advance(8);
      final result = (await diagnostics.finishCase())!;
      final cpu = result['processCpu']! as Map;
      expect(cpu['status'], 'unavailable');
      expect(cpu['oneCorePercent'], isNull);
      expect(cpu['availableSamples'], 0);
      final metrics = result['deviceMetrics'] as Map;
      expect((metrics['memory'] as Map)['status'], 'unavailable');
      expect(
        ((metrics['battery'] as Map)['end'] as Map)['reason'],
        'notReported',
      );
    });

    test('an unavailable middle sample marks CPU partial without losing cumulative evidence', () async {
      final clock = DiagnosticClock();
      var reads = 0;
      final diagnostics = clock.diagnostics(() async {
        if (++reads == 2) return thermal('nominal');
        return deviceSnapshot(
          cpu: clock.micros / 1e6 * 1.5,
          uptime: clock.micros / 1e6,
        );
      });
      await diagnostics.beginCase();
      clock.advance(10);
      diagnostics.poll();
      await flushReads();
      clock.advance(10);
      final result = (await diagnostics.finishCase())!;
      final cpu = result['processCpu']! as Map;
      expect(cpu['status'], 'partial');
      expect(cpu['availableSamples'], 2);
      expect(cpu['oneCorePercent'], 150.0);
      expect(((result['thermal'] as Map)['samples'] as List).length, 3);
    });

    test('counter reset and non-increasing native time invalidate aggregate CPU rates', () async {
      for (final last in [
        (cpu: 9.0, uptime: 1010.0),
        (cpu: 15.0, uptime: 1000.0),
        (cpu: 15.0, uptime: 999.0),
      ]) {
        final clock = DiagnosticClock();
        var reads = 0;
        final diagnostics = clock.diagnostics(
          () async => ++reads == 1
              ? deviceSnapshot(cpu: 10, uptime: 1000)
              : deviceSnapshot(cpu: last.cpu, uptime: last.uptime),
        );
        await diagnostics.beginCase();
        clock.advance(8);
        final cpu = (await diagnostics.finishCase())!['processCpu']! as Map;
        expect(cpu['status'], 'unavailable');
        expect(cpu['reason'], 'invalidCounterSequence');
        expect(cpu['oneCorePercent'], isNull);
        expect((cpu['intervals'] as List).single['oneCorePercent'], isNull);
      }
    });

    test(
      'invalid numeric CPU evidence and single snapshots cannot create rates',
      () async {
        for (final value in [double.nan, double.infinity, -1.0]) {
          final clock = DiagnosticClock();
          final diagnostics = clock.diagnostics(
            () async => deviceSnapshot(cpu: value, uptime: 1000),
          );
          await diagnostics.beginCase();
          clock.advance(8);
          final cpu = (await diagnostics.finishCase())!['processCpu']! as Map;
          expect(cpu['status'], 'unavailable');
          expect(cpu['oneCorePercent'], isNull);
        }
        final clock = DiagnosticClock();
        final diagnostics = clock.diagnostics(
          () async => deviceSnapshot(cpu: 10, uptime: 1000),
        );
        await diagnostics.beginCase();
        final cpu = (await diagnostics.finishCase())!['processCpu']! as Map;
        expect(cpu['reason'], 'insufficientSamples');
        expect(cpu['oneCorePercent'], isNull);
      },
    );

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

  group('benchmark completion', () {
    test('playing uses normal pause to clear held input then freezes audio and clips', () {
      final game = CompletionController();
      game.state!
        ..inputY = 1
        ..sprint = true
        ..aiming = true;
      GameBenchmark.pauseCompletedWorkload(game);
      expect(game.state!.phase, PlayPhase.paused);
      expect(game.state!.inputY, 0);
      expect(game.state!.sprint, isFalse);
      expect(game.state!.aiming, isFalse);
      expect(game.calls, ['toggle:paused', 'prepareStaticFrame']);
      game.calls.clear();
      GameBenchmark.pauseCompletedWorkload(game);
      expect(game.state!.phase, PlayPhase.paused);
      expect(game.calls, ['prepareStaticFrame']);
    });

    test(
      'cinematic pauses in place without completing or skipping the event',
      () {
        final game = CompletionController();
        game.state!.phase = PlayPhase.cinematic;
        game.director = HazardDirector('opening')..index = 1;
        final director = game.director;
        GameBenchmark.pauseCompletedWorkload(game);
        expect(game.state!.phase, PlayPhase.cinematic);
        expect(game.director, same(director));
        expect(game.director!.index, 1);
        expect(game.director!.paused, isTrue);
        expect(game.calls, ['eventPaused:true', 'prepareStaticFrame']);
      },
    );

    test('interrupted menus remain intact and disposed or absent games are ignored', () {
      final game = CompletionController();
      game.state!.phase = PlayPhase.settings;
      GameBenchmark.pauseCompletedWorkload(game);
      expect(game.state!.phase, PlayPhase.settings);
      expect(game.calls, ['prepareStaticFrame']);
      game.calls.clear();
      game.disposed = true;
      GameBenchmark.pauseCompletedWorkload(game);
      game.disposed = false;
      game.state = null;
      GameBenchmark.pauseCompletedWorkload(game);
      expect(game.calls, isEmpty);
    });
  });
}
