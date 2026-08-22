import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:flutter_scene_vrm/flutter_scene_vrm.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'automation/automation_state.dart';
import 'automation/marionette_extensions.dart';
import 'tracking/face_camera_tracker.dart';
import 'tracking/face_tracking_signal.dart';
import 'tracking/macos_vision_face_tracker.dart';
import 'tracking/mobile_face_camera_tracker.dart';

enum AvatarFraming { fullBody, bustUp }

void main() {
  if (kDebugMode && !kIsWeb) {
    MarionetteBinding.ensureInitialized();
    registerVrmLabMarionetteExtensions();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(const VrmLabApp());
}

class VrmLabApp extends StatelessWidget {
  const VrmLabApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff59d7c8),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff0b1020),
      useMaterial3: true,
    ),
    home: const VrmLabPage(),
  );
}

class VrmLabPage extends StatefulWidget {
  const VrmLabPage({super.key});

  @override
  State<VrmLabPage> createState() => _VrmLabPageState();
}

class _VrmLabPageState extends State<VrmLabPage> with WidgetsBindingObserver {
  final VrmLabController _lab = VrmLabController();
  Object? _error;

  @override
  void initState() {
    super.initState();
    VrmLabAutomationState.attach(_lab);
    WidgetsBinding.instance.addObserver(this);
    _lab.load().catchError((Object error, StackTrace stackTrace) {
      if (mounted) setState(() => _error = error);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    VrmLabAutomationState.detach(_lab);
    _lab.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_lab.handleLifecycle(state));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AnimatedBuilder(
      animation: _lab,
      builder: (context, _) {
        if (_error case final error?) {
          return Center(child: SelectableText('VRM load failed\n$error'));
        }
        if (!_lab.ready) {
          return const Center(child: CircularProgressIndicator());
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            SceneView(
              _lab.scene,
              cameraBuilder: _lab.camera,
              onTick: (_, delta) => _lab.tick(delta),
              warmUp: true,
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: _ControlPanel(lab: _lab),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: _TrackingPanel(lab: _lab),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 42),
                  child: _CameraTrackingHud(lab: _lab),
                ),
              ),
            ),
            const SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    '2層検証: Flutter UI / flutter_scene_vrm / flutter_scene fork',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class VrmLabController extends ChangeNotifier {
  VrmLabController() {
    faceCamera =
        (Platform.isMacOS
              ? MacOsVisionFaceTracker(onSignal: _onCameraSignal)
              : MobileFaceCameraTracker(onSignal: _onCameraSignal))
          ..addListener(_onFaceCameraChanged);
    unawaited(faceCamera.refreshDevices());
  }

  final Scene scene = Scene();
  final FaceTrackingPipeline trackingPipeline = FaceTrackingPipeline();
  late final FaceCameraTracker faceCamera;
  VrmAvatar? avatar;
  VrmFaceTrackingDriver? _trackingDriver;
  bool ready = false;
  bool autoBlink = true;
  bool trackingEnabled = false;
  bool simulationEnabled = false;
  bool automationEnabled = false;
  AvatarFraming avatarFraming = AvatarFraming.fullBody;
  VrmBodyFollowMode bodyFollowMode = VrmBodyFollowMode.natural;
  double bodyFollowIntensity = 1;
  String emotion = 'neutral';
  double mouth = 0;
  VrmFaceTrackingFrame trackingFrame = const VrmFaceTrackingFrame(
    yawRadians: 0,
    pitchRadians: 0,
    rollRadians: 0,
    blinkLeft: 0,
    blinkRight: 0,
    mouthOpen: 0,
  );
  double _elapsed = 0;
  double _blinkPhase = 0;
  DateTime? _lastCameraSignalAt;
  bool _resumeTracking = false;

  VrmDocument get document => avatar!.document;
  Map<String, VrmTrackedBoneRotation> get trackedTorso =>
      _trackingDriver?.smoothedTorso ?? const {};
  VrmUpperBodyTrackingFrame get upperBodyFrame =>
      trackingPipeline.upperBodyFiltered;
  VrmArmTrackingFrame get armFrame => trackingPipeline.armsFiltered;
  Map<String, VrmTrackedBoneRotation> get trackedArms =>
      _trackingDriver?.smoothedArms ?? const {};
  String get trackingSource {
    if (!trackingEnabled) return 'idle';
    if (automationEnabled) return 'mcp';
    if (simulationEnabled) return 'simulation';
    return 'camera';
  }

  Future<void> load() async {
    await Scene.initializeStaticResources();
    final data = await rootBundle.load('assets/models/validation-avatar.vrm');
    avatar = await VrmAvatar.fromBytes(data.buffer.asUint8List());
    _trackingDriver = VrmFaceTrackingDriver(
      avatar!,
      bodyFollowMode: bodyFollowMode,
      bodyFollowIntensity: bodyFollowIntensity,
    );
    _applyShoulderSafeIdlePose();
    final avatarStage = Node(name: 'AvatarStage')
      ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);
    avatarStage.add(avatar!.root);
    scene.add(avatarStage);
    avatar!.setExpression(emotion, 1);
    ready = true;
    notifyListeners();
  }

  PerspectiveCamera camera(Duration elapsed) {
    final bustUp = avatarFraming == AvatarFraming.bustUp;
    return PerspectiveCamera(
      fovRadiansY: (bustUp ? 30 : 34) * math.pi / 180,
      position: bustUp ? vm.Vector3(0, 1.36, 1.55) : vm.Vector3(0, 1.32, 3.15),
      target: bustUp ? vm.Vector3(0, 1.36, 0) : vm.Vector3(0, 1.12, 0),
      fovNear: 0.05,
      fovFar: 20,
    );
  }

  void setAvatarFraming(AvatarFraming value) {
    avatarFraming = value;
    notifyListeners();
  }

  bool setAvatarFramingByName(String? name) {
    final matches = AvatarFraming.values.where((value) => value.name == name);
    if (matches.isEmpty) return false;
    setAvatarFraming(matches.first);
    return true;
  }

  Future<void> selectCameraDevice(String deviceId) async {
    await faceCamera.selectDevice(deviceId);
    if (trackingEnabled && !simulationEnabled && !automationEnabled) {
      final cameraIsActive =
          faceCamera.state == FaceCameraState.starting ||
          faceCamera.state == FaceCameraState.running ||
          faceCamera.state == FaceCameraState.noFace;
      if (!cameraIsActive) await faceCamera.start();
    }
    notifyListeners();
  }

  Future<void> setCameraPreviewVisible(bool visible) async {
    await faceCamera.setPreviewEnabled(visible);
    notifyListeners();
  }

  void setBodyFollowMode(VrmBodyFollowMode value) {
    bodyFollowMode = value;
    final driver = _trackingDriver;
    if (driver != null) {
      driver.bodyFollowMode = value;
      driver.apply(
        trackingFrame,
        upperBody: upperBodyFrame,
        arms: armFrame,
        smoothBody: false,
      );
    }
    notifyListeners();
  }

  bool setBodyFollowModeByName(String? name) {
    final matches = VrmBodyFollowMode.values.where(
      (value) => value.name == name,
    );
    if (matches.isEmpty) return false;
    setBodyFollowMode(matches.first);
    return true;
  }

  void setBodyFollowIntensity(double value) {
    bodyFollowIntensity = value.clamp(0.0, 1.5);
    final driver = _trackingDriver;
    if (driver != null) {
      driver.bodyFollowIntensity = bodyFollowIntensity;
      driver.apply(
        trackingFrame,
        upperBody: upperBodyFrame,
        arms: armFrame,
        smoothBody: false,
      );
    }
    notifyListeners();
  }

  void _applyShoulderSafeIdlePose() {
    const angle = 35 * math.pi / 180;
    // This validation avatar uses aim/roll helper bones under each shoulder.
    // Rotate the complete shoulder subtree so those helpers stay aligned.
    avatar!.setHumanBoneRotation(
      'leftShoulder',
      vm.Quaternion.euler(0, 0, -angle),
    );
    avatar!.setHumanBoneRotation(
      'rightShoulder',
      vm.Quaternion.euler(0, 0, angle),
    );
  }

  void setEmotion(String value) {
    avatar!.setExpression(emotion, 0);
    emotion = value;
    avatar!.setExpression(value, 1);
    notifyListeners();
  }

  void setMouth(double value) {
    mouth = value;
    avatar!.setExpression('aa', value);
    notifyListeners();
  }

  void setAutoBlink(bool value) {
    autoBlink = value;
    if (!value) avatar!.setExpression('blink', 0);
    notifyListeners();
  }

  Future<void> startTracking({bool forceSimulation = false}) async {
    final cameraIsActive =
        faceCamera.state == FaceCameraState.starting ||
        faceCamera.state == FaceCameraState.running ||
        faceCamera.state == FaceCameraState.noFace;
    final useSimulation = forceSimulation || !faceCamera.isSupportedPlatform;
    if (trackingEnabled &&
        !automationEnabled &&
        simulationEnabled == useSimulation &&
        (useSimulation || cameraIsActive)) {
      return;
    }
    if (trackingEnabled) await faceCamera.stop();
    autoBlink = false;
    if (document.expressions.containsKey('blink')) {
      avatar!.setExpression('blink', 0);
    }
    trackingEnabled = true;
    automationEnabled = false;
    if (faceCamera.isSupportedPlatform && !forceSimulation) {
      simulationEnabled = false;
      await faceCamera.start();
    } else {
      simulationEnabled = true;
    }
    notifyListeners();
  }

  Future<void> stopTracking() async {
    trackingEnabled = false;
    simulationEnabled = false;
    automationEnabled = false;
    await faceCamera.stop();
    _trackingDriver?.reset();
    _applyShoulderSafeIdlePose();
    trackingFrame = const VrmFaceTrackingFrame(
      yawRadians: 0,
      pitchRadians: 0,
      rollRadians: 0,
      blinkLeft: 0,
      blinkRight: 0,
      mouthOpen: 0,
    );
    notifyListeners();
  }

  void calibrateTracking() {
    trackingPipeline.calibrate();
    notifyListeners();
  }

  Future<void> injectAutomationFace(FaceTrackingSignal signal) async {
    if (!automationEnabled) {
      await faceCamera.stop();
      trackingPipeline.reset();
    }
    autoBlink = false;
    trackingEnabled = true;
    simulationEnabled = false;
    automationEnabled = true;
    trackingFrame = trackingPipeline.ingest(
      signal,
      deltaSeconds: 1 / 60,
      smooth: false,
    );
    _trackingDriver?.apply(
      trackingFrame,
      upperBody: upperBodyFrame,
      arms: armFrame,
      smoothBody: false,
    );
    notifyListeners();
  }

  void setExpressionWeight(String name, double weight) {
    avatar!.setExpression(name, weight.clamp(0.0, 1.0));
    notifyListeners();
  }

  void resetAvatar() {
    trackingPipeline.reset();
    _trackingDriver?.reset();
    _applyShoulderSafeIdlePose();
    trackingFrame = trackingPipeline.filtered;
    mouth = 0;
    emotion = 'neutral';
    avatar!.resetExpressions();
    if (document.expressions.containsKey('neutral')) {
      avatar!.setExpression('neutral', 1);
    }
    notifyListeners();
  }

  void _onCameraSignal(FaceTrackingSignal signal) {
    final now = DateTime.now();
    final previous = _lastCameraSignalAt;
    _lastCameraSignalAt = now;
    final delta = previous == null
        ? 1 / 30
        : now.difference(previous).inMicroseconds / 1000000;
    _applyTrackingSignal(signal, delta);
  }

  void _applyTrackingSignal(FaceTrackingSignal signal, double delta) {
    if (!trackingEnabled) return;
    trackingFrame = trackingPipeline.ingest(signal, deltaSeconds: delta);
    _trackingDriver?.apply(
      trackingFrame,
      upperBody: upperBodyFrame,
      arms: armFrame,
      deltaSeconds: delta,
    );
    notifyListeners();
  }

  void _onFaceCameraChanged() {
    if (trackingEnabled) notifyListeners();
  }

  Future<void> handleLifecycle(AppLifecycleState state) async {
    // A desktop VTuber window must keep capturing when another app has focus.
    // Mobile platforms still release the camera while backgrounded.
    if ((!Platform.isIOS && !Platform.isAndroid) ||
        !faceCamera.isSupportedPlatform) {
      return;
    }
    final usingCamera =
        trackingEnabled && !simulationEnabled && !automationEnabled;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _resumeTracking = usingCamera;
      if (usingCamera) await faceCamera.stop();
    } else if (state == AppLifecycleState.resumed && _resumeTracking) {
      _resumeTracking = false;
      await faceCamera.start();
    }
  }

  void tick(double deltaSeconds) {
    _elapsed += deltaSeconds;
    if (simulationEnabled && trackingEnabled) {
      final blinkWave = _elapsed % 3.1 > 2.92
          ? math.sin((_elapsed % 3.1 - 2.92) / 0.18 * math.pi).clamp(0.0, 1.0)
          : 0.0;
      _applyTrackingSignal(
        FaceTrackingSignal(
          yawDegrees: math.sin(_elapsed * 0.72) * 24,
          pitchDegrees: math.sin(_elapsed * 0.47) * 10,
          rollDegrees: math.sin(_elapsed * 0.61) * 8,
          leftEyeOpen: 1 - blinkWave,
          rightEyeOpen: 1 - blinkWave,
          mouthOpen: (math.sin(_elapsed * 2.2) * 0.5 + 0.5) * 0.65,
        ),
        deltaSeconds,
      );
      return;
    }
    if (trackingEnabled &&
        !automationEnabled &&
        faceCamera.state == FaceCameraState.noFace &&
        faceCamera.faceOverlay?.bodyJoints.isEmpty != false) {
      _applyTrackingSignal(
        const FaceTrackingSignal(
          yawDegrees: 0,
          pitchDegrees: 0,
          rollDegrees: 0,
          leftEyeOpen: 1,
          rightEyeOpen: 1,
          mouthOpen: 0,
          confidence: 1,
        ),
        deltaSeconds,
      );
      return;
    }
    if (!autoBlink || avatar == null) return;
    final cycle = _elapsed % 3.2;
    final next = cycle > 2.98
        ? math.sin((cycle - 2.98) / 0.22 * math.pi).clamp(0.0, 1.0)
        : 0.0;
    if ((next - _blinkPhase).abs() > 0.03) {
      _blinkPhase = next;
      avatar!.setExpression('blink', next);
    }
  }

  @override
  void dispose() {
    faceCamera.removeListener(_onFaceCameraChanged);
    faceCamera.dispose();
    super.dispose();
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.lab});

  final VrmLabController lab;

  @override
  Widget build(BuildContext context) {
    final doc = lab.document;
    return Card(
      margin: const EdgeInsets.all(12),
      color: const Color(0xe6192435),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doc.meta.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '公式VRM 1.0検証モデル · ${doc.expressions.length} expressions',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _StatusChip(label: 'Morph', supported: true),
                  _StatusChip(label: 'Humanoid', supported: true),
                  _StatusChip(label: 'MToon fallback', supported: doc.hasMToon),
                  _StatusChip(
                    label: 'SpringBone parsed',
                    supported: doc.hasSpringBone,
                  ),
                  _StatusChip(
                    label: 'Constraint parsed',
                    supported: doc.hasNodeConstraint,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SegmentedButton<AvatarFraming>(
                key: const ValueKey('avatar-framing'),
                segments: const [
                  ButtonSegment(
                    value: AvatarFraming.fullBody,
                    icon: Icon(Icons.accessibility_new),
                    label: Text('全身'),
                  ),
                  ButtonSegment(
                    value: AvatarFraming.bustUp,
                    icon: Icon(Icons.portrait),
                    label: Text('バストアップ'),
                  ),
                ],
                selected: {lab.avatarFraming},
                onSelectionChanged: (values) =>
                    lab.setAvatarFraming(values.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                key: const ValueKey('vrm-emotion'),
                segments: const [
                  ButtonSegment(value: 'neutral', label: Text('Neutral')),
                  ButtonSegment(value: 'happy', label: Text('Happy')),
                  ButtonSegment(value: 'angry', label: Text('Angry')),
                  ButtonSegment(value: 'sad', label: Text('Sad')),
                ],
                selected: {lab.emotion},
                onSelectionChanged: (values) => lab.setEmotion(values.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('口パク AA'),
                  Expanded(
                    child: Slider(
                      key: const ValueKey('vrm-mouth'),
                      value: lab.mouth,
                      onChanged: lab.setMouth,
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                key: const ValueKey('vrm-auto-blink'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('自動まばたき'),
                value: lab.autoBlink,
                onChanged: lab.setAutoBlink,
              ),
              const Divider(),
              const Text(
                '緑: このPoCで動作。MToon / SpringBone / Constraintは検出のみで、描画・物理適用は次段階。',
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingPanel extends StatelessWidget {
  const _TrackingPanel({required this.lab});

  final VrmLabController lab;

  @override
  Widget build(BuildContext context) {
    final frame = lab.trackingFrame;
    final body = lab.upperBodyFrame;
    final arms = lab.armFrame;
    final radiansToDegrees = 180 / math.pi;
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Card(
      margin: const EdgeInsets.all(12),
      color: const Color(0xe6192435),
      child: SizedBox(
        width: compact ? 220 : 285,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.face_retouching_natural, size: 19),
                  const SizedBox(width: 7),
                  Text(
                    'Face → VRM',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  _TrackingDot(active: lab.trackingEnabled),
                ],
              ),
              const SizedBox(height: 8),
              if (lab.faceCamera.availableDevices.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '使用カメラ',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            key: const ValueKey('face-camera-device'),
                            value: lab.faceCamera.selectedDeviceId,
                            isExpanded: true,
                            isDense: true,
                            items: [
                              for (final device
                                  in lab.faceCamera.availableDevices)
                                DropdownMenuItem(
                                  value: device.id,
                                  child: Text(
                                    device.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (deviceId) {
                              if (deviceId != null) {
                                unawaited(lab.selectCameraDevice(deviceId));
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('face-camera-refresh'),
                      tooltip: '接続カメラを再検出',
                      onPressed: () =>
                          unawaited(lab.faceCamera.refreshDevices()),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                '上半身追従',
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
              const SizedBox(height: 4),
              SegmentedButton<VrmBodyFollowMode>(
                key: const ValueKey('body-follow-mode'),
                segments: const [
                  ButtonSegment(
                    value: VrmBodyFollowMode.headOnly,
                    label: Text('頭のみ'),
                  ),
                  ButtonSegment(
                    value: VrmBodyFollowMode.natural,
                    label: Text('自然'),
                  ),
                  ButtonSegment(
                    value: VrmBodyFollowMode.anime,
                    label: Text('アニメ'),
                  ),
                ],
                selected: {lab.bodyFollowMode},
                onSelectionChanged: (values) =>
                    lab.setBodyFollowMode(values.first),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    '強さ ${(lab.bodyFollowIntensity * 100).round()}%',
                    style: const TextStyle(fontSize: 10),
                  ),
                  Expanded(
                    child: Slider(
                      key: const ValueKey('body-follow-intensity'),
                      value: lab.bodyFollowIntensity,
                      min: 0,
                      max: 1.5,
                      onChanged: lab.setBodyFollowIntensity,
                    ),
                  ),
                ],
              ),
              Text(
                'Yaw ${(frame.yawRadians * radiansToDegrees).toStringAsFixed(1)}°  '
                'Pitch ${(frame.pitchRadians * radiansToDegrees).toStringAsFixed(1)}°  '
                'Roll ${(frame.rollRadians * radiansToDegrees).toStringAsFixed(1)}°',
                style: const TextStyle(fontSize: 11),
              ),
              Text(
                'Blink L ${frame.blinkLeft.toStringAsFixed(2)} / '
                'R ${frame.blinkRight.toStringAsFixed(2)}  '
                'Mouth ${frame.mouthOpen.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11),
              ),
              if (body.yawConfidence > 0 ||
                  body.pitchConfidence > 0 ||
                  body.rollConfidence > 0)
                Text(
                  'Body Y ${(body.yawRadians * radiansToDegrees).toStringAsFixed(1)}°  '
                  'P ${(body.pitchRadians * radiansToDegrees).toStringAsFixed(1)}°  '
                  'R ${(body.rollRadians * radiansToDegrees).toStringAsFixed(1)}°',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xffffca68),
                  ),
                ),
              if (arms.leftConfidence > 0 || arms.rightConfidence > 0)
                Text(
                  'Arms L ${(arms.leftConfidence * 100).round()}%  '
                  'R ${(arms.rightConfidence * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xffffca68),
                  ),
                ),
              if (lab.faceCamera.detectorFps > 0)
                Text(
                  'Detector ${lab.faceCamera.detectorFps.toStringAsFixed(1)} fps · '
                  'drop ${lab.faceCamera.droppedFrames}',
                  style: const TextStyle(fontSize: 10, color: Colors.white60),
                ),
              if (lab.faceCamera.errorMessage case final message?)
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.amber),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('face-tracking-toggle'),
                      onPressed: lab.trackingEnabled
                          ? lab.stopTracking
                          : lab.startTracking,
                      icon: Icon(
                        lab.trackingEnabled
                            ? Icons.stop_circle_outlined
                            : Icons.videocam_outlined,
                      ),
                      label: Text(lab.trackingEnabled ? '停止' : '追跡開始'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.outlined(
                    key: const ValueKey('face-tracking-calibrate'),
                    tooltip: '現在の顔向きを正面として補正',
                    onPressed: lab.trackingEnabled
                        ? lab.calibrateTracking
                        : null,
                    icon: const Icon(Icons.center_focus_strong),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraTrackingHud extends StatelessWidget {
  const _CameraTrackingHud({required this.lab});

  final VrmLabController lab;

  @override
  Widget build(BuildContext context) {
    final tracker = lab.faceCamera;
    final camera = tracker.cameraController;
    final bytes = tracker.previewJpeg;
    Widget preview;
    if (tracker.previewEnabled &&
        camera != null &&
        camera.value.isInitialized) {
      preview = CameraPreview(camera);
    } else if (tracker.previewEnabled && bytes != null) {
      preview = Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
      );
    } else {
      preview = DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xff090e18),
          gradient: RadialGradient(
            colors: [Color(0xff142335), Color(0xff070b12)],
            radius: 0.9,
          ),
        ),
      );
    }

    Widget previewStack = Stack(
      fit: StackFit.expand,
      children: [
        preview,
        CustomPaint(
          key: const ValueKey('face-landmark-overlay'),
          painter: _FaceLandmarkPainter(tracker.faceOverlay),
        ),
      ],
    );
    if (tracker.previewMirrored) {
      previewStack = Transform.flip(flipX: true, child: previewStack);
    }

    final overlay = tracker.faceOverlay;
    final hasFace = overlay?.faceBounds != null;
    final hasBody = overlay?.bodyJoints.isNotEmpty == true;
    final lockLabel = hasFace && hasBody
        ? 'FACE + BODY'
        : hasFace
        ? 'FACE LOCK'
        : hasBody
        ? 'BODY LOCK'
        : 'SEARCHING';

    return Card(
      key: const ValueKey('camera-tracking-hud'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: const Color(0xee192435),
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Icon(
                    !hasFace && !hasBody
                        ? Icons.center_focus_weak
                        : Icons.center_focus_strong,
                    size: 17,
                    color: !hasFace && !hasBody
                        ? Colors.white54
                        : const Color(0xff5ee3bd),
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'CAMERA TRACKING',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    lockLabel,
                    style: TextStyle(
                      fontSize: 9,
                      color: !hasFace && !hasBody
                          ? Colors.white54
                          : const Color(0xff5ee3bd),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: const ValueKey('camera-preview-toggle'),
                    tooltip: tracker.previewEnabled ? 'カメラ映像を隠す' : 'カメラ映像を表示',
                    onPressed: () => unawaited(
                      lab.setCameraPreviewVisible(!tracker.previewEnabled),
                    ),
                    icon: Icon(
                      tracker.previewEnabled
                          ? Icons.videocam_outlined
                          : Icons.videocam_off_outlined,
                      size: 17,
                    ),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            AspectRatio(aspectRatio: 4 / 3, child: previewStack),
          ],
        ),
      ),
    );
  }
}

class _FaceLandmarkPainter extends CustomPainter {
  const _FaceLandmarkPainter(this.overlay);

  final FaceCameraOverlay? overlay;

  static const _closedRegions = {
    'leftEye',
    'rightEye',
    'outerLips',
    'innerLips',
  };

  @override
  void paint(Canvas canvas, Size size) {
    final data = overlay;
    if (data == null) return;
    final line = Paint()
      ..color = const Color(0xff63f4d3)
      ..strokeWidth = 1.35
      ..style = PaintingStyle.stroke;
    final normalizedBounds = data.faceBounds;
    Rect? bounds;
    if (normalizedBounds != null) {
      bounds = Rect.fromLTWH(
        normalizedBounds.left * size.width,
        normalizedBounds.top * size.height,
        normalizedBounds.width * size.width,
        normalizedBounds.height * size.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds, const Radius.circular(5)),
        line..color = const Color(0xcc5ee3bd),
      );
    }

    for (final entry in data.landmarks.entries) {
      if (entry.value.length < 2) continue;
      final path = Path();
      for (var index = 0; index < entry.value.length; index++) {
        final point = entry.value[index];
        final x = point.dx * size.width;
        final y = point.dy * size.height;
        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      if (_closedRegions.contains(entry.key)) path.close();
      canvas.drawPath(path, line..color = const Color(0xff63f4d3));
    }

    _paintBody(canvas, size, data.bodyJoints);

    if (bounds != null) {
      final center = bounds.center;
      final reticle = Paint()
        ..color = const Color(0xddffca68)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(center.dx - 7, center.dy),
        Offset(center.dx + 7, center.dy),
        reticle,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - 7),
        Offset(center.dx, center.dy + 7),
        reticle,
      );
    }
  }

  void _paintBody(Canvas canvas, Size size, Map<String, Offset> joints) {
    Offset? point(String name) {
      final value = joints[name];
      return value == null
          ? null
          : Offset(value.dx * size.width, value.dy * size.height);
    }

    final bodyLine = Paint()
      ..color = const Color(0xffffca68)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const connections = [
      ('leftWrist', 'leftElbow'),
      ('leftElbow', 'leftShoulder'),
      ('leftShoulder', 'neck'),
      ('neck', 'rightShoulder'),
      ('rightShoulder', 'rightElbow'),
      ('rightElbow', 'rightWrist'),
      ('leftShoulder', 'leftHip'),
      ('rightShoulder', 'rightHip'),
      ('leftHip', 'rightHip'),
    ];
    for (final connection in connections) {
      final from = point(connection.$1);
      final to = point(connection.$2);
      if (from != null && to != null) canvas.drawLine(from, to, bodyLine);
    }
    for (final joint in joints.values) {
      canvas.drawCircle(
        Offset(joint.dx * size.width, joint.dy * size.height),
        2.7,
        bodyLine,
      );
    }
  }

  @override
  bool shouldRepaint(_FaceLandmarkPainter oldDelegate) =>
      oldDelegate.overlay != overlay;
}

class _TrackingDot extends StatelessWidget {
  const _TrackingDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: active ? const Color(0xff5ee3bd) : Colors.white24,
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.supported});

  final String label;
  final bool supported;

  @override
  Widget build(BuildContext context) => Chip(
    visualDensity: VisualDensity.compact,
    avatar: Icon(
      supported ? Icons.check_circle : Icons.remove_circle_outline,
      size: 16,
      color: supported ? const Color(0xff5ee3bd) : Colors.amber,
    ),
    label: Text(label),
  );
}
