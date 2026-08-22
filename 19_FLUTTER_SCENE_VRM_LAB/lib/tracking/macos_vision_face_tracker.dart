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
      onSignal(
        FaceTrackingSignal(
          yawDegrees: _number(values['yawDegrees']),
          pitchDegrees: _number(values['pitchDegrees']),
          rollDegrees: _number(values['rollDegrees']),
          leftEyeOpen: _number(values['leftEyeOpen'], fallback: 1),
          rightEyeOpen: _number(values['rightEyeOpen'], fallback: 1),
          mouthOpen: _number(values['mouthOpen']),
          confidence: _number(values['confidence'], fallback: 1),
        ),
      );
    } else if (type == 'noFace') {
      state = FaceCameraState.noFace;
      _faceOverlay = null;
      _processedFrames = _integer(values['processedFrames']);
      _droppedFrames = _integer(values['droppedFrames']);
      detectorFps = _number(values['fps']);
    } else if (type == 'running') {
      state = FaceCameraState.running;
    } else if (type == 'preview') {
      final bytes = values['imageBytes'];
      if (bytes is Uint8List) _previewJpeg = bytes;
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

  static FaceCameraOverlay? _overlay(Map<Object?, Object?> values) {
    final rawBounds = values['faceBounds'];
    final rawLandmarks = values['landmarks'];
    if (rawBounds is! List || rawBounds.length != 4 || rawLandmarks is! Map) {
      return null;
    }
    final bounds = rawBounds.map(_number).toList(growable: false);
    final landmarks = <String, List<Offset>>{};
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
    return FaceCameraOverlay(
      faceBounds: Rect.fromLTWH(bounds[0], bounds[1], bounds[2], bounds[3]),
      landmarks: Map.unmodifiable(landmarks),
    );
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
