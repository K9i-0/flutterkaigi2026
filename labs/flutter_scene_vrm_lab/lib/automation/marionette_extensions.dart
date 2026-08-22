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
      final body = lab.upperBodyFrame;
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
          'framing': lab.avatarFraming.name,
          'bodyFollowMode': lab.bodyFollowMode.name,
          'bodyFollowIntensity': lab.bodyFollowIntensity,
          'torsoDegrees': {
            for (final entry in lab.trackedTorso.entries)
              entry.key: {
                'yaw': entry.value.yawRadians * toDegrees,
                'pitch': entry.value.pitchRadians * toDegrees,
                'roll': entry.value.rollRadians * toDegrees,
              },
          },
          'yawDegrees': frame.yawRadians * toDegrees,
          'pitchDegrees': frame.pitchRadians * toDegrees,
          'rollDegrees': frame.rollRadians * toDegrees,
          'blinkLeft': frame.blinkLeft,
          'blinkRight': frame.blinkRight,
          'mouthOpen': frame.mouthOpen,
          'confidence': frame.confidence,
          'upperBody': {
            'yawDegrees': body.yawRadians * toDegrees,
            'pitchDegrees': body.pitchRadians * toDegrees,
            'rollDegrees': body.rollRadians * toDegrees,
            'yawConfidence': body.yawConfidence,
            'pitchConfidence': body.pitchConfidence,
            'rollConfidence': body.rollConfidence,
          },
          'arms': {
            'leftShoulderDegrees':
                lab.armFrame.leftShoulderRollRadians * toDegrees,
            'rightShoulderDegrees':
                lab.armFrame.rightShoulderRollRadians * toDegrees,
            'leftElbowDegrees': lab.armFrame.leftElbowRollRadians * toDegrees,
            'rightElbowDegrees': lab.armFrame.rightElbowRollRadians * toDegrees,
            'leftConfidence': lab.armFrame.leftConfidence,
            'rightConfidence': lab.armFrame.rightConfidence,
            'leftElbowConfidence': lab.armFrame.leftElbowConfidence,
            'rightElbowConfidence': lab.armFrame.rightElbowConfidence,
            'appliedDegrees': {
              for (final entry in lab.trackedArms.entries)
                entry.key: entry.value.rollRadians * toDegrees,
            },
          },
        },
        'camera': {
          'state': lab.faceCamera.state.name,
          'selectedDeviceId': lab.faceCamera.selectedDeviceId,
          'selectedDeviceName': lab.faceCamera.selectedDeviceName,
          'devices': [
            for (final device in lab.faceCamera.availableDevices)
              {
                'id': device.id,
                'name': device.name,
                'isExternal': device.isExternal,
              },
          ],
          'detectorFps': lab.faceCamera.detectorFps,
          'processedFrames': lab.faceCamera.processedFrames,
          'droppedFrames': lab.faceCamera.droppedFrames,
          'hasPreviewFrame':
              lab.faceCamera.previewJpeg != null ||
              lab.faceCamera.cameraController?.value.isInitialized == true,
          'previewVisible': lab.faceCamera.previewEnabled,
          'hasFaceOverlay': lab.faceCamera.faceOverlay != null,
          'landmarkRegions':
              lab.faceCamera.faceOverlay?.landmarks.keys.toList() ?? const [],
          'bodyJointNames':
              lab.faceCamera.faceOverlay?.bodyJoints.keys.toList() ?? const [],
          'error': lab.faceCamera.errorMessage,
        },
        'expressions': lab.avatar!.expressionWeights,
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.setCameraPreview',
    description: 'Show or hide the raw camera image. The tracking outlines remain visible.',
    callback: (params) async {
      final lab = VrmLabAutomationState.controller;
      final visible = _parseBool(params['visible']);
      if (lab == null || !lab.ready || visible == null) {
        return MarionetteExtensionResult.invalidParams(
          'VRM lab must be ready and visible=true/false is required.',
        );
      }
      await lab.setCameraPreviewVisible(visible);
      return MarionetteExtensionResult.success({
        'visible': lab.faceCamera.previewEnabled,
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.setBodyFollow',
    description:
        'Set upper body follow. Required mode=headOnly/natural/anime; '
        'optional intensity=0..1.5.',
    callback: (params) async {
      final lab = VrmLabAutomationState.controller;
      final mode = params['mode'];
      final intensity = params['intensity'] == null
          ? null
          : double.tryParse(params['intensity']!);
      if (lab == null ||
          !lab.ready ||
          !const ['headOnly', 'natural', 'anime'].contains(mode) ||
          (params['intensity'] != null && intensity == null) ||
          (intensity != null && (intensity < 0 || intensity > 1.5))) {
        return MarionetteExtensionResult.invalidParams(
          'mode=headOnly/natural/anime and numeric intensity=0..1.5 are required.',
        );
      }
      lab.setBodyFollowModeByName(mode);
      if (intensity != null) lab.setBodyFollowIntensity(intensity);
      return MarionetteExtensionResult.success({
        'mode': lab.bodyFollowMode.name,
        'intensity': lab.bodyFollowIntensity,
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.selectCamera',
    description: 'List cameras or select one by deviceId.',
    callback: (params) async {
      final lab = VrmLabAutomationState.controller;
      if (lab == null || !lab.ready) {
        return MarionetteExtensionResult.error(1, 'VRM lab is not ready.');
      }
      await lab.faceCamera.refreshDevices();
      final deviceId = params['deviceId'];
      if (deviceId != null) {
        if (!lab.faceCamera.availableDevices.any(
          (device) => device.id == deviceId,
        )) {
          return MarionetteExtensionResult.invalidParams(
            'deviceId must identify an available camera.',
          );
        }
        await lab.selectCameraDevice(deviceId);
      }
      return MarionetteExtensionResult.success({
        'selectedDeviceId': lab.faceCamera.selectedDeviceId,
        'selectedDeviceName': lab.faceCamera.selectedDeviceName,
        'devices': [
          for (final device in lab.faceCamera.availableDevices)
            {
              'id': device.id,
              'name': device.name,
              'isExternal': device.isExternal,
            },
        ],
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.setAvatarFraming',
    description: 'Set avatar framing. Required mode=fullBody/bustUp.',
    callback: (params) async {
      final lab = VrmLabAutomationState.controller;
      final mode = params['mode'];
      if (lab == null || !lab.ready || !lab.setAvatarFramingByName(mode)) {
        return MarionetteExtensionResult.invalidParams(
          'VRM lab must be ready and mode=fullBody/bustUp is required.',
        );
      }
      return MarionetteExtensionResult.success({
        'mode': lab.avatarFraming.name,
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
        'mouthOpen, confidence, and bodyYaw/bodyPitch/bodyRoll values.',
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
        'bodyYawRadians': lab.upperBodyFrame.yawRadians,
        'bodyPitchRadians': lab.upperBodyFrame.pitchRadians,
        'bodyRollRadians': lab.upperBodyFrame.rollRadians,
        'leftShoulderRadians': lab.armFrame.leftShoulderRollRadians,
        'rightShoulderRadians': lab.armFrame.rightShoulderRollRadians,
        'leftElbowRadians': lab.armFrame.leftElbowRollRadians,
        'rightElbowRadians': lab.armFrame.rightElbowRollRadians,
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
  final bodyYaw = value('bodyYaw', 0);
  final bodyPitch = value('bodyPitch', 0);
  final bodyRoll = value('bodyRoll', 0);
  final bodyYawConfidence = value('bodyYawConfidence', 0);
  final bodyPitchConfidence = value('bodyPitchConfidence', 0);
  final bodyRollConfidence = value('bodyRollConfidence', 0);
  final leftShoulder = value('leftShoulder', -35);
  final rightShoulder = value('rightShoulder', 35);
  final leftElbow = value('leftElbow', 0);
  final rightElbow = value('rightElbow', 0);
  final leftArmConfidence = value('leftArmConfidence', 0);
  final rightArmConfidence = value('rightArmConfidence', 0);
  final leftElbowConfidence = value('leftElbowConfidence', 0);
  final rightElbowConfidence = value('rightElbowConfidence', 0);
  if ([
    yaw,
    pitch,
    roll,
    leftEye,
    rightEye,
    mouth,
    confidence,
    bodyYaw,
    bodyPitch,
    bodyRoll,
    bodyYawConfidence,
    bodyPitchConfidence,
    bodyRollConfidence,
    leftShoulder,
    rightShoulder,
    leftElbow,
    rightElbow,
    leftArmConfidence,
    rightArmConfidence,
    leftElbowConfidence,
    rightElbowConfidence,
  ].contains(null)) {
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
    bodyYawDegrees: bodyYaw!,
    bodyPitchDegrees: bodyPitch!,
    bodyRollDegrees: bodyRoll!,
    bodyYawConfidence: bodyYawConfidence!,
    bodyPitchConfidence: bodyPitchConfidence!,
    bodyRollConfidence: bodyRollConfidence!,
    leftShoulderDegrees: leftShoulder!,
    rightShoulderDegrees: rightShoulder!,
    leftElbowDegrees: leftElbow!,
    rightElbowDegrees: rightElbow!,
    leftArmConfidence: leftArmConfidence!,
    rightArmConfidence: rightArmConfidence!,
    leftElbowConfidence: leftElbowConfidence!,
    rightElbowConfidence: rightElbowConfidence!,
  );
}
