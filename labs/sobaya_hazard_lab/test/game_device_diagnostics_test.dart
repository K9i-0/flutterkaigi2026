import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_device_diagnostics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(HazardDeviceDiagnostics.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  Map<String, Object> nativeState({
    String state = 'nominal',
    bool simulator = false,
  }) => {
    'thermalState': state,
    'isLowPowerModeEnabled': true,
    'systemUptime': 1234.5,
    'isSimulator': simulator,
    'isIOSAppOnMac': false,
  };

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'requests one OS snapshot and preserves all four thermal categories',
    () async {
      for (final state in ['nominal', 'fair', 'serious', 'critical']) {
        var calls = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls++;
          expect(call.method, 'getThermalState');
          expect(call.arguments, isNull);
          return nativeState(state: state);
        });
        final result = await HazardDeviceDiagnostics.readThermalState();
        expect({...result}..remove('metrics'), {
          'status': 'available',
          'available': true,
          'platform': 'ios',
          'environment': 'physicalDevice',
          'source': 'ProcessInfo',
          'thermalState': state,
          'isLowPowerModeEnabled': true,
          'systemUptime': 1234.5,
        });
        final metrics = result['metrics']! as Map;
        expect(metrics.length, 5);
        for (final metric in metrics.values.cast<Map>()) {
          expect(metric['status'], 'unavailable');
          expect(metric['reason'], 'notReported');
        }
        expect(jsonDecode(jsonEncode(result)), result);
        expect(calls, 1);
      }
    },
  );

  test(
    'non-iOS platforms are unavailable without invoking a channel',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return nativeState();
      });
      for (final platform in TargetPlatform.values.where(
        (platform) => platform != TargetPlatform.iOS,
      )) {
        debugDefaultTargetPlatformOverride = platform;
        final result = await HazardDeviceDiagnostics.readThermalState();
        expect(result['status'], 'unavailable');
        expect(result['reason'], 'unsupportedPlatform');
        expect(result['platform'], platform.name);
      }
      expect(calls, 0);
    },
  );

  test(
    'simulator output cannot masquerade as physical device thermal data',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => nativeState(simulator: true),
      );
      final result = await HazardDeviceDiagnostics.readThermalState();
      expect(result['status'], 'unavailable');
      expect(result['reason'], 'simulator');
      expect(result.containsKey('thermalState'), isFalse);
    },
  );

  test('missing native channel is explicitly unavailable', () async {
    final result = await HazardDeviceDiagnostics.readThermalState();
    expect(result['status'], 'unavailable');
    expect(result['reason'], 'missingPlugin');
  });

  test(
    'an iOS app running on Mac is not a physical iOS device sample',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {...nativeState(), 'isIOSAppOnMac': true},
      );
      final result = await HazardDeviceDiagnostics.readThermalState();
      expect(result['status'], 'unavailable');
      expect(result['reason'], 'iosAppOnMac');
      expect(result.containsKey('thermalState'), isFalse);
    },
  );

  test(
    'native errors are unavailable without forwarding error details',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: 'nativeFailure',
          details: 'private detail',
        );
      });
      final result = await HazardDeviceDiagnostics.readThermalState();
      expect(result['status'], 'unavailable');
      expect(result['reason'], 'platformError');
      expect(jsonEncode(result), isNot(contains('private detail')));
    },
  );

  test('a stalled channel returns unavailable within its timeout', () async {
    final pending = Completer<Object?>();
    messenger.setMockMethodCallHandler(channel, (_) => pending.future);
    final result = await HazardDeviceDiagnostics.readThermalState(
      timeout: const Duration(milliseconds: 5),
    );
    expect(result['status'], 'unavailable');
    expect(result['reason'], 'timeout');
    pending.complete(nativeState());
  });

  test(
    'malformed or future native values are never reported as nominal',
    () async {
      for (final response in <Object?>[
        null,
        'nominal',
        {},
        {...nativeState(), 'thermalState': 'unknown'},
        {...nativeState(), 'systemUptime': -1},
        {...nativeState(), 'systemUptime': double.nan},
        {...nativeState(), 'isLowPowerModeEnabled': 'false'},
        {...nativeState(), 'isSimulator': null},
      ]) {
        messenger.setMockMethodCallHandler(channel, (_) async => response);
        final result = await HazardDeviceDiagnostics.readThermalState();
        expect(result['status'], 'unavailable');
        expect(result['reason'], 'invalidResponse');
        expect(result.containsKey('thermalState'), isFalse);
      }
    },
  );

  Map<String, Object> nativeMetrics() => {
    'processCpu': {
      'status': 'available',
      'available': true,
      'userSeconds': 36.5,
      'systemSeconds': 4.5,
      'totalSeconds': 41.0,
      'sampleSystemUptimeSeconds': 1234.501,
    },
    'activeProcessorCount': {
      'status': 'available',
      'available': true,
      'count': 6,
    },
    'memory': {
      'status': 'available',
      'available': true,
      'physicalFootprintBytes': 1600000000,
    },
    'battery': {
      'status': 'available',
      'available': true,
      'state': 'charging',
      'level': .65,
      'monitoringEnabled': true,
    },
    'screenBrightness': {'status': 'available', 'available': true, 'value': .4},
  };

  Future<Map> readMetrics(Object? metrics) async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {...nativeState(state: 'fair'), 'metrics': metrics},
    );
    final result = await HazardDeviceDiagnostics.readThermalState();
    expect(result['status'], 'available');
    expect(result['thermalState'], 'fair');
    expect(jsonDecode(jsonEncode(result)), result);
    return result['metrics']! as Map;
  }

  test(
    'CPU counters, memory and observation conditions retain explicit units',
    () async {
      final metrics = await readMetrics(nativeMetrics());
      final cpu = metrics['processCpu'] as Map;
      expect(cpu, {
        'status': 'available',
        'available': true,
        'source': 'getrusage(RUSAGE_SELF)',
        'scope': 'processAllThreads',
        'usageConvention': 'oneCore100Percent',
        'userSeconds': 36.5,
        'systemSeconds': 4.5,
        'totalSeconds': 41.0,
        'sampleSystemUptimeSeconds': 1234.501,
      });
      expect(cpu.containsKey('percent'), isFalse);
      expect((metrics['activeProcessorCount'] as Map)['count'], 6);
      expect((metrics['memory'] as Map)['physicalFootprintBytes'], 1600000000);
      expect((metrics['battery'] as Map)['state'], 'charging');
      expect((metrics['battery'] as Map)['level'], .65);
      expect((metrics['screenBrightness'] as Map)['value'], .4);
    },
  );

  test(
    'a failed metric cannot invalidate thermal or unrelated metrics',
    () async {
      final metrics = await readMetrics({
        ...nativeMetrics(),
        'processCpu': {
          'status': 'unavailable',
          'available': false,
          'reason': 'getrusageFailed',
        },
        'memory': {
          'status': 'unavailable',
          'available': false,
          'reason': 'taskInfoFailed',
        },
      });
      expect((metrics['processCpu'] as Map)['reason'], 'getrusageFailed');
      expect((metrics['memory'] as Map)['reason'], 'taskInfoFailed');
      expect((metrics['screenBrightness'] as Map)['status'], 'available');
      expect((metrics['battery'] as Map)['status'], 'available');
    },
  );

  test(
    'malformed and inconsistent cumulative CPU counters remain unavailable',
    () async {
      final valid = nativeMetrics()['processCpu']! as Map;
      for (final invalid in <Object?>[
        'invalid',
        {...valid, 'userSeconds': -1},
        {...valid, 'systemSeconds': double.infinity},
        {...valid, 'totalSeconds': double.nan},
        {...valid, 'totalSeconds': 10.0},
        {...valid, 'sampleSystemUptimeSeconds': -1},
        {...valid, 'sampleSystemUptimeSeconds': '1234'},
        {...valid, 'available': 'true'},
      ]) {
        final metrics = await readMetrics({
          ...nativeMetrics(),
          'processCpu': invalid,
        });
        expect((metrics['processCpu'] as Map)['status'], 'unavailable');
        expect((metrics['processCpu'] as Map)['reason'], 'invalidResponse');
        expect((metrics['memory'] as Map)['status'], 'available');
      }
    },
  );

  test(
    'metric numeric bounds reject unknown charge, invalid cores and memory',
    () async {
      final metrics = await readMetrics({
        'activeProcessorCount': {
          'status': 'available',
          'available': true,
          'count': 0,
        },
        'memory': {
          'status': 'available',
          'available': true,
          'physicalFootprintBytes': 1.5,
        },
        'battery': {
          'status': 'available',
          'available': true,
          'state': 'full',
          'level': -1,
          'monitoringEnabled': true,
        },
        'screenBrightness': {
          'status': 'available',
          'available': true,
          'value': 1.1,
        },
      });
      for (final name in [
        'activeProcessorCount',
        'memory',
        'battery',
        'screenBrightness',
      ]) {
        expect((metrics[name] as Map)['reason'], 'invalidResponse');
      }
      expect((metrics['processCpu'] as Map)['reason'], 'notReported');
    },
  );

  test(
    'unknown battery state is preserved without inventing a charge level',
    () async {
      final metrics = await readMetrics({
        ...nativeMetrics(),
        'battery': {
          'status': 'unavailable',
          'available': false,
          'reason': 'batteryStateUnknown',
          'state': 'unknown',
          'level': -1,
          'monitoringEnabled': true,
        },
      });
      final battery = metrics['battery'] as Map;
      expect(battery['reason'], 'batteryStateUnknown');
      expect(battery['state'], 'unknown');
      expect(battery['monitoringEnabled'], isTrue);
      expect(battery.containsKey('level'), isFalse);
      expect((metrics['processCpu'] as Map)['status'], 'available');
    },
  );

  test(
    'malformed metrics container is isolated and failure details are sanitized',
    () async {
      final malformed = await readMetrics('bad container');
      for (final metric in malformed.values.cast<Map>()) {
        expect(metric['reason'], 'invalidResponse');
      }
      final metrics = await readMetrics({
        'memory': {
          'status': 'unavailable',
          'available': false,
          'reason': 'unknown native reason with private detail',
          'source': 'arbitrary',
          'details': 'private detail',
        },
      });
      expect((metrics['memory'] as Map)['reason'], 'nativeUnavailable');
      expect(jsonEncode(metrics), isNot(contains('private detail')));
    },
  );
}
