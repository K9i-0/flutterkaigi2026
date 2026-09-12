import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// On-demand OS state for a physical iOS device. A thermal category is not a
/// temperature reading or a performance measurement. This never polls or
/// changes power mode, permissions, frame rate or graphics settings.
abstract final class HazardDeviceDiagnostics {
  static const channelName = 'com.madogiwa.hazard/deviceDiagnostics';
  static const _channel = MethodChannel(channelName);
  static const _thermalStates = {'nominal', 'fair', 'serious', 'critical'};

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

  static Map<String, Object?> _unavailable(String reason) => {
    'status': 'unavailable',
    'available': false,
    'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    'reason': reason,
  };
}
