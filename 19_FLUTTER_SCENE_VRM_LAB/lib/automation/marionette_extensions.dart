import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import '../tracking/face_tracking_signal.dart';
import 'automation_state.dart';

void registerVrmLabMarionetteExtensions() {
  if (!kDebugMode || kIsWeb) return;

  registerMarionetteExtension(
    name: 'madogiwa.inspectVrm',
    description:
        'Inspect the loaded VRM, expressions, tracking source, normalized '
        'face frame, and camera detector state.',
    callback: (_) async {
      final lab = VrmLabAutomationState.controller;
      if (lab == null || !lab.ready) {
        return MarionetteExtensionResult.error(1, 'VRM lab is not ready.');
      }
      final document = lab.document;
      final frame = lab.trackingFrame;
      const toDegrees = 180 / math.pi;
      return MarionetteExtensionResult.success({
        'model': {
          'name': document.meta.name,
          'version': document.meta.version,
          'authors': document.meta.authors,
          'humanoidBones': document.humanoidBones.keys.toList(),
          'expressions': document.expressions.keys.toList(),
          'hasMToon': document.hasMToon,
          'hasSpringBone': document.hasSpringBone,
          'hasNodeConstraint': document.hasNodeConstraint,
        },
        'tracking': {
          'enabled': lab.trackingEnabled,
          'source': lab.trackingSource,
          'yawDegrees': frame.yawRadians * toDegrees,
          'pitchDegrees': frame.pitchRadians * toDegrees,
          'rollDegrees': frame.rollRadians * toDegrees,
          'blinkLeft': frame.blinkLeft,
          'blinkRight': frame.blinkRight,
          'mouthOpen': frame.mouthOpen,
          'confidence': frame.confidence,
        },
        'camera': {
          'state': lab.faceCamera.state.name,
          'detectorFps': lab.faceCamera.detectorFps,
          'processedFrames': lab.faceCamera.processedFrames,
          'droppedFrames': lab.faceCamera.droppedFrames,
          'error': lab.faceCamera.errorMessage,
        },
        'expressions': lab.avatar!.expressionWeights,
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.setFaceTracking',
    description:
        'Start or stop face tracking. Required enabled=true/false. '
        'Optional source=auto/simulation.',
    callback: (params) async {
      final lab = VrmLabAutomationState.controller;
      final enabled = _parseBool(params['enabled']);
      final source = params['source'] ?? 'auto';
      if (lab == null || !lab.ready || enabled == null) {
        return MarionetteExtensionResult.invalidParams(
          'VRM lab must be ready and enabled=true/false is required.',
        );
      }
      if (source != 'auto' && source != 'simulation') {
        return MarionetteExtensionResult.invalidParams(
          'source must be auto or simulation.',
        );
      }
      if (enabled) {
        await lab.startTracking(forceSimulation: source == 'simulation');
      } else {
        await lab.stopTracking();
      }
      return MarionetteExtensionResult.success({
        'enabled': lab.trackingEnabled,
        'source': lab.trackingSource,
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.injectFace',
    description:
        'Inject one deterministic normalized face frame through the same VRM '
        'driver. Optional yaw/pitch/roll degrees, leftEyeOpen/rightEyeOpen, '
        'mouthOpen, and confidence.',
    callback: (params) async {
      final lab = VrmLabAutomationState.controller;
      if (lab == null || !lab.ready) {
        return MarionetteExtensionResult.error(1, 'VRM lab is not ready.');
      }
      final parsed = _faceSignal(params);
      if (parsed == null) {
        return MarionetteExtensionResult.invalidParams(
          'Every supplied face value must be numeric.',
        );
      }
      await lab.injectAutomationFace(parsed);
      final frame = lab.trackingFrame;
      return MarionetteExtensionResult.success({
        'source': lab.trackingSource,
        'yawRadians': frame.yawRadians,
        'pitchRadians': frame.pitchRadians,
        'rollRadians': frame.rollRadians,
        'blinkLeft': frame.blinkLeft,
        'blinkRight': frame.blinkRight,
        'mouthOpen': frame.mouthOpen,
        'confidence': frame.confidence,
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.calibrateFace',
    description: 'Treat the latest detector pose as the neutral head pose.',
    callback: (_) async {
      final lab = VrmLabAutomationState.controller;
      if (lab == null || !lab.ready) {
        return MarionetteExtensionResult.error(1, 'VRM lab is not ready.');
      }
      lab.calibrateTracking();
      return MarionetteExtensionResult.success({'status': 'calibrated'});
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.setVrmExpression',
    description:
        'Set an expression. Use name=neutral/happy/angry/sad or aa and '
        'optional weight=0..1.',
    callback: (params) async {
      final lab = VrmLabAutomationState.controller;
      final name = params['name'];
      final weight = double.tryParse(params['weight'] ?? '1');
      if (lab == null ||
          !lab.ready ||
          name == null ||
          weight == null ||
          !lab.document.expressions.containsKey(name)) {
        return MarionetteExtensionResult.invalidParams(
          'A known expression name and numeric weight are required.',
        );
      }
      lab.setExpressionWeight(name, weight);
      return MarionetteExtensionResult.success({
        'name': name,
        'weight': lab.avatar!.expressionWeights[name],
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.resetVrm',
    description: 'Stop tracking and restore neutral head and face values.',
    callback: (_) async {
      final lab = VrmLabAutomationState.controller;
      if (lab == null || !lab.ready) {
        return MarionetteExtensionResult.error(1, 'VRM lab is not ready.');
      }
      await lab.stopTracking();
      lab.resetAvatar();
      return MarionetteExtensionResult.success({'status': 'reset'});
    },
  );
}

bool? _parseBool(String? value) => switch (value?.toLowerCase()) {
  'true' || '1' || 'on' => true,
  'false' || '0' || 'off' => false,
  _ => null,
};

FaceTrackingSignal? _faceSignal(Map<String, String> params) {
  double? value(String key, double fallback) {
    final raw = params[key];
    return raw == null ? fallback : double.tryParse(raw);
  }

  final yaw = value('yaw', 0);
  final pitch = value('pitch', 0);
  final roll = value('roll', 0);
  final leftEye = value('leftEyeOpen', 1);
  final rightEye = value('rightEyeOpen', 1);
  final mouth = value('mouthOpen', 0);
  final confidence = value('confidence', 1);
  if ([yaw, pitch, roll, leftEye, rightEye, mouth, confidence].contains(null)) {
    return null;
  }
  return FaceTrackingSignal(
    yawDegrees: yaw!,
    pitchDegrees: pitch!,
    rollDegrees: roll!,
    leftEyeOpen: leftEye!,
    rightEyeOpen: rightEye!,
    mouthOpen: mouth!,
    confidence: confidence!,
  );
}
