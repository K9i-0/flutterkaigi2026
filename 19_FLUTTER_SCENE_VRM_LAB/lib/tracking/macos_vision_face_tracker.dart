import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'face_camera_tracker.dart';
import 'face_tracking_signal.dart';

class MacOsVisionFaceTracker extends FaceCameraTracker {
  MacOsVisionFaceTracker({required super.onSignal});

  static const _methods = MethodChannel('madogiwa.vrm_lab/macos_face_tracking');
  static const _events = EventChannel(
    'madogiwa.vrm_lab/macos_face_tracking_events',
  );

  StreamSubscription<Object?>? _subscription;
  bool _disposed = false;
  int _processedFrames = 0;
  int _droppedFrames = 0;
  List<FaceCameraDevice> _availableDevices = const [];
  String? _selectedDeviceId;
  Uint8List? _previewJpeg;
  FaceCameraOverlay? _faceOverlay;
  bool _previewEnabled = false;

  @override
  bool get isSupportedPlatform => Platform.isMacOS;
  @override
  FaceCameraState state = FaceCameraState.idle;
  @override
  String? errorMessage;
  @override
  double detectorFps = 0;
  @override
  int get processedFrames => _processedFrames;
  @override
  int get droppedFrames => _droppedFrames;
  @override
  Uint8List? get previewJpeg => _previewJpeg;
  @override
  FaceCameraOverlay? get faceOverlay => _faceOverlay;
  @override
  bool get previewEnabled => _previewEnabled;
  @override
  bool get previewMirrored => true;
  @override
  List<FaceCameraDevice> get availableDevices => _availableDevices;
  @override
  String? get selectedDeviceId => _selectedDeviceId;
  @override
  String? get selectedDeviceName {
    for (final device in _availableDevices) {
      if (device.id == _selectedDeviceId) return device.name;
    }
    return null;
  }

  @override
  Future<void> refreshDevices() async {
    if (!isSupportedPlatform || _disposed) return;
    try {
      final result = await _methods.invokeListMethod<Object?>('listDevices');
      _availableDevices = (result ?? const [])
          .whereType<Map>()
          .map((device) => device.cast<Object?, Object?>())
          .where((device) => device['id'] is String && device['name'] is String)
          .map(
            (device) => FaceCameraDevice(
              id: device['id']! as String,
              name: device['name']! as String,
              isExternal: device['isExternal'] == true,
            ),
          )
          .toList(growable: false);
      if (!_availableDevices.any((device) => device.id == _selectedDeviceId)) {
        final externalDevices = _availableDevices.where(
          (device) => device.isExternal,
        );
        _selectedDeviceId =
            externalDevices.firstOrNull?.id ??
            _availableDevices.firstOrNull?.id;
      }
      notifyListeners();
    } on PlatformException catch (error) {
      errorMessage = error.message ?? error.code;
      notifyListeners();
    }
  }

  @override
  Future<void> selectDevice(String deviceId) async {
    if (_selectedDeviceId == deviceId ||
        !_availableDevices.any((device) => device.id == deviceId)) {
      return;
    }
    final wasRunning =
        state == FaceCameraState.starting ||
        state == FaceCameraState.running ||
        state == FaceCameraState.noFace;
    if (wasRunning) await stop();
    _selectedDeviceId = deviceId;
    errorMessage = null;
    notifyListeners();
    if (wasRunning) await start();
  }

  @override
  Future<void> start() async {
    if (!isSupportedPlatform) {
      state = FaceCameraState.unsupported;
      notifyListeners();
      return;
    }
    if (state == FaceCameraState.starting ||
        state == FaceCameraState.running ||
        state == FaceCameraState.noFace) {
      return;
    }
    state = FaceCameraState.starting;
    errorMessage = null;
    notifyListeners();
    try {
      if (_availableDevices.isEmpty) await refreshDevices();
      await _subscription?.cancel();
      _subscription = _events.receiveBroadcastStream().listen(
        _handleEvent,
        onError: _handleError,
      );
      await _methods.invokeMethod<void>('start', {
        'deviceId': _selectedDeviceId,
      });
      await _methods.invokeMethod<void>('setPreviewEnabled', {
        'enabled': _previewEnabled,
      });
    } on PlatformException catch (error) {
      errorMessage = error.message ?? error.code;
      state = FaceCameraState.error;
      await _subscription?.cancel();
      _subscription = null;
      notifyListeners();
    }
  }

  void _handleEvent(Object? event) {
    if (_disposed || event is! Map) return;
    final values = event.cast<Object?, Object?>();
    final type = values['type'];
    final eventDeviceId = values['deviceId'];
    if (eventDeviceId is String) _selectedDeviceId = eventDeviceId;
    if (type == 'face') {
      state = FaceCameraState.running;
      _faceOverlay = _overlay(values);
      _processedFrames = _integer(values['processedFrames']);
      _droppedFrames = _integer(values['droppedFrames']);
      detectorFps = _number(values['fps']);
      onSignal(_signal(values));
    } else if (type == 'noFace') {
      state = FaceCameraState.noFace;
      _faceOverlay = _overlay(values);
      _processedFrames = _integer(values['processedFrames']);
      _droppedFrames = _integer(values['droppedFrames']);
      detectorFps = _number(values['fps']);
      if (_hasBody(values)) onSignal(_signal(values, hasFace: false));
    } else if (type == 'running') {
      state = FaceCameraState.running;
    } else if (type == 'preview') {
      final bytes = values['imageBytes'];
      if (_previewEnabled && bytes is Uint8List) _previewJpeg = bytes;
    } else if (type == 'error') {
      state = FaceCameraState.error;
      errorMessage = '${values['message'] ?? 'Vision tracking failed.'}';
    }
    notifyListeners();
  }

  void _handleError(Object error) {
    if (_disposed) return;
    errorMessage = '$error';
    state = FaceCameraState.error;
    notifyListeners();
  }

  static double _number(Object? value, {double fallback = 0}) =>
      value is num ? value.toDouble() : fallback;

  static int _integer(Object? value) => value is num ? value.toInt() : 0;

  static bool _hasBody(Map<Object?, Object?> values) =>
      _number(values['bodyYawConfidence']) > 0 ||
      _number(values['bodyPitchConfidence']) > 0 ||
      _number(values['bodyRollConfidence']) > 0;

  static FaceTrackingSignal _signal(
    Map<Object?, Object?> values, {
    bool hasFace = true,
  }) => FaceTrackingSignal(
    yawDegrees: hasFace ? _number(values['yawDegrees']) : 0,
    pitchDegrees: hasFace ? _number(values['pitchDegrees']) : 0,
    rollDegrees: hasFace ? _number(values['rollDegrees']) : 0,
    leftEyeOpen: hasFace ? _number(values['leftEyeOpen'], fallback: 1) : 1,
    rightEyeOpen: hasFace ? _number(values['rightEyeOpen'], fallback: 1) : 1,
    mouthOpen: hasFace ? _number(values['mouthOpen']) : 0,
    confidence: hasFace ? _number(values['confidence'], fallback: 1) : 1,
    bodyYawDegrees: _number(values['bodyYawDegrees']),
    bodyPitchDegrees: _number(values['bodyPitchDegrees']),
    bodyRollDegrees: _number(values['bodyRollDegrees']),
    bodyYawConfidence: _number(values['bodyYawConfidence']),
    bodyPitchConfidence: _number(values['bodyPitchConfidence']),
    bodyRollConfidence: _number(values['bodyRollConfidence']),
    leftShoulderDegrees: _number(values['leftShoulderDegrees'], fallback: -35),
    rightShoulderDegrees: _number(values['rightShoulderDegrees'], fallback: 35),
    leftElbowDegrees: _number(values['leftElbowDegrees']),
    rightElbowDegrees: _number(values['rightElbowDegrees']),
    leftArmConfidence: _number(values['leftArmConfidence']),
    rightArmConfidence: _number(values['rightArmConfidence']),
    leftElbowConfidence: _number(values['leftElbowConfidence']),
    rightElbowConfidence: _number(values['rightElbowConfidence']),
  );

  static FaceCameraOverlay? _overlay(Map<Object?, Object?> values) {
    final rawBounds = values['faceBounds'];
    final rawLandmarks = values['landmarks'];
    Rect? faceBounds;
    if (rawBounds is List && rawBounds.length == 4) {
      final bounds = rawBounds.map(_number).toList(growable: false);
      faceBounds = Rect.fromLTWH(bounds[0], bounds[1], bounds[2], bounds[3]);
    }
    final landmarks = <String, List<Offset>>{};
    if (rawLandmarks is Map) {
      for (final entry in rawLandmarks.entries) {
        if (entry.key is! String || entry.value is! List) continue;
        final points = <Offset>[];
        for (final rawPoint in entry.value! as List) {
          if (rawPoint is List && rawPoint.length == 2) {
            points.add(Offset(_number(rawPoint[0]), _number(rawPoint[1])));
          }
        }
        if (points.isNotEmpty) {
          landmarks[entry.key! as String] = List.unmodifiable(points);
        }
      }
    }
    final bodyJoints = <String, Offset>{};
    final rawBodyJoints = values['bodyJoints'];
    if (rawBodyJoints is Map) {
      for (final entry in rawBodyJoints.entries) {
        final point = entry.value;
        if (entry.key is String && point is List && point.length == 2) {
          bodyJoints[entry.key! as String] = Offset(
            _number(point[0]),
            _number(point[1]),
          );
        }
      }
    }
    if (faceBounds == null && landmarks.isEmpty && bodyJoints.isEmpty) {
      return null;
    }
    return FaceCameraOverlay(
      faceBounds: faceBounds,
      landmarks: Map.unmodifiable(landmarks),
      bodyJoints: Map.unmodifiable(bodyJoints),
    );
  }

  @override
  Future<void> setPreviewEnabled(bool enabled) async {
    _previewEnabled = enabled;
    if (!enabled) _previewJpeg = null;
    if (isSupportedPlatform) {
      try {
        await _methods.invokeMethod<void>('setPreviewEnabled', {
          'enabled': enabled,
        });
      } on PlatformException catch (error) {
        errorMessage = error.message ?? error.code;
      }
    }
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    if (isSupportedPlatform) {
      try {
        await _methods.invokeMethod<void>('stop');
      } on PlatformException catch (error) {
        errorMessage = error.message ?? error.code;
      }
    }
    await _subscription?.cancel();
    _subscription = null;
    _previewJpeg = null;
    _faceOverlay = null;
    state = FaceCameraState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_methods.invokeMethod<void>('stop'));
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
