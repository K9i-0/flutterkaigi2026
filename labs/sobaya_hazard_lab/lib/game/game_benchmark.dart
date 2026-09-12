import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'game_controller.dart';
import 'game_device_diagnostics.dart';
import 'game_state.dart';
import 'game_settings.dart';

/// Lossless transport for native consoles that truncate long log messages.
///
/// Every line starts with [chunkPrefix], followed by an ASCII JSON envelope:
/// `{ "id": "record-id", "part": 1, "total": N, "data": "base64" }`.
/// Parts are one-based. Group by id, require a consistent total and all parts,
/// concatenate data in part order, then base64-decode and UTF-8-decode the
/// result to recover the original JSON text. Identical duplicate parts may be
/// discarded; conflicting duplicates or missing parts must not yield a record.
abstract final class GameBenchmarkLog {
  static const chunkPrefix = 'HAZARD_GAME_BENCHMARK_CHUNK ';
  static const chunkDataCharacters = 512;

  /// Encode the entire UTF-8 payload before splitting: a part can end between
  /// UTF-8 bytes, so decode only after reassembly. No compression is required.
  static Iterable<String> chunkLines(
    String payload, {
    required String id,
  }) sync* {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id)) {
      throw ArgumentError.value(
        id,
        'id',
        'Expected 1–64 ASCII identifier characters',
      );
    }
    final encoded = base64Encode(utf8.encode(payload));
    final total = math.max(
      1,
      (encoded.length + chunkDataCharacters - 1) ~/ chunkDataCharacters,
    );
    for (var part = 1; part <= total; part++) {
      final start = (part - 1) * chunkDataCharacters;
      yield '$chunkPrefix${jsonEncode({'id': id, 'part': part, 'total': total, 'data': encoded.substring(start, math.min(start + chunkDataCharacters, encoded.length))})}';
    }
  }
}

/// Compile-time workload limits, independent of saved player preferences.
class GameBenchmarkConfig {
  const GameBenchmarkConfig._(this.frameRateLimit, this.seconds);

  factory GameBenchmarkConfig.parse({String fps = '60', String seconds = '8'}) {
    if (fps != '30' && fps != '60') {
      throw ArgumentError.value(
        fps,
        'HAZARD_BENCHMARK_FPS',
        'Expected 30 or 60',
      );
    }
    final duration = RegExp(r'^[0-9]+$').hasMatch(seconds)
        ? int.tryParse(seconds)
        : null;
    if (duration == null || duration < 8 || duration > 300) {
      throw ArgumentError.value(
        seconds,
        'HAZARD_BENCHMARK_SECONDS',
        'Expected an integer between 8 and 300',
      );
    }
    return GameBenchmarkConfig._(int.parse(fps), duration);
  }

  factory GameBenchmarkConfig.fromEnvironment() => GameBenchmarkConfig.parse(
    fps: const String.fromEnvironment(
      'HAZARD_BENCHMARK_FPS',
      defaultValue: '60',
    ),
    seconds: const String.fromEnvironment(
      'HAZARD_BENCHMARK_SECONDS',
      defaultValue: '8',
    ),
  );

  final int frameRateLimit;
  final int seconds;
  int get deadlineSeconds => math.max(30, seconds + 22);

  bool shouldFinish(
    Duration elapsed, {
    required int samples,
    required bool semanticReady,
  }) =>
      elapsed >= Duration(seconds: seconds) &&
      ((samples >= 240 && semanticReady) ||
          elapsed >= Duration(seconds: deadlineSeconds));
}

/// Per-case render-call and OS-state evidence. The caller's existing poll timer
/// drives sampling; this object owns no timer and starts at most one read.
class GameBenchmarkDiagnostics {
  GameBenchmarkDiagnostics({
    required this.renderCount,
    required this.elapsedMicroseconds,
    Future<Map<String, Object?>> Function()? readThermal,
    DateTime Function()? utcNow,
  }) : readThermal = readThermal ?? HazardDeviceDiagnostics.readThermalState,
       utcNow = utcNow ?? (() => DateTime.now().toUtc());

  final int Function() renderCount;
  final int Function() elapsedMicroseconds;
  final Future<Map<String, Object?>> Function() readThermal;
  final DateTime Function() utcNow;
  final _samples = <Map<String, Object?>>[];
  Future<void>? _pending;
  int _generation = 0,
      _startMicros = 0,
      _startRenderCount = 0,
      _nextSampleMicros = 0;
  int? _lastSampleRequestedMicros;
  bool _active = false, _finishing = false;

  Future<void> beginCase() {
    final generation = ++_generation;
    _active = true;
    _finishing = false;
    _samples.clear();
    _lastSampleRequestedMicros = null;
    _startMicros = elapsedMicroseconds();
    _startRenderCount = renderCount();
    _nextSampleMicros = _startMicros;
    if (_pending != null) {
      // An old case's read cannot be cancelled. Wait for it, discard its
      // response, then take this case's initial sample without overlapping.
      return _pending!.then((_) {
        if (_active && generation == _generation) return _sample();
      });
    }
    return _sample();
  }

  void poll() {
    if (_active && !_finishing && elapsedMicroseconds() >= _nextSampleMicros) {
      unawaited(_sample());
    }
  }

  Future<void> _sample() {
    if (!_active) return Future<void>.value();
    if (_pending != null) return _pending!;
    final generation = _generation;
    final requestedMicros = elapsedMicroseconds();
    final requestedAt = utcNow().toUtc().toIso8601String();
    _nextSampleMicros =
        requestedMicros + const Duration(seconds: 10).inMicroseconds;
    final future = () async {
      Map<String, Object?> state;
      try {
        state = await readThermal();
      } catch (_) {
        state = {
          'status': 'unavailable',
          'available': false,
          'reason': 'readFailed',
        };
      }
      if (!_active || generation != _generation) return;
      _lastSampleRequestedMicros = requestedMicros;
      _samples.add({
        ...state,
        'requestedAtUtc': requestedAt,
        'completedAtUtc': utcNow().toUtc().toIso8601String(),
        'caseElapsedMs': (requestedMicros - _startMicros) / 1000,
        'completedCaseElapsedMs': (elapsedMicroseconds() - _startMicros) / 1000,
      });
    }();
    _pending = future.whenComplete(() => _pending = null);
    return _pending!;
  }

  Future<Map<String, Object?>?> finishCase() async {
    if (!_active) return null;
    final generation = _generation;
    final requestedEndMicros = elapsedMicroseconds();
    _finishing = true;
    // A boundary sample can reuse the request started by this same poll.
    await _pending;
    if (!_active || generation != _generation) return null;
    if ((_lastSampleRequestedMicros ?? -1) < requestedEndMicros) {
      await _sample();
    }
    if (!_active || generation != _generation) return null;
    final endCount = renderCount();
    final elapsedSeconds = (elapsedMicroseconds() - _startMicros) / 1e6;
    final calls = endCount - _startRenderCount;
    const ranks = {'nominal': 0, 'fair': 1, 'serious': 2, 'critical': 3};
    Map<String, Object?>? peak;
    for (final sample in _samples) {
      final rank = ranks[sample['thermalState']];
      if (sample['available'] == true &&
          rank != null &&
          (peak == null || rank > ranks[peak['thermalState']]!)) {
        peak = sample;
      }
    }
    _active = false;
    return {
      'sceneRenderCountStart': _startRenderCount,
      'sceneRenderCountEnd': endCount,
      'sceneRenderCalls': calls >= 0 ? calls : null,
      'sceneRenderMeasurementSeconds': elapsedSeconds,
      'sceneRenderCallsPerSecond': calls >= 0 && elapsedSeconds > 0
          ? calls / elapsedSeconds
          : null,
      'sceneRenderMeasurement': 'Scene.render calls that returned per real elapsed second; not presented FPS or GPU completion',
      'processCpu': _cpuSummary(),
      'deviceMetrics': {
        'measurement': 'Native snapshots at case boundaries and every ten seconds; not GPU utilization or temperature in degrees',
        'memory': _metricSummary('memory', 'physicalFootprintBytes'),
        'battery': _metricSummary('battery', 'level'),
        'screenBrightness': _metricSummary('screenBrightness', 'value'),
        'activeProcessorCount': _metricSummary('activeProcessorCount', 'count'),
      },
      'thermal': {
        'status': peak == null
            ? 'unavailable'
            : _samples.every((sample) => sample['available'] == true)
            ? 'available'
            : 'partial',
        'sampleIntervalSeconds': 10,
        'start': _samples.firstOrNull,
        'end': _samples.lastOrNull,
        'peakState': peak?['thermalState'],
        'peakRecordedAtUtc': peak?['completedAtUtc'],
        'samples': List<Map<String, Object?>>.of(_samples),
      },
    };
  }

  Map<String, Object?> _metric(Map<String, Object?> sample, String name) {
    final metrics = sample['metrics'];
    final metric = metrics is Map ? metrics[name] : null;
    return metric is Map
        ? Map<String, Object?>.from(metric)
        : {
            'status': 'unavailable',
            'available': false,
            'reason': 'notReported',
          };
  }

  static double? _nonnegativeNumber(Object? value) =>
      value is num && value.isFinite && value >= 0 ? value.toDouble() : null;

  Map<String, Object?> _metricSummary(String name, String valueKey) {
    final metrics = _samples.map((sample) => _metric(sample, name)).toList();
    final values = metrics
        .where((metric) => metric['available'] == true)
        .map((metric) => _nonnegativeNumber(metric[valueKey]))
        .whereType<double>()
        .toList();
    return {
      'status': values.isEmpty
          ? 'unavailable'
          : values.length == metrics.length
          ? 'available'
          : 'partial',
      'valueField': valueKey,
      'start': metrics.firstOrNull,
      'end': metrics.lastOrNull,
      'minimumSampledValue': values.isEmpty ? null : values.reduce(math.min),
      'maximumSampledValue': values.isEmpty ? null : values.reduce(math.max),
    };
  }

  Map<String, Object?> _cpuSummary() {
    final validSamples =
        <({Map<String, Object?> sample, double cpu, double uptime})>[];
    for (final sample in _samples) {
      final metric = _metric(sample, 'processCpu');
      final cpu = _nonnegativeNumber(metric['totalSeconds']);
      final uptime = _nonnegativeNumber(metric['sampleSystemUptimeSeconds']);
      if (metric['available'] == true && cpu != null && uptime != null) {
        validSamples.add((sample: sample, cpu: cpu, uptime: uptime));
      }
    }
    final intervals = <Map<String, Object?>>[];
    for (var i = 1; i < validSamples.length; i++) {
      final start = validSamples[i - 1], end = validSamples[i];
      final cpuSeconds = end.cpu - start.cpu;
      final elapsedSeconds = end.uptime - start.uptime;
      final valid = cpuSeconds >= 0 && elapsedSeconds > 0;
      intervals.add({
        'status': valid ? 'available' : 'unavailable',
        if (!valid)
          'reason': cpuSeconds < 0
              ? 'cpuCounterDecreased'
              : 'nonIncreasingClock',
        'startCaseElapsedMs': start.sample['caseElapsedMs'],
        'endCaseElapsedMs': end.sample['caseElapsedMs'],
        'elapsedSeconds': elapsedSeconds > 0 ? elapsedSeconds : null,
        'cpuSeconds': cpuSeconds >= 0 ? cpuSeconds : null,
        'oneCorePercent': valid ? cpuSeconds / elapsedSeconds * 100 : null,
      });
    }
    final valid =
        intervals.isNotEmpty &&
        intervals.every((interval) => interval['status'] == 'available');
    final start = validSamples.firstOrNull, end = validSamples.lastOrNull;
    final cpuSeconds = valid ? end!.cpu - start!.cpu : null;
    final elapsedSeconds = valid ? end!.uptime - start!.uptime : null;
    final rates = intervals
        .map((interval) => interval['oneCorePercent'])
        .whereType<double>()
        .toList();
    return {
      'status': !valid
          ? 'unavailable'
          : validSamples.length == _samples.length
          ? 'available'
          : 'partial',
      if (!valid)
        'reason': intervals.isEmpty
            ? 'insufficientSamples'
            : 'invalidCounterSequence',
      'scope': 'processAllThreads',
      'usageConvention': 'oneCore100Percent',
      'measurement': '100 * cumulative process CPU seconds delta / native sampleSystemUptimeSeconds delta; 100 percent is one core and values above 100 are valid',
      'measurementWindow': 'First to last available native CPU snapshot after case setup; no warmup exclusion; separate from the last 240 Flutter frame durations',
      'clock': 'ProcessInfo.systemUptime differences, not process lifetime',
      'sampleIntervalSeconds': 10,
      'availableSamples': validSamples.length,
      'start': start == null ? null : _metric(start.sample, 'processCpu'),
      'end': end == null ? null : _metric(end.sample, 'processCpu'),
      'startCaseElapsedMs': start?.sample['caseElapsedMs'],
      'endCaseElapsedMs': end?.sample['caseElapsedMs'],
      'elapsedSeconds': elapsedSeconds,
      'cpuSeconds': cpuSeconds,
      'oneCorePercent': valid ? cpuSeconds! / elapsedSeconds! * 100 : null,
      'maximumIntervalOneCorePercent': rates.isEmpty
          ? null
          : rates.reduce(math.max),
      'intervals': intervals,
    };
  }

  void stop() {
    _active = false;
    _generation++;
  }
}

/// Opt-in Flutter frame-duration profile with separately labelled render-call
/// cadence and OS thermal snapshots, never inferred presentation or GPU time.
class GameBenchmark {
  GameBenchmark(this.game)
    : configuration = GameBenchmarkConfig.fromEnvironment(),
      diagnostics = GameBenchmarkDiagnostics(
        renderCount: () => game.sceneRenderCount,
        elapsedMicroseconds: () => game.diagnosticClock.elapsedMicroseconds,
      ) {
    if (cases.isEmpty) {
      throw ArgumentError.value(
        const String.fromEnvironment('HAZARD_BENCHMARK_CASE'),
        'HAZARD_BENCHMARK_CASE',
        'No benchmark case matches this name',
      );
    }
    game.benchmarkMode = true;
    // Reproducible audible settings without writing the user's preferences.
    game.settings = HazardSettings(
      cinematicLighting: const bool.fromEnvironment(
        'HAZARD_CINEMATIC',
        defaultValue: true,
      ),
      graphicsPreset: benchmarkGraphics,
      frameRateLimit: configuration.frameRateLimit,
    );
    game.lighting.apply(
      game.scene,
      enabled: game.settings.cinematicLighting,
      preset: game.settings.graphicsPreset,
    );
    unawaited(next());
    timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => unawaited(poll()),
    );
  }
  final HazardGameController game;
  final GameBenchmarkConfig configuration;
  final GameBenchmarkDiagnostics diagnostics;
  bool _disposed = false, _closingCase = false, _preparingCase = false;
  Timer? timer;
  final watch = Stopwatch();
  int index = -1;
  bool interrupted = false, heardAmbience = false, heardSpeech = false;
  int windowMotionTicks = 0, completedPassages = 0;
  bool playerWasVaulting = false;
  int pursuitTicks = 0, searchTicks = 0, beerPreviewTicks = 0;
  int maxConcurrentSearchers = 0, maxBeerGuideSprites = 0;
  final observedPursuers = <int>{},
      movingSearchers = <int>{},
      advancedSearchers = <int>{};
  final speechMorphTicks = <String, int>{};
  static final benchmarkGraphics = _graphics();
  static final overrideScale = _scale();
  static HazardGraphicsPreset _graphics() {
    const name = String.fromEnvironment(
      'HAZARD_GRAPHICS',
      defaultValue: 'quality',
    );
    if (!HazardGraphicsPreset.values.any((preset) => preset.name == name)) {
      throw ArgumentError.value(name, 'HAZARD_GRAPHICS');
    }
    return HazardGraphicsPreset.decode(name);
  }

  static double? _scale() {
    const raw = String.fromEnvironment('HAZARD_BENCHMARK_SCALE');
    if (raw.isEmpty) return null;
    final scale = double.tryParse(raw);
    if (scale == null || !scale.isFinite || scale < .5 || scale > 1) {
      throw ArgumentError.value(
        raw,
        'HAZARD_BENCHMARK_SCALE',
        'Expected a finite resolution scale between 0.5 and 1.0',
      );
    }
    return scale;
  }

  static final cases = allCases
      .where(
        (c) =>
            const String.fromEnvironment('HAZARD_BENCHMARK_CASE').isEmpty ||
            c.name == const String.fromEnvironment('HAZARD_BENCHMARK_CASE'),
      )
      .toList();
  static const allCases = [
    (
      name: 'village-four',
      region: 'village',
      count: 4,
      scale: .85,
      contacts: true,
      event: null,
    ),
    (
      name: 'village-eight',
      region: 'village',
      count: 8,
      scale: .85,
      contacts: true,
      event: null,
    ),
    (
      name: 'village-eight-no-contact',
      region: 'village',
      count: 8,
      scale: .85,
      contacts: false,
      event: null,
    ),
    (
      name: 'village-eight-full',
      region: 'village',
      count: 8,
      scale: 1.0,
      contacts: true,
      event: null,
    ),
    (
      name: 'farm-six',
      region: 'farm',
      count: 6,
      scale: .85,
      contacts: true,
      event: null,
    ),
    (
      name: 'mountain-six',
      region: 'mountain',
      count: 6,
      scale: .85,
      contacts: true,
      event: null,
    ),
    (
      name: 'mountain-six-full',
      region: 'mountain',
      count: 6,
      scale: 1.0,
      contacts: true,
      event: null,
    ),
    (
      name: 'window-player',
      region: 'village',
      count: 0,
      scale: .85,
      contacts: true,
      event: null,
    ),
    (
      name: 'window-enemies',
      region: 'village',
      count: 2,
      scale: .85,
      contacts: true,
      event: null,
    ),
    (
      name: 'stealth-search',
      region: 'village',
      count: 6,
      scale: .85,
      contacts: true,
      event: null,
    ),
    (
      name: 'beer-preview',
      region: 'village',
      count: 0,
      scale: .85,
      contacts: true,
      event: null,
    ),
    (
      name: 'opening-voice',
      region: 'village',
      count: 8,
      scale: .85,
      contacts: true,
      event: 'opening',
    ),
    (
      name: 'boss-voice',
      region: 'mountain',
      count: 6,
      scale: .85,
      contacts: true,
      event: 'last_order',
    ),
  ];

  /// Load each required region before fixtures or measurement clocks begin.
  /// A rejected transition must not spin forever on the same old region.
  @visibleForTesting
  static Future<bool> prepareRegion(
    HazardGameController game,
    String region, {
    required bool Function() cancelled,
  }) async {
    if (cancelled() || game.disposed || !await game.restart()) return false;
    if (cancelled() || game.disposed) return false;
    final epoch = game.runEpoch;
    final visited = <String>{};
    while (game.state!.zoneId != region) {
      final current = game.state!;
      if (!visited.add(current.zoneId)) return false;
      current.exitRequested = Map<String, dynamic>.from(
        (current.map['exits'] as List).last,
      );
      current.phase = PlayPhase.transition;
      if (!await game.transitionRegion() ||
          cancelled() ||
          game.disposed ||
          game.runEpoch != epoch) {
        return false;
      }
    }
    return true;
  }

  Future<void> next() async {
    if (_disposed || _preparingCase) return;
    _preparingCase = true;
    watch.stop();
    try {
      index++;
      if (index == cases.length) {
        dispose();
        pauseCompletedWorkload(game);
        debugPrintSynchronously('HAZARD_GAME_BENCHMARK_COMPLETE');
        return;
      }
      final c = cases[index];
      if (!await prepareRegion(game, c.region, cancelled: () => _disposed)) {
        if (_disposed || game.disposed) return;
        throw StateError('Could not load benchmark region ${c.region}');
      }
      game.director = null;
      final s = game.state!;
      final caseEpoch = game.runEpoch;
      s.seenEvents.addAll(['opening', 'farm', 'last_order', 'ending']);
      s.checkpointRequested = false;
      s.phase = PlayPhase.playing;
      final baseX = c.region == 'mountain' ? 8.0 : 0.0;
      final baseZ = c.region == 'mountain'
          ? 1.0
          : c.region == 'farm'
          ? -8.0
          : -13.0;
      s.x = baseX;
      s.z = baseZ;
      s.health = 100000;
      for (final e in s.enemies) {
        e.active = e.id < c.count;
        e.alerted = false;
        e.x = baseX + (e.id % 4 - 1.5) * 1.5;
        e.z = baseZ + 6 + (e.id ~/ 4) * 2;
        e.heading = math.atan2(s.x - e.x, s.z - e.z);
        e.ambientDance = null;
      }
      // Align the saved-settings snapshot with the actual workload. The previous
      // full-resolution cases incorrectly logged the constructor's 85% setting.
      game.settings.renderScale = overrideScale ?? c.scale;
      game.scene.renderScale = game.settings.renderScale;
      game.contactShadows?.node.visible = c.contacts;
      windowMotionTicks = completedPassages = 0;
      playerWasVaulting = false;
      pursuitTicks = searchTicks = beerPreviewTicks = 0;
      maxConcurrentSearchers = maxBeerGuideSprites = 0;
      observedPursuers.clear();
      movingSearchers.clear();
      advancedSearchers.clear();
      if (c.name == 'stealth-search') {
        // A recorded sighting outside the barn, followed by the player hiding
        // inside its real west wall. AI must generate and visit its own guesses.
        s.x = -7.8;
        s.z = 11;
        s.yaw = math.pi / 2;
        s.invulnerable = 100000;
        for (final e in s.enemies.where((e) => e.active)) {
          e
            ..x = -10.8
            ..z = 6.5 + e.id * 1.2
            ..heading = 0
            ..alerted = true
            ..lastKnownX = -10.5
            ..lastKnownY = 0
            ..lastKnownZ = 11
            ..knowledgeSource = 'sight'
            ..knowledgeTime = s.time
            ..observedHeading = 0;
        }
      } else if (c.name == 'beer-preview') {
        s.beers = 10;
        s.equip('beer');
        s.aiming = true;
        s.pitch = -.15;
        s.invulnerable = 100000;
      } else if (c.event == null && !c.name.startsWith('window-')) {
        stageVisiblePursuers(baseX, baseZ);
      }
      if (c.name.startsWith('window-')) {
        final w = s.windows.first;
        s.x = w.x;
        s.y = 0;
        s.pitch = .12;
        s.invulnerable = 100000;
        if (c.name == 'window-player') {
          s.z = w.entryZ(true);
          s.yaw = math.pi;
        } else {
          s.z = w.exitZ(true) + 2;
          s.yaw = 0;
          resetWindowEnemies();
        }
      }
      if (c.event != null) {
        s.seenEvents.remove(c.event);
        if (c.event == 'opening') {
          // Reverse shots are authored at the actual entrance. The generic
          // crowd staging point left Fukuchan outside his own camera frame.
          s.x = (s.map['spawn']['x'] as num).toDouble();
          s.z = (s.map['spawn']['z'] as num).toDouble();
        }
        game.startEvent(c.event!);
        if (c.event == 'opening') game.director!.index = 1;
      }
      heardAmbience = heardSpeech = false;
      speechMorphTicks.clear();
      interrupted = false;
      await diagnostics.beginCase();
      if (_disposed || game.disposed) return;
      if (game.runEpoch != caseEpoch || !identical(game.state, s)) {
        throw StateError('Benchmark run was replaced during setup');
      }
      game.frames.reset();
      watch
        ..reset()
        ..start();
    } catch (error) {
      if (!_disposed) {
        debugPrintSynchronously(
          'HAZARD_GAME_BENCHMARK_SETUP_ERROR ${jsonEncode({'case': index >= 0 && index < cases.length ? cases[index].name : null, 'error': '$error', 'valid': false})}',
        );
        dispose();
        pauseCompletedWorkload(game);
      }
    } finally {
      _preparingCase = false;
    }
  }

  Future<void> poll() async {
    if (_disposed || _closingCase || _preparingCase) return;
    diagnostics.poll();
    if (!configuration.shouldFinish(
      watch.elapsed,
      samples: game.frames.count,
      semanticReady: semanticReady,
    )) {
      return;
    }
    final closingIndex = index;
    _closingCase = true;
    try {
      final diagnosticResult = await diagnostics.finishCase();
      if (_disposed || index != closingIndex || diagnosticResult == null) {
        return;
      }
      final ready = semanticReady;
      final payload = jsonEncode({
        'schemaVersion': 2,
        'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'runLabel': const String.fromEnvironment('HAZARD_BENCHMARK_RUN'),
        'case': cases[index].name,
        'benchmarkDurationSeconds': configuration.seconds,
        'benchmarkDeadlineSeconds': configuration.deadlineSeconds,
        'benchmarkFrameRateLimit': configuration.frameRateLimit,
        'settings': jsonDecode(game.settings.encode()),
        'lighting': game.lighting.inspect(game.scene),
        'audio': {
          'observedAmbience': heardAmbience,
          'observedSpeech': heardSpeech,
          'voice': game.voice.inspect(),
          'soundscape': game.soundscape.inspect(),
        },
        'region': cases[index].region,
        'contactShadows': cases[index].contacts,
        'profile': kProfileMode,
        'valid':
            kProfileMode &&
            game.frames.count == 240 &&
            !interrupted &&
            game.foreground &&
            game.state!.phase == expectedPhase &&
            ready &&
            game.voice.inspect()['errors'].isEmpty,
        'speechMorphTicks': speechMorphTicks,
        'eventShot': game.director?.index,
        'windowMotionTicks': windowMotionTicks,
        'completedWindowPassages': completedPassages,
        'workload': {
          'observedVisualPursuers': observedPursuers.toList()..sort(),
          'pursuitTicks': pursuitTicks,
          'searchTicks': searchTicks,
          'maxConcurrentSearchers': maxConcurrentSearchers,
          'movingSearchers': movingSearchers.toList()..sort(),
          'advancedSearchers': advancedSearchers.toList()..sort(),
          'beerPreviewTicks': beerPreviewTicks,
          'maxBeerGuideSprites': maxBeerGuideSprites,
          'activeEnemies': game.state!.enemies
              .where((e) => e.active && e.alive)
              .length,
          'currentSearchingEnemies': currentSearchers.length,
          'beerGuideVisible': game.beerVisuals.dots.node.visible,
          'semanticReady': ready,
        },
        'interrupted': interrupted,
        'foreground': game.foreground,
        'gamePhase': game.state!.phase.name,
        'simulatedSeconds': game.state!.time,
        'renderScale': game.scene.renderScale,
        'viewport': [game.viewport.width, game.viewport.height],
        'devicePixelRatio': game.devicePixelRatio,
        'renderPixels': [
          (game.viewport.width * game.devicePixelRatio * game.scene.renderScale)
              .ceil(),
          (game.viewport.height *
                  game.devicePixelRatio *
                  game.scene.renderScale)
              .ceil(),
        ],
        'measurement': 'Flutter UI and raster thread durations; not GPU execution time or presented FPS',
        'elapsedMs': watch.elapsedMilliseconds,
        ...game.frames.toJson(),
        ...diagnosticResult,
      });
      final recordId =
          '${DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(36)}-${index.toRadixString(36)}';
      // Emit complete short records before the legacy line, which iOS may cut.
      // This work runs after diagnostics finish and does not enter their window.
      for (final line in GameBenchmarkLog.chunkLines(payload, id: recordId)) {
        debugPrintSynchronously(line);
      }
      debugPrintSynchronously('HAZARD_GAME_BENCHMARK $payload');
      await next();
    } finally {
      _closingCase = false;
    }
  }

  PlayPhase get expectedPhase =>
      cases[index].event == null ? PlayPhase.playing : PlayPhase.cinematic;

  // Fast rendering can fill the frame buffer before a voiced shot or window
  // traversal finishes. Reuse the actual workload requirements for waiting
  // and validity, while the configured deadline still reports failures.
  bool get semanticReady {
    final c = cases[index];
    final ordinaryPursuit =
        c.event == null &&
        !c.name.startsWith('window-') &&
        c.name != 'stealth-search' &&
        c.name != 'beer-preview';
    return heardAmbience &&
        (c.event == null ? game.state!.time >= 6 : heardSpeech) &&
        (!ordinaryPursuit ||
            (pursuitTicks >= 60 &&
                game.state!.enemies
                    .where((e) => e.active)
                    .every((e) => observedPursuers.contains(e.id)))) &&
        (c.name != 'stealth-search' ||
            (searchTicks >= 120 &&
                movingSearchers.length >= 3 &&
                advancedSearchers.length >= 2 &&
                currentSearchers.length >= 2)) &&
        (c.name != 'beer-preview' ||
            (beerPreviewTicks >= 120 &&
                game.state!.aiming &&
                game.state!.weapon == 'beer' &&
                game.state!.beerPreview != null &&
                game.beerVisuals.dots.node.visible &&
                game.beerVisuals.held.visible)) &&
        (!c.name.startsWith('window-') ||
            (windowMotionTicks >= 60 && completedPassages > 0)) &&
        (c.event != 'opening' ||
            [
              '福ちゃん',
              'やめ太郎',
            ].every((name) => (speechMorphTicks[name] ?? 0) > 5));
  }

  // A paused SceneView has no tick callbacks. Observe UI/lifecycle changes too
  // so a pause cannot disappear from the benchmark's interruption history.
  void observeState() {
    if (!_disposed &&
        !_preparingCase &&
        index >= 0 &&
        index < cases.length &&
        (!game.foreground || game.state!.phase != expectedPhase)) {
      interrupted = true;
    }
  }

  void tick() {
    if (_disposed || _preparingCase) return;
    observeState();
    heardAmbience |= game.soundscape.ambience.speaking;
    heardSpeech |= game.voice.speaking;
    for (final entry in game.speechWeights.entries) {
      if (entry.value > .001) {
        speechMorphTicks.update(entry.key, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    if (index < cases.length) {
      final s = game.state!;
      final name = cases[index].name;
      final visualPursuers = s.enemies
          .where((e) => e.active && e.alive && e.alerted && e.seesPlayer)
          .toList();
      observedPursuers.addAll(visualPursuers.map((e) => e.id));
      if (visualPursuers.any((e) => e.moved > .00001)) pursuitTicks++;
      final searchers = currentSearchers;
      maxConcurrentSearchers = math.max(
        maxConcurrentSearchers,
        searchers.length,
      );
      if (searchers.length >= 2) searchTicks++;
      movingSearchers.addAll(
        searchers.where((e) => e.moved > .00001).map((e) => e.id),
      );
      advancedSearchers.addAll(
        searchers.where((e) => e.searchIndex > 0).map((e) => e.id),
      );
      if (name == 'beer-preview' &&
          s.aiming &&
          s.weapon == 'beer' &&
          (s.beerPreview?.points.length ?? 0) > 3 &&
          game.beerVisuals.held.visible &&
          game.beerVisuals.dots.node.visible &&
          game.beerVisuals.dots.geometry.instanceCount > 20) {
        beerPreviewTicks++;
        maxBeerGuideSprites = math.max(
          maxBeerGuideSprites,
          game.beerVisuals.dots.geometry.instanceCount,
        );
      }
      if (name == 'window-player') {
        if (s.vault?.crossing ?? false) windowMotionTicks++;
        if (playerWasVaulting && s.vault == null) completedPassages++;
        playerWasVaulting = s.vault != null;
        if (s.vault == null && s.interaction?.startsWith('window:') == true) {
          s.yaw = s.z < s.windows.first.z ? math.pi : 0;
          s.interact();
        }
      } else if (name == 'window-enemies') {
        final enemies = s.enemies.take(2);
        if (enemies.any((e) => e.vault?.crossing ?? false)) {
          windowMotionTicks++;
        }
        if (enemies.every(
          (e) => e.vault == null && e.z > s.windows.first.z + .8,
        )) {
          completedPassages += 2;
          resetWindowEnemies();
        }
      } else if (name == 'stealth-search') {
        s.yaw = math.pi / 2 + math.sin(s.time * .3) * .15;
      } else {
        s.yaw = math.pi + math.sin(s.time * .3) * .25;
      }
    }
  }

  // A repeated rendering workload, not evidence of normal route progression.
  // Only the opt-in benchmark relocates enemies after both have landed.
  void resetWindowEnemies() {
    final s = game.state!, w = s.windows.first;
    for (var i = 0; i < 2; i++) {
      s.enemies[i]
        ..x = w.x
        ..y = 0
        ..z = w.entryZ(true) - i
        ..heading = 0
        ..vault = null
        ..climb = null
        ..attackPending = false
        ..meleeRecovery = 0
        ..approachX = null
        ..approachZ = null
        ..approachTimer = 0
        ..alerted = true
        // This traversal workload has a real last sighting on the far side.
        ..lastKnownX = s.x
        ..lastKnownY = s.y
        ..lastKnownZ = s.z
        ..knowledgeSource = 'sight'
        ..knowledgeTime = s.time
        ..searchDuration = 0
        ..searchRemaining = 0
        ..pursuitRemaining = 0
        ..memoryFlowTime = 0
        ..investigationTarget = null
        ..searchIndex = 0;
      s.enemies[i].searchPoints.clear();
    }
  }

  List<Enemy> get currentSearchers => game.state!.enemies
      .where(
        (e) =>
            e.active &&
            e.alive &&
            !e.boss &&
            e.alerted &&
            !e.seesPlayer &&
            e.awareness == EnemyAwareness.searching &&
            e.searchRemaining > 0 &&
            e.searchPoints.isNotEmpty &&
            e.memoryNavigation != null,
      )
      .toList();

  // Preserve the authored collision map. If a tree or new cover occupies an
  // old crowd slot, use a nearby free, genuinely visible staging slot.
  void stageVisiblePursuers(double baseX, double baseZ) {
    final s = game.state!;
    final placed = <Enemy>[];
    for (final e in s.enemies.where((e) => e.active)) {
      bool usable() =>
          !s.blocked(e.x, e.z, e.y, radius: e.collisionRadius) &&
          s.enemyCanSeePlayer(e) &&
          placed.every(
            (other) =>
                math.pow(other.x - e.x, 2) + math.pow(other.z - e.z, 2) >
                math.pow(other.collisionRadius + e.collisionRadius + .15, 2),
          );
      if (!usable()) {
        for (var i = 0; i < 60; i++) {
          e.x = baseX + (i % 7 - 3) * 1.5;
          e.z = baseZ + 4 + (i ~/ 7) * 1.2;
          e.y = s.floorHeight(e.x, e.z, 0);
          e.heading = math.atan2(s.x - e.x, s.z - e.z);
          if (usable()) break;
        }
      }
      placed.add(e);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    timer?.cancel();
    timer = null;
    watch.stop();
    diagnostics.stop();
  }

  /// Stop an opt-in workload without completing or skipping a story event.
  /// Keep an interrupted menu or an already paused game in its current state.
  @visibleForTesting
  static void pauseCompletedWorkload(HazardGameController game) {
    if (game.disposed || game.state == null) return;
    if (game.director != null) {
      game.setEventPaused(true);
    } else if (game.state!.running) {
      game.toggle(PlayPhase.paused);
    }
    // toggle notifies the view; freeze audio/clips now even without another tick.
    game.prepareStaticFrame();
  }
}
