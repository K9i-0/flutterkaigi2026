import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'face_tracking_signal.dart';

enum FaceCameraState { idle, starting, running, noFace, unsupported, error }

class MobileFaceCameraTracker extends ChangeNotifier {
  MobileFaceCameraTracker({required this.onSignal});

  final ValueChanged<FaceTrackingSignal> onSignal;
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableContours: true,
      enableLandmarks: true,
      enableTracking: true,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  CameraController? _controller;
  CameraDescription? _camera;
  bool _busy = false;
  bool _disposed = false;
  int _processedFrames = 0;
  int _droppedFrames = 0;
  final Stopwatch _fpsWatch = Stopwatch();

  FaceCameraState state = FaceCameraState.idle;
  String? errorMessage;
  double detectorFps = 0;

  static bool get isSupportedPlatform => Platform.isAndroid || Platform.isIOS;
  CameraController? get cameraController => _controller;
  int get processedFrames => _processedFrames;
  int get droppedFrames => _droppedFrames;

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
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('利用可能なカメラがありません。');
      _camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        _camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      _controller = controller;
      await controller.initialize();
      await controller.startImageStream(_processCameraImage);
      _fpsWatch
        ..reset()
        ..start();
      state = FaceCameraState.running;
      notifyListeners();
    } catch (error) {
      errorMessage = '$error';
      state = FaceCameraState.error;
      await _disposeCamera();
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _disposeCamera();
    state = FaceCameraState.idle;
    notifyListeners();
  }

  Future<void> _disposeCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();
  }

  void _processCameraImage(CameraImage image) {
    if (_busy || _disposed) {
      _droppedFrames++;
      return;
    }
    final input = _inputImageFromCameraImage(image);
    if (input == null) {
      _droppedFrames++;
      return;
    }
    _busy = true;
    _detect(input);
  }

  Future<void> _detect(InputImage image) async {
    try {
      final faces = await _detector.processImage(image);
      if (_disposed) return;
      _processedFrames++;
      final elapsed = _fpsWatch.elapsedMilliseconds;
      if (elapsed >= 1000) {
        detectorFps = _processedFrames * 1000 / elapsed;
      }
      if (faces.isEmpty) {
        state = FaceCameraState.noFace;
      } else {
        final face = faces.reduce(
          (a, b) =>
              a.boundingBox.size.longestSide >= b.boundingBox.size.longestSide
              ? a
              : b,
        );
        state = FaceCameraState.running;
        onSignal(_signalFromFace(face));
      }
      notifyListeners();
    } catch (error) {
      errorMessage = '$error';
      state = FaceCameraState.error;
      notifyListeners();
    } finally {
      _busy = false;
    }
  }

  FaceTrackingSignal _signalFromFace(Face face) => FaceTrackingSignal(
    yawDegrees: face.headEulerAngleY ?? 0,
    pitchDegrees: face.headEulerAngleX ?? 0,
    rollDegrees: face.headEulerAngleZ ?? 0,
    leftEyeOpen: face.leftEyeOpenProbability ?? 1,
    rightEyeOpen: face.rightEyeOpenProbability ?? 1,
    mouthOpen: _mouthOpen(face),
    confidence: 1,
  );

  double _mouthOpen(Face face) {
    final upper = face.contours[FaceContourType.upperLipBottom]?.points;
    final lower = face.contours[FaceContourType.lowerLipTop]?.points;
    if (upper == null || lower == null || upper.isEmpty || lower.isEmpty) {
      return 0;
    }
    double meanY(List<math.Point<int>> points) =>
        points.fold<double>(0, (sum, point) => sum + point.y) / points.length;
    final ratio = (meanY(lower) - meanY(upper)).abs() / face.boundingBox.height;
    return ((ratio - 0.008) / 0.07).clamp(0.0, 1.0);
  }

  final Map<DeviceOrientation, int> _orientations = const {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = _controller;
    final camera = _camera;
    if (controller == null || camera == null) return null;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    } else {
      var compensation = _orientations[controller.value.deviceOrientation];
      if (compensation == null) return null;
      compensation = camera.lensDirection == CameraLensDirection.front
          ? (camera.sensorOrientation + compensation) % 360
          : (camera.sensorOrientation - compensation + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(compensation);
    }
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null ||
        format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888) ||
        image.planes.length != 1) {
      return null;
    }
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_disposeCamera());
    unawaited(_detector.close());
    super.dispose();
  }
}
