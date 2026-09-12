import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// On-demand OS state for a physical iOS device. A thermal category is not a
/// temperature reading. CPU seconds are cumulative process-wide work, not a
/// system/GPU utilization percentage. Reads enable local battery observation;
/// this never polls or changes power mode, permissions or graphics settings.
abstract final class HazardDeviceDiagnostics {
  static const channelName = 'com.madogiwa.hazard/deviceDiagnostics';
  static const _channel = MethodChannel(channelName);
  static const _thermalStates = {'nominal', 'fair', 'serious', 'critical'};
  static const _batteryStates = {'unknown', 'unplugged', 'charging', 'full'};
  static const _metricSources = {
    'processCpu': 'getrusage(RUSAGE_SELF)',
    'activeProcessorCount': 'ProcessInfo.activeProcessorCount',
    'memory': 'task_info(TASK_VM_INFO).phys_footprint',
    'battery': 'UIDevice',
    'screenBrightness': 'UIWindowScene.screen.brightness',
  };
  static const _metricReasons = {
    'getrusageFailed',
    'taskInfoFailed',
    'taskInfoVersionUnavailable',
    'invalidMetric',
    'batteryStateUnknown',
    'batteryLevelUnknown',
    'noForegroundScreen',
    'invalidScreenBrightness',
  };

  static Future<Map<String, Object?>> readThermalState({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return _unavailable('unsupportedPlatform');
    }
    try {
      final response = await _channel
          .invokeMethod<Object?>('getThermalState')
          .timeout(timeout);
      if (response is! Map) return _unavailable('invalidResponse');
      if (response['isSimulator'] == true) return _unavailable('simulator');
      if (response['isIOSAppOnMac'] == true) return _unavailable('iosAppOnMac');

      final thermalState = response['thermalState'];
      final lowPower = response['isLowPowerModeEnabled'];
      final uptime = response['systemUptime'];
      if (response['isSimulator'] != false ||
          response['isIOSAppOnMac'] != false ||
          !_thermalStates.contains(thermalState) ||
          lowPower is! bool ||
          uptime is! num ||
          !uptime.isFinite ||
          uptime < 0) {
        return _unavailable('invalidResponse');
      }
      return {
        'status': 'available',
        'available': true,
        'platform': 'ios',
        'environment': 'physicalDevice',
        'source': 'ProcessInfo',
        'thermalState': thermalState as String,
        'isLowPowerModeEnabled': lowPower,
        'systemUptime': uptime.toDouble(),
        'metrics': _readMetrics(response['metrics']),
      };
    } on TimeoutException {
      return _unavailable('timeout');
    } on MissingPluginException {
      return _unavailable('missingPlugin');
    } on PlatformException {
      return _unavailable('platformError');
    } catch (_) {
      return _unavailable('unexpectedError');
    }
  }

  // Additive metrics are isolated from the original thermal contract. Older
  // native runners continue to work, with explicitly unreported metrics.
  static Map<String, Object?> _readMetrics(Object? raw) => {
    for (final entry in _metricSources.entries)
      entry.key: _readMetric(
        entry.key,
        entry.value,
        raw is Map ? raw[entry.key] : null,
        malformedContainer: raw != null && raw is! Map,
      ),
  };

  static Map<String, Object?> _readMetric(
    String name,
    String source,
    Object? raw, {
    required bool malformedContainer,
  }) {
    Map<String, Object?> unavailable(String reason) => {
      'status': 'unavailable',
      'available': false,
      'source': source,
      'reason': reason,
    };
    if (malformedContainer) return unavailable('invalidResponse');
    if (raw == null) return unavailable('notReported');
    if (raw is! Map) return unavailable('invalidResponse');
    if (raw['status'] == 'unavailable' && raw['available'] == false) {
      return {
        ...unavailable(
          _metricReasons.contains(raw['reason'])
              ? raw['reason'] as String
              : 'nativeUnavailable',
        ),
        // An unknown charge/state is evidence, never a fabricated zero/full.
        if (name == 'battery') ..._batteryFields(raw),
      };
    }
    if (raw['status'] != 'available' || raw['available'] != true) {
      return unavailable('invalidResponse');
    }
    Map<String, Object?>? values;
    switch (name) {
      case 'processCpu':
        final user = _finiteNonnegative(raw['userSeconds']);
        final system = _finiteNonnegative(raw['systemSeconds']);
        final total = _finiteNonnegative(raw['totalSeconds']);
        final sampledAt = _finiteNonnegative(raw['sampleSystemUptimeSeconds']);
        if (user != null &&
            system != null &&
            total != null &&
            sampledAt != null &&
            (total - user - system).abs() <= .000001) {
          values = {
            'scope': 'processAllThreads',
            'usageConvention': 'oneCore100Percent',
            'userSeconds': user,
            'systemSeconds': system,
            'totalSeconds': total,
            'sampleSystemUptimeSeconds': sampledAt,
          };
        }
      case 'activeProcessorCount':
        final count = raw['count'];
        if (count is int && count > 0) values = {'count': count};
      case 'memory':
        final bytes = raw['physicalFootprintBytes'];
        if (bytes is int && bytes >= 0) {
          values = {'physicalFootprintBytes': bytes};
        }
      case 'battery':
        final fields = _batteryFields(raw);
        if (fields['state'] != null &&
            fields['state'] != 'unknown' &&
            fields['level'] != null &&
            fields['monitoringEnabled'] == true) {
          values = fields;
        }
      case 'screenBrightness':
        final value = _fraction(raw['value']);
        if (value != null) values = {'value': value};
    }
    if (values == null) return unavailable('invalidResponse');
    return {
      'status': 'available',
      'available': true,
      'source': source,
      ...values,
    };
  }

  static Map<String, Object?> _batteryFields(Map raw) {
    final level = _fraction(raw['level']);
    return {
      if (_batteryStates.contains(raw['state']))
        'state': raw['state'] as String,
      if (raw['monitoringEnabled'] is bool)
        'monitoringEnabled': raw['monitoringEnabled'] as bool,
      'level': ?level,
    };
  }

  static double? _finiteNonnegative(Object? value) =>
      value is num && value.isFinite && value >= 0 ? value.toDouble() : null;

  static double? _fraction(Object? value) {
    final number = _finiteNonnegative(value);
    return number != null && number <= 1 ? number : null;
  }

  static Map<String, Object?> _unavailable(String reason) => {
    'status': 'unavailable',
    'available': false,
    'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    'reason': reason,
  };
}
