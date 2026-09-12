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
        expect(result, {
          'status': 'available',
          'available': true,
          'platform': 'ios',
          'environment': 'physicalDevice',
          'source': 'ProcessInfo',
          'thermalState': state,
          'isLowPowerModeEnabled': true,
          'systemUptime': 1234.5,
        });
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
}
