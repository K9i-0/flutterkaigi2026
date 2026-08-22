import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'face_tracking_signal.dart';

enum FaceCameraState { idle, starting, running, noFace, unsupported, error }

@immutable
class FaceCameraDevice {
  const FaceCameraDevice({
    required this.id,
    required this.name,
    this.isExternal = false,
  });

  final String id;
  final String name;
  final bool isExternal;
}

@immutable
class FaceCameraOverlay {
  const FaceCameraOverlay({
    required this.faceBounds,
    required this.landmarks,
    this.bodyJoints = const {},
  });

  final Rect? faceBounds;
  final Map<String, List<Offset>> landmarks;
  final Map<String, Offset> bodyJoints;
}

abstract class FaceCameraTracker extends ChangeNotifier {
  FaceCameraTracker({required this.onSignal});

  final ValueChanged<FaceTrackingSignal> onSignal;

  bool get isSupportedPlatform;
  FaceCameraState get state;
  String? get errorMessage;
  double get detectorFps;
  int get processedFrames;
  int get droppedFrames;
  CameraController? get cameraController => null;
  Uint8List? get previewJpeg => null;
  FaceCameraOverlay? get faceOverlay => null;
  bool get previewEnabled => false;
  bool get previewMirrored => false;
  List<FaceCameraDevice> get availableDevices => const [];
  String? get selectedDeviceId => null;
  String? get selectedDeviceName => null;

  Future<void> start();
  Future<void> stop();
  Future<void> refreshDevices() async {}
  Future<void> selectDevice(String deviceId) async {}
  Future<void> setPreviewEnabled(bool enabled) async {}
}
