import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:marionette_flutter/marionette_flutter.dart';

import 'automation/automation_state.dart';
import 'automation/marionette_extensions.dart';
import 'game/island_game_controller.dart';
import 'game/mobile_quality.dart';
import 'scene/madogiwa_island_scene.dart';
import 'world/island_world.dart';

void main() {
  if (kDebugMode && !kIsWeb) {
    MarionetteBinding.ensureInitialized();
    registerIslandMarionetteExtensions();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(const MadogiwaIslandCraftApp());
}

class MadogiwaIslandCraftApp extends StatelessWidget {
  const MadogiwaIslandCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '窓際族・無人島クラフト',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff62d99b),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff07181d),
      ),
      home: const IslandPage(),
    );
  }
}

class IslandPage extends StatefulWidget {
  const IslandPage({super.key});

  @override
  State<IslandPage> createState() => _IslandPageState();
}

class _IslandPageState extends State<IslandPage> {
  late final IslandGameController _controller;
  late final MadogiwaIslandScene _islandScene;
  final FocusNode _gameFocus = FocusNode(debugLabel: 'Island game input');
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  Offset _joystickInput = Offset.zero;
  bool _ready = false;
  bool _showIntro = !const bool.fromEnvironment(
    'MADOGIWA_SKIP_INTRO',
    defaultValue: false,
  );
  bool _showGameMenu = false;
  bool _showCrafting = false;
  bool _showBuildMenu = false;
  bool _miniMapExpanded = false;
  Object? _error;
  Offset? _gestureStart;
  Offset? _gestureLatest;
  double _gestureStartDistance = 14.2;
  bool _gestureMoved = false;

  @override
  void initState() {
    super.initState();
    _controller = IslandGameController();
    _islandScene = MadogiwaIslandScene(controller: _controller);
    SchedulerBinding.instance.addTimingsCallback(_recordFrameTimings);
    IslandAutomationState.attach(controller: _controller, scene: _islandScene);
    _islandScene
        .load()
        .then((_) {
          if (mounted) setState(() => _ready = true);
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (mounted) setState(() => _error = error);
        });
  }

  @override
  void dispose() {
    IslandAutomationState.detach(_islandScene);
    SchedulerBinding.instance.removeTimingsCallback(_recordFrameTimings);
    _gameFocus.dispose();
    _islandScene.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _recordFrameTimings(List<FrameTiming> timings) {
    if (!mounted) return;
    for (final timing in timings) {
      _islandScene.recordFlutterFrame(
        buildTimeMs: timing.buildDuration.inMicroseconds / 1000,
        rasterTimeMs: timing.rasterDuration.inMicroseconds / 1000,
      );
    }
  }

  void _reset() {
    _islandScene.reset();
    setState(() => _showIntro = false);
  }

  void _handleKeyEvent(KeyEvent event) {
    final movementKeys = {
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowRight,
    };
    if (!movementKeys.contains(event.logicalKey)) return;
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _pressedKeys.add(event.logicalKey);
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
    }
    _applyMovementInput();
  }

  void _setJoystickInput(Offset input) {
    _joystickInput = input;
    _applyMovementInput();
  }

  void _applyMovementInput() {
    final left =
        _pressedKeys.contains(LogicalKeyboardKey.keyA) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowLeft);
    final right =
        _pressedKeys.contains(LogicalKeyboardKey.keyD) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowRight);
    final forward =
        _pressedKeys.contains(LogicalKeyboardKey.keyW) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowUp);
    final backward =
        _pressedKeys.contains(LogicalKeyboardKey.keyS) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowDown);
    final keyboardRight = (right ? 1.0 : 0) - (left ? 1.0 : 0);
    final keyboardForward = (forward ? 1.0 : 0) - (backward ? 1.0 : 0);
    _islandScene.setMoveInput(
      right: (keyboardRight + _joystickInput.dx).clamp(-1.0, 1.0),
      forward: (keyboardForward - _joystickInput.dy).clamp(-1.0, 1.0),
    );
  }

  void _performContextAction() {
    _gameFocus.requestFocus();
    final changed = _islandScene.performContextAction();
    if (changed) HapticFeedback.mediumImpact();
  }

  void _selectInteractionMode(IslandTool tool) {
    _gameFocus.requestFocus();
    _islandScene.selectTool(tool);
    setState(() => _showBuildMenu = false);
    HapticFeedback.selectionClick();
  }

  void _placeSelectedBlueprint(BuildBlueprint blueprint) {
    final changed = _islandScene.buildAtSelected(blueprint);
    if (!changed) return;
    HapticFeedback.mediumImpact();
    setState(() => _showBuildMenu = false);
    _gameFocus.requestFocus();
  }

  void _startViewGesture(ScaleStartDetails details) {
    _gameFocus.requestFocus();
    _gestureStart = details.localFocalPoint;
    _gestureLatest = details.localFocalPoint;
    _gestureStartDistance = _islandScene.cameraDistance;
    _gestureMoved = false;
  }

  void _updateViewGesture(ScaleUpdateDetails details) {
    _gestureLatest = details.localFocalPoint;
    if (details.pointerCount >= 2) {
      _gestureMoved = true;
      _islandScene.setCameraDistance(_gestureStartDistance / details.scale);
      return;
    }
    final delta = details.focalPointDelta;
    if (delta.distanceSquared < 0.01) return;
    if ((_gestureStart == null
            ? 0
            : (details.localFocalPoint - _gestureStart!).distanceSquared) >
        36) {
      _gestureMoved = true;
    }
    _islandScene.orbitCamera(
      deltaYaw: -delta.dx * 0.009,
      deltaPitch: delta.dy * 0.006,
    );
  }

  void _endViewGesture(Size viewSize) {
    if (!_gestureMoved &&
        !_showIntro &&
        !_controller.campaignComplete &&
        !_showCrafting &&
        !_showBuildMenu &&
        !_showGameMenu &&
        _gestureLatest != null) {
      final buildTarget = _islandScene.handleTap(_gestureLatest!, viewSize);
      if (buildTarget != null && _controller.tool == IslandTool.build) {
        HapticFeedback.selectionClick();
        setState(() => _showBuildMenu = true);
      }
    }
    _gestureStart = null;
    _gestureLatest = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_error case final error?) return _ErrorScreen(error: error);
    if (!_ready) return const _LoadingScreen();
    final viewSize = MediaQuery.sizeOf(context);
    final portraitLayout = viewSize.width < 600;
    final shortLandscape = viewSize.width >= 600 && viewSize.height < 500;
    final compactControls = portraitLayout || shortLandscape;

    return Scaffold(
      body: KeyboardListener(
        focusNode: _gameFocus,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _OceanBackdrop(),
            LayoutBuilder(
              builder: (context, constraints) {
                final viewSize = constraints.biggest;
                _islandScene.setViewportMetrics(
                  viewSize,
                  MediaQuery.devicePixelRatioOf(context),
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _startViewGesture,
                  onScaleUpdate: _updateViewGesture,
                  onScaleEnd: (_) => _endViewGesture(viewSize),
                  child: SceneView(
                    _islandScene.scene,
                    cameraBuilder: _islandScene.camera,
                    onTick: (_, deltaSeconds) =>
                        _islandScene.tick(deltaSeconds),
                    warmUp: true,
                  ),
                );
              },
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: RepaintBoundary(
                    child: _MinimalHud(
                      onCrafting: () => setState(() => _showCrafting = true),
                      onMenu: () => setState(() => _showGameMenu = true),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, 60, 8, 0),
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      _islandScene.mapRevision,
                      _controller,
                    ]),
                    builder: (context, _) => GestureDetector(
                      key: const ValueKey('mini_map_toggle'),
                      onTap: () =>
                          setState(() => _miniMapExpanded = !_miniMapExpanded),
                      child: _IslandMiniMap(
                        scene: _islandScene,
                        expanded: _miniMapExpanded,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IgnorePointer(
                    child: ListenableBuilder(
                      listenable: Listenable.merge([
                        _islandScene.performanceRevision,
                        _islandScene,
                      ]),
                      builder: (context, _) =>
                          _islandScene.performanceHudEnabled
                          ? _PerformanceHud(scene: _islandScene)
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compactControls ? 10 : 18,
                    0,
                    0,
                    12,
                  ),
                  child: RepaintBoundary(
                    child: _AnalogJoystick(
                      compact: compactControls,
                      onChanged: _setJoystickInput,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    0,
                    compactControls ? 12 : 20,
                    12,
                  ),
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      _controller,
                      _islandScene.hudRevision,
                    ]),
                    builder: (context, _) => RepaintBoundary(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (_controller.tool == IslandTool.build) ...[
                            const _BuildTapHint(),
                            const SizedBox(height: 8),
                          ],
                          _InteractionModeSwitch(
                            mode: _controller.tool == IslandTool.gather
                                ? IslandTool.gather
                                : IslandTool.build,
                            compact: compactControls,
                            onChanged: _selectInteractionMode,
                          ),
                          if (_controller.tool == IslandTool.gather) ...[
                            const SizedBox(height: 9),
                            _ContextActionButton(
                              label: _islandScene.contextActionLabel,
                              compact: compactControls,
                              onPressed: _performContextAction,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_showIntro)
              RepaintBoundary(
                child: _IntroOverlay(
                  onStart: () {
                    setState(() => _showIntro = false);
                    _gameFocus.requestFocus();
                  },
                ),
              ),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                if (_controller.endingAvailable &&
                    !_controller.campaignComplete) {
                  return _EndingDecisionOverlay(
                    onChoose: _islandScene.chooseEnding,
                  );
                }
                if (_controller.campaignComplete) {
                  return _CompleteOverlay(
                    controller: _controller,
                    onReset: _reset,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            if (_showCrafting)
              _CraftingOverlay(
                controller: _controller,
                scene: _islandScene,
                onClose: () {
                  setState(() => _showCrafting = false);
                  _gameFocus.requestFocus();
                },
              ),
            if (_showBuildMenu)
              _BuildMenuOverlay(
                controller: _controller,
                onBuild: _placeSelectedBlueprint,
                onClose: () {
                  setState(() => _showBuildMenu = false);
                  _gameFocus.requestFocus();
                },
              ),
            if (_showGameMenu)
              _GameMenuOverlay(
                controller: _controller,
                scene: _islandScene,
                onOpenInventory: () => setState(() {
                  _showGameMenu = false;
                  _showCrafting = true;
                }),
                onReset: _reset,
                onClose: () {
                  setState(() => _showGameMenu = false);
                  _gameFocus.requestFocus();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _IslandMiniMap extends StatefulWidget {
  const _IslandMiniMap({required this.scene, required this.expanded});

  final MadogiwaIslandScene scene;
  final bool expanded;

  @override
  State<_IslandMiniMap> createState() => _IslandMiniMapState();
}

class _IslandMiniMapState extends State<_IslandMiniMap> {
  ui.Image? _terrainImage;
  int _paintedCells = 0;

  MadogiwaIslandScene get scene => widget.scene;

  void _updateTerrainCache() {
    final historyLength = scene.explorationHistoryLength;
    if (_paintedCells > historyLength) {
      _terrainImage?.dispose();
      _terrainImage = null;
      _paintedCells = 0;
    }
    if (_paintedCells == historyLength) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (_terrainImage case final previous?) {
      canvas.drawImage(previous, Offset.zero, Paint());
    }
    final paint = Paint()..isAntiAlias = false;
    for (var position = _paintedCells; position < historyLength; position++) {
      final index = scene.explorationIndexAt(position);
      final mapX = index % IslandWorld.worldSize;
      final mapZ = index ~/ IslandWorld.worldSize;
      final x = mapX - IslandWorld.worldHalfSize;
      final z = mapZ - IslandWorld.worldHalfSize;
      paint.color = !IslandWorld.isLand(x, z)
          ? const Color(0xff17445c)
          : switch (IslandWorld.biomeCode(x, z)) {
              0 => const Color(0xffc8aa6d),
              1 => const Color(0xff3f8d55),
              2 => const Color(0xff687779),
              3 => const Color(0xff356a5a),
              _ => const Color(0xff8a7b69),
            };
      canvas.drawRect(
        Rect.fromLTWH(mapX.toDouble(), mapZ.toDouble(), 1, 1),
        paint,
      );
    }
    final picture = recorder.endRecording();
    final next = picture.toImageSync(
      IslandWorld.worldSize,
      IslandWorld.worldSize,
    );
    picture.dispose();
    _terrainImage?.dispose();
    _terrainImage = next;
    _paintedCells = historyLength;
  }

  @override
  void dispose() {
    _terrainImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _updateTerrainCache();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xe6091d24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x776ff0c0)),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 14)],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, widget.expanded ? 8 : 7, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.expanded)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.map_rounded,
                    size: 14,
                    color: Color(0xff72efbc),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    '探索マップ',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '通信 ${scene.controller.signalLevel}/4 · 再会 ${scene.reunitedCount}/3',
                    style: const TextStyle(
                      color: Color(0xffffc36b),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            if (widget.expanded) const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.square(widget.expanded ? 146 : 76),
                  painter: _IslandMapPainter(
                    scene,
                    _terrainImage,
                    scene.mapRevision.value,
                    Object.hash(
                      scene.controller.signalLevel,
                      scene.controller.completedLandmarks.length,
                      scene.reunitedCount,
                      scene.signalBoundaryEnabled,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IslandMapPainter extends CustomPainter {
  const _IslandMapPainter(
    this.scene,
    this.terrainImage,
    this.revision,
    this.stateRevision,
  );

  final MadogiwaIslandScene scene;
  final ui.Image? terrainImage;
  final int revision;
  final int stateRevision;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff061216),
    );
    final scale = size.width / IslandWorld.worldSize;
    if (terrainImage case final terrain?) {
      canvas.drawImageRect(
        terrain,
        Rect.fromLTWH(
          0,
          0,
          IslandWorld.worldSize.toDouble(),
          IslandWorld.worldSize.toDouble(),
        ),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.none,
      );
    }

    for (final landmark in MadogiwaIslandScene.landmarks) {
      if (!scene.isExplored(landmark.cell.x, landmark.cell.z)) continue;
      final center = Offset(
        (landmark.cell.x + IslandWorld.worldHalfSize + 0.5) * scale,
        (landmark.cell.z + IslandWorld.worldHalfSize + 0.5) * scale,
      );
      canvas.drawCircle(
        center,
        3.2,
        Paint()
          ..color =
              (landmark.memberId == 'all'
                  ? scene.isLandmarkComplete(landmark.id)
                  : scene.isMemberReunited(landmark.memberId))
              ? const Color(0xff72efbc)
              : const Color(0xffff8b5f),
      );
      canvas.drawCircle(
        center,
        4.6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    final player = Offset(
      (scene.playerX + IslandWorld.worldHalfSize + 0.5) * scale,
      (scene.playerZ + IslandWorld.worldHalfSize + 0.5) * scale,
    );
    if (scene.signalBoundaryEnabled) {
      canvas.drawCircle(
        const Offset(128.5, 128.5) * scale,
        scene.controller.explorationLimit * scale,
        Paint()
          ..color = const Color(0xffff4b45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7,
      );
    }
    canvas.drawCircle(player, 4.5, Paint()..color = const Color(0xffffdf61));
    canvas.drawCircle(
      player,
      5.8,
      Paint()
        ..color = const Color(0xff092027)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _IslandMapPainter oldDelegate) =>
      revision != oldDelegate.revision ||
      stateRevision != oldDelegate.stateRevision ||
      scene.playerX != oldDelegate.scene.playerX ||
      scene.playerZ != oldDelegate.scene.playerZ;
}

class _OceanBackdrop extends StatelessWidget {
  const _OceanBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff8ce3e7), Color(0xff218ab2), Color(0xff08384d)],
        ),
      ),
    );
  }
}

class _GameMenuOverlay extends StatelessWidget {
  const _GameMenuOverlay({
    required this.controller,
    required this.scene,
    required this.onOpenInventory,
    required this.onReset,
    required this.onClose,
  });

  final IslandGameController controller;
  final MadogiwaIslandScene scene;
  final VoidCallback onOpenInventory;
  final VoidCallback onReset;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xaa001015),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 590, maxHeight: 560),
            child: Material(
              color: const Color(0xff09242b),
              elevation: 24,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: ListenableBuilder(
                listenable: Listenable.merge([controller, scene]),
                builder: (context, _) {
                  final options = scene.visualOptions;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 10, 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.menu_rounded,
                              color: Color(0xffffc26b),
                            ),
                            const SizedBox(width: 9),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ゲームメニュー',
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '目標・所持品・進行状況・設定',
                                    style: TextStyle(
                                      color: Color(0xff8fb4bc),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              key: const ValueKey('game_menu_close'),
                              tooltip: '閉じる',
                              onPressed: onClose,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
                          children: [
                            _MenuStatus(
                              controller: controller,
                              scene: scene,
                              onOpenInventory: onOpenInventory,
                            ),
                            const SizedBox(height: 12),
                            const _MenuSectionTitle(
                              icon: Icons.tune_rounded,
                              label: '画質・デバッグ設定',
                            ),
                            const SizedBox(height: 8),
                            _QualitySelector(scene: scene),
                            const SizedBox(height: 8),
                            _TimeDebugger(scene: scene),
                            const SizedBox(height: 6),
                            _VisualSwitch(
                              option: 'dayNightCycle',
                              label: '昼夜サイクル',
                              description: '約12分周期。夕方は16〜21時をゆっくり進行',
                              value: options['dayNightCycle']!,
                              scene: scene,
                            ),
                            _VisualSwitch(
                              option: 'dynamicLighting',
                              label: '時間連動の環境光',
                              description: '空・太陽・月光・露出・色調を連動',
                              value: options['dynamicLighting']!,
                              scene: scene,
                            ),
                            _VisualSwitch(
                              option: 'signalBoundary',
                              label: '探索限界リング',
                              description: '進入可能範囲を示す赤い発光境界',
                              value: options['signalBoundary']!,
                              scene: scene,
                            ),
                            _VisualSwitch(
                              option: 'performanceHud',
                              label: 'パフォーマンスHUD',
                              description: 'FPS・フレーム時間・描画規模を表示',
                              value: options['performanceHud']!,
                              scene: scene,
                            ),
                            _VisualSwitch(
                              option: 'shadows',
                              label: '太陽・月の影',
                              description: scene.shadowProfileLabel,
                              value: options['shadows']!,
                              scene: scene,
                            ),
                            _VisualSwitch(
                              option: 'contactShadows',
                              label: '接地影',
                              description: '足元やボクセル境界の短距離影',
                              value: options['contactShadows']!,
                              scene: scene,
                            ),
                            _VisualSwitch(
                              option: 'torchLights',
                              label: '松明ライト',
                              description: scene.torchProfileLabel,
                              value: options['torchLights']!,
                              scene: scene,
                            ),
                            _VisualSwitch(
                              option: 'torchParticles',
                              label: '松明の火の粉',
                              description: scene.particleProfileLabel,
                              value: options['torchParticles']!,
                              scene: scene,
                            ),
                            _VisualSwitch(
                              option: 'landmarkLights',
                              label: 'ランドマーク固有光',
                              description: '無線塔・会議室・タコ石の門',
                              value: options['landmarkLights']!,
                              scene: scene,
                            ),
                            _VisualSwitch(
                              option: 'godRays',
                              label: '朝夕の光芒',
                              description: scene.godRaysProfileLabel,
                              value: options['godRays']!,
                              scene: scene,
                            ),
                            _VisualSwitch(
                              option: 'dynamicFog',
                              label: '時間連動fog',
                              description: '色・密度・太陽散乱を変化',
                              value: options['dynamicFog']!,
                              scene: scene,
                            ),
                            _VisualSwitch(
                              option: 'waterEffects',
                              label: '海面反射・微動',
                              description: scene.reflectionsProfileLabel,
                              value: options['waterEffects']!,
                              scene: scene,
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              key: const ValueKey('visual_settings_reset'),
                              onPressed: scene.resetVisualSettings,
                              icon: const Icon(Icons.restart_alt_rounded),
                              label: const Text('ビジュアル設定を初期化'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              key: const ValueKey('game_reset'),
                              onPressed: onReset,
                              icon: const Icon(Icons.replay_rounded),
                              label: const Text('ゲームを最初からやり直す'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuStatus extends StatelessWidget {
  const _MenuStatus({
    required this.controller,
    required this.scene,
    required this.onOpenInventory,
  });

  final IslandGameController controller;
  final MadogiwaIslandScene scene;
  final VoidCallback onOpenInventory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _MenuSectionTitle(icon: Icons.flag_rounded, label: '現在の目標'),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xff102f37),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x5572efbc)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.chapterObjective,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${controller.progressLabel} · 探索半径 '
                  '${controller.explorationLimit.round()}マス',
                  style: const TextStyle(
                    color: Color(0xff72efbc),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  controller.message,
                  style: const TextStyle(
                    color: Color(0xffb8cdd1),
                    fontSize: 11,
                  ),
                ),
                if (scene.nearbyLandmark case final landmark?) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    key: const ValueKey('objective_action'),
                    onPressed: scene.performNearbyObjective,
                    icon: const Icon(Icons.settings_input_antenna_rounded),
                    label: Text('${landmark.label}を調べる'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _MenuSectionTitle(
          icon: Icons.inventory_2_rounded,
          label: '資材・インベントリ',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final item in IslandItem.values)
              Chip(
                avatar: Icon(_menuItemIcon(item), size: 16),
                label: Text(
                  '${item.label} ${controller.itemCount(item)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          key: const ValueKey('menu_inventory_open'),
          onPressed: onOpenInventory,
          icon: const Icon(Icons.handyman_rounded),
          label: const Text('インベントリ・クラフトを開く'),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xff102f37),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Text(
              '${scene.framesPerSecond.toStringAsFixed(0)} FPS · '
              'AVG ${scene.averageFrameTimeMs.toStringAsFixed(1)} ms · '
              'P95 ${scene.p95FrameTimeMs.toStringAsFixed(1)} ms · '
              '${scene.activeChunkCount}/256 chunks · '
              '${scene.graphicsQualityLabel} ${scene.renderScale.toStringAsFixed(2)}x',
              style: const TextStyle(
                color: Color(0xff9cb8bd),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static IconData _menuItemIcon(IslandItem item) => switch (item) {
    IslandItem.wood => Icons.forest_rounded,
    IslandItem.stone => Icons.landscape_rounded,
    IslandItem.food => Icons.restaurant_rounded,
    IslandItem.coal => Icons.circle,
    IslandItem.iron => Icons.hexagon_rounded,
    IslandItem.herb => Icons.eco_rounded,
  };
}

class _MenuSectionTitle extends StatelessWidget {
  const _MenuSectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xffffc26b)),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _QualitySelector extends StatelessWidget {
  const _QualitySelector({required this.scene});

  final MadogiwaIslandScene scene;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff102f37),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, size: 18),
                const SizedBox(width: 7),
                const Text(
                  '画質プリセット',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  scene.characterAtNativeResolution
                      ? 'キャラ優先 1.00x'
                      : '実効 ${scene.renderScale.toStringAsFixed(2)}x',
                  style: const TextStyle(
                    color: Color(0xff72efbc),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<GraphicsQuality>(
                key: const ValueKey('graphics_quality'),
                showSelectedIcon: false,
                segments: [
                  for (final quality in GraphicsQuality.values)
                    ButtonSegment(
                      value: quality,
                      label: Text(switch (quality) {
                        GraphicsQuality.auto => '自動',
                        GraphicsQuality.performance => '軽量',
                        GraphicsQuality.balanced => '標準',
                        GraphicsQuality.quality => '高画質',
                      }),
                    ),
                ],
                selected: {scene.graphicsQuality},
                onSelectionChanged: (selection) {
                  scene.setGraphicsQuality(selection.single);
                  HapticFeedback.selectionClick();
                },
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '現在: ${scene.adaptiveDetailLabel}\n'
              '${scene.resourceLodLabel}\n'
              'Autoは遠景LOD・影・エフェクトを先に節約し、解像度は最後に調整します。',
              style: const TextStyle(color: Color(0xff8fb4bc), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeDebugger extends StatelessWidget {
  const _TimeDebugger({required this.scene});

  final MadogiwaIslandScene scene;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff102f37),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 18),
                const SizedBox(width: 7),
                Text(
                  '${scene.phaseLabel} ${scene.clockLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                for (final preset in const [
                  ('朝', 0.27),
                  ('昼', 0.5),
                  ('夕', 0.73),
                  ('夜', 0.88),
                ])
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ActionChip(
                      key: ValueKey('time_${preset.$1}'),
                      label: Text(preset.$1),
                      onPressed: () => scene.setTimeOfDay(preset.$2),
                    ),
                  ),
              ],
            ),
            Slider(
              key: const ValueKey('time_slider'),
              value: scene.timeOfDay,
              onChanged: scene.setTimeOfDay,
            ),
          ],
        ),
      ),
    );
  }
}

class _VisualSwitch extends StatelessWidget {
  const _VisualSwitch({
    required this.option,
    required this.label,
    required this.description,
    required this.value,
    required this.scene,
  });

  final String option;
  final String label;
  final String description;
  final bool value;
  final MadogiwaIslandScene scene;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      key: ValueKey('visual_$option'),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(description, style: const TextStyle(fontSize: 10)),
      value: value,
      onChanged: (enabled) => scene.setVisualOption(option, enabled),
    );
  }
}

class _MinimalHud extends StatelessWidget {
  const _MinimalHud({required this.onCrafting, required this.onMenu});

  final VoidCallback onCrafting;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xcc091d24),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 12)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Wrap(
          alignment: WrapAlignment.center,
          runSpacing: 6,
          children: [
            IconButton(
              key: const ValueKey('crafting_open'),
              tooltip: 'インベントリとクラフト',
              onPressed: onCrafting,
              icon: const Icon(Icons.inventory_2_rounded),
            ),
            IconButton(
              key: const ValueKey('game_menu_open'),
              tooltip: 'ゲームメニュー',
              onPressed: onMenu,
              icon: const Icon(Icons.menu_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceHud extends StatelessWidget {
  const _PerformanceHud({required this.scene});

  final MadogiwaIslandScene scene;

  @override
  Widget build(BuildContext context) {
    final fps = scene.framesPerSecond;
    final fpsColor = fps <= 0
        ? const Color(0xff8ca8ae)
        : fps >= 55
        ? const Color(0xff72efbc)
        : fps >= 30
        ? const Color(0xffffcf67)
        : const Color(0xffff6b61);
    return Container(
      key: const ValueKey('performance_hud'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xe6082027),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fpsColor.withValues(alpha: 0.62)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed_rounded, size: 16, color: fpsColor),
          const SizedBox(width: 6),
          Text(
            '${fps.toStringAsFixed(0)} FPS',
            key: const ValueKey('performance_fps'),
            style: TextStyle(
              color: fpsColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '${scene.averageFrameTimeMs.toStringAsFixed(1)} ms',
            style: const TextStyle(
              color: Color(0xff8fb0b7),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalogJoystick extends StatefulWidget {
  const _AnalogJoystick({required this.compact, required this.onChanged});

  final bool compact;
  final ValueChanged<Offset> onChanged;

  @override
  State<_AnalogJoystick> createState() => _AnalogJoystickState();
}

class _AnalogJoystickState extends State<_AnalogJoystick> {
  double get _size => widget.compact ? 108 : 132;
  double get _travel => widget.compact ? 34 : 42;
  Offset _knob = Offset.zero;

  void _update(Offset localPosition) {
    final raw = localPosition - Offset(_size / 2, _size / 2);
    final distance = raw.distance;
    final clamped = distance > _travel ? raw / distance * _travel : raw;
    final normalized = clamped / _travel;
    setState(() => _knob = clamped);
    widget.onChanged(normalized.distance < 0.08 ? Offset.zero : normalized);
  }

  void _release() {
    if (_knob == Offset.zero) return;
    setState(() => _knob = Offset.zero);
    widget.onChanged(Offset.zero);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'アナログ移動スティック',
      child: GestureDetector(
        key: const ValueKey('analog_joystick'),
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          HapticFeedback.selectionClick();
          _update(details.localPosition);
        },
        onPanUpdate: (details) => _update(details.localPosition),
        onPanEnd: (_) => _release(),
        onPanCancel: _release,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: const Color(0x9911272d),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x8872efbc), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 14),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.control_camera_rounded,
                color: const Color(0x5572efbc),
                size: widget.compact ? 50 : 64,
              ),
              Transform.translate(
                offset: _knob,
                child: Container(
                  width: widget.compact ? 46 : 54,
                  height: widget.compact ? 46 : 54,
                  decoration: BoxDecoration(
                    color: const Color(0xee1b4b52),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xff8affd1),
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.directions_run_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextActionButton extends StatelessWidget {
  const _ContextActionButton({
    required this.label,
    required this.compact,
    required this.onPressed,
  });

  final String label;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (compact)
            FloatingActionButton(
              key: const ValueKey('context_action'),
              heroTag: 'context_action',
              onPressed: onPressed,
              backgroundColor: const Color(0xeeffc561),
              foregroundColor: const Color(0xff152227),
              child: const Icon(Icons.handyman_rounded, size: 26),
            )
          else
            FloatingActionButton.large(
              key: const ValueKey('context_action'),
              heroTag: 'context_action',
              onPressed: onPressed,
              backgroundColor: const Color(0xeeffc561),
              foregroundColor: const Color(0xff152227),
              child: const Icon(Icons.handyman_rounded, size: 32),
            ),
          const SizedBox(height: 5),
          Container(
            constraints: BoxConstraints(maxWidth: compact ? 88 : 120),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xdd082027),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildTapHint extends StatelessWidget {
  const _BuildTapHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('build_tap_hint'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xe60a252b),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xaa72efbc)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded, size: 17, color: Color(0xff72efbc)),
          SizedBox(width: 6),
          Text(
            '地面をタップして建設',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _InteractionModeSwitch extends StatelessWidget {
  const _InteractionModeSwitch({
    required this.mode,
    required this.compact,
    required this.onChanged,
  });

  final IslandTool mode;
  final bool compact;
  final ValueChanged<IslandTool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xee091d24),
      borderRadius: BorderRadius.circular(17),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeButton(
              key: const ValueKey('mode_gather'),
              label: '採取',
              icon: Icons.hardware_rounded,
              compact: compact,
              selected: mode == IslandTool.gather,
              onPressed: () => onChanged(IslandTool.gather),
            ),
            const SizedBox(width: 4),
            _ModeButton(
              key: const ValueKey('mode_build'),
              label: '建設',
              icon: Icons.home_work_rounded,
              compact: compact,
              selected: mode == IslandTool.build,
              onPressed: () => onChanged(IslandTool.build),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.label,
    required this.icon,
    required this.compact,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool compact;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: '$labelモード',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: BoxConstraints(minHeight: compact ? 44 : 50),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 11 : 15,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: selected ? const Color(0xff62dda8) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? const Color(0xff062018) : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xff062018) : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildMenuOverlay extends StatelessWidget {
  const _BuildMenuOverlay({
    required this.controller,
    required this.onBuild,
    required this.onClose,
  });

  final IslandGameController controller;
  final ValueChanged<BuildBlueprint> onBuild;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          key: const ValueKey('build_menu_barrier'),
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          child: const ColoredBox(color: Color(0x66001015)),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 660, maxHeight: 440),
              child: Material(
                key: const ValueKey('build_menu'),
                color: const Color(0xff08242b),
                elevation: 18,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xff17433e),
                              child: Icon(
                                Icons.home_work_rounded,
                                color: Color(0xff72efbc),
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ここに何を作る？',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    controller.selectedCell == null
                                        ? '建設位置を選択してください'
                                        : '選択マス ${controller.selectedCell!.x}, '
                                              '${controller.selectedCell!.z}  ·  '
                                              '木材 ${controller.wood}  石材 ${controller.stone}',
                                    style: const TextStyle(
                                      color: Color(0xff9cb8bd),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              key: const ValueKey('build_menu_close'),
                              tooltip: '閉じる',
                              onPressed: onClose,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth = (constraints.maxWidth - 10) / 2;
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final blueprint in BuildBlueprint.values)
                                  SizedBox(
                                    width: blueprint == BuildBlueprint.house
                                        ? constraints.maxWidth
                                        : cardWidth,
                                    child: _BlueprintCard(
                                      blueprint: blueprint,
                                      controller: controller,
                                      onPressed: () => onBuild(blueprint),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BlueprintCard extends StatelessWidget {
  const _BlueprintCard({
    required this.blueprint,
    required this.controller,
    required this.onPressed,
  });

  final BuildBlueprint blueprint;
  final IslandGameController controller;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cell = controller.selectedCell;
    final failure = cell == null
        ? '位置未選択'
        : controller.buildFailureReason(blueprint, cell);
    final available = failure == null;
    final cost = blueprint.cost.entries
        .map((entry) => '${entry.key.label}${entry.value}')
        .join('・');
    final highlight = blueprint == BuildBlueprint.house;
    return Material(
      key: ValueKey('build_${blueprint.name}'),
      color: highlight ? const Color(0xff16473f) : const Color(0xff10343b),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: available ? onPressed : null,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: available
                    ? const Color(0xff275b4b)
                    : const Color(0xff25383b),
                child: Icon(
                  _blueprintIcon(blueprint),
                  color: available
                      ? const Color(0xff72efbc)
                      : const Color(0xff758b8e),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      blueprint.label,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      available ? '${blueprint.description} · $cost' : failure,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: available
                            ? const Color(0xffb5c9cc)
                            : const Color(0xffffa58a),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              if (available)
                const Icon(Icons.add_circle_rounded, color: Color(0xffffc561)),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _blueprintIcon(BuildBlueprint blueprint) => switch (blueprint) {
  BuildBlueprint.floor => Icons.grid_view_rounded,
  BuildBlueprint.wall => Icons.view_week_rounded,
  BuildBlueprint.roof => Icons.roofing_rounded,
  BuildBlueprint.torch => Icons.local_fire_department_rounded,
  BuildBlueprint.house => Icons.cottage_rounded,
};

class _CraftingOverlay extends StatelessWidget {
  const _CraftingOverlay({
    required this.controller,
    required this.scene,
    required this.onClose,
  });

  final IslandGameController controller;
  final MadogiwaIslandScene scene;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x9900141b),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 690, maxHeight: 560),
          child: Material(
            color: const Color(0xff08242b),
            borderRadius: BorderRadius.circular(26),
            clipBehavior: Clip.antiAlias,
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 12, 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_rounded,
                          color: Color(0xff72efbc),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'インベントリ・クラフト',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '設備と道具が探索範囲を広げる',
                                style: TextStyle(
                                  color: Color(0xff9cb8bd),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('crafting_close'),
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in IslandItem.values)
                          Chip(
                            avatar: Icon(_itemIcon(item), size: 16),
                            label: Text(
                              '${item.label} ${controller.itemCount(item)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (controller.reunitedMembers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: Row(
                        children: [
                          const Text(
                            '仲間配置',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Wrap(
                              spacing: 7,
                              children: [
                                for (final id in controller.reunitedMembers)
                                  ActionChip(
                                    key: ValueKey('companion_$id'),
                                    avatar: Icon(
                                      controller.companionMode(id) ==
                                              CompanionMode.follow
                                          ? Icons.directions_walk_rounded
                                          : Icons.home_work_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      '${_memberName(id)}: '
                                      '${controller.companionMode(id) == CompanionMode.follow ? '同行' : '拠点'}',
                                    ),
                                    onPressed: () =>
                                        controller.toggleCompanionMode(id),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                      itemCount: CraftRecipe.values.length,
                      itemBuilder: (context, index) {
                        final recipe = CraftRecipe.values[index];
                        final owned = controller.hasRecipe(recipe);
                        final canCraft = controller.canCraft(recipe);
                        final cost = recipe.cost.entries
                            .map((entry) => '${entry.key.label}${entry.value}')
                            .join('・');
                        return Card(
                          color: const Color(0xff10343b),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: owned
                                  ? const Color(0xff275b4b)
                                  : const Color(0xff183f47),
                              child: Icon(
                                owned
                                    ? Icons.check_rounded
                                    : _recipeIcon(recipe),
                                color: owned
                                    ? const Color(0xff72efbc)
                                    : Colors.white,
                              ),
                            ),
                            title: Text(
                              recipe.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text('${recipe.description}\n必要: $cost'),
                            isThreeLine: true,
                            trailing: FilledButton(
                              key: ValueKey('craft_${recipe.name}'),
                              onPressed: canCraft
                                  ? () => scene.craftRecipe(recipe)
                                  : null,
                              child: Text(owned ? '作成済み' : '作る'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static IconData _itemIcon(IslandItem item) => switch (item) {
    IslandItem.wood => Icons.forest_rounded,
    IslandItem.stone => Icons.landscape_rounded,
    IslandItem.food => Icons.restaurant_rounded,
    IslandItem.coal => Icons.circle,
    IslandItem.iron => Icons.hexagon_rounded,
    IslandItem.herb => Icons.eco_rounded,
  };

  static IconData _recipeIcon(CraftRecipe recipe) => switch (recipe) {
    CraftRecipe.campfire => Icons.local_fire_department_rounded,
    CraftRecipe.workbench => Icons.carpenter_rounded,
    CraftRecipe.stoneAxe => Icons.hardware_rounded,
    CraftRecipe.stonePickaxe ||
    CraftRecipe.ironPickaxe => Icons.construction_rounded,
    CraftRecipe.bridgeKit => Icons.view_stream_rounded,
    CraftRecipe.forge => Icons.whatshot_rounded,
    CraftRecipe.fogGear => Icons.masks_rounded,
  };

  static String _memberName(String id) => switch (id) {
    'yametaro' => 'やめ太郎',
    'yumemin' => 'ゆめみん',
    'takosan' => 'タコさん',
    _ => id,
  };
}

class _IntroOverlay extends StatelessWidget {
  const _IntroOverlay({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x6600141b),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xf2071b21),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xff67dfa9)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(25, 24, 25, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏝️', style: TextStyle(fontSize: 38)),
                  const SizedBox(height: 8),
                  const Text(
                    '島流し、1日目。',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '無人島へ異動させられた4人は離れ離れ。\n拠点と通信設備をクラフトして圏外の霧を払い、\n3人と再会して山頂の通信機を完成させよう。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xffbad0d3), height: 1.55),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    key: const ValueKey('intro_start'),
                    onPressed: onStart,
                    icon: const Icon(Icons.handyman_rounded),
                    label: const Text('島流し生活を始める'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff62dda8),
                      foregroundColor: const Color(0xff062018),
                      minimumSize: const Size.fromHeight(49),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EndingDecisionOverlay extends StatelessWidget {
  const _EndingDecisionOverlay({required this.onChoose});

  final ValueChanged<EndingChoice> onChoose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xaa00141b),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            color: const Color(0xf2071b21),
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.settings_input_antenna_rounded,
                    size: 48,
                    color: Color(0xff72efbc),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '最終通信機、完成',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '会社へ救助信号を送るか、\nこの島を新しい窓際族エリアにするか。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xffc0d1d4), height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('ending_rescue'),
                          onPressed: () => onChoose(EndingChoice.rescue),
                          icon: const Icon(Icons.directions_boat_rounded),
                          label: const Text('会社へ帰る'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey('ending_stay'),
                          onPressed: () => onChoose(EndingChoice.stay),
                          icon: const Icon(Icons.home_work_rounded),
                          label: const Text('島に残る'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompleteOverlay extends StatelessWidget {
  const _CompleteOverlay({required this.controller, required this.onReset});

  final IslandGameController controller;

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x7700141b),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            color: const Color(0xf2071b21),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: const BorderSide(color: Color(0xffffb65f)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    controller.endingChoice == EndingChoice.stay ? '🏝️' : '🚢',
                    style: const TextStyle(fontSize: 42),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.endingChoice == EndingChoice.stay
                        ? '窓際族自治区、誕生！'
                        : '島流し任務、完了！',
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.endingChoice == EndingChoice.stay
                        ? '救助を丁重に断り、\n島全体を最高の窓際族エリアにした。'
                        : '全員で救助船へ乗り込み、\n無人島で得たクラフト技術を会社へ持ち帰った。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xffc0d1d4), height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    key: const ValueKey('island_reset'),
                    onPressed: onReset,
                    child: const Text('島をリセット'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xff62dda8)),
            SizedBox(height: 20),
            Text(
              '無人島を生成中',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
            SizedBox(height: 6),
            Text(
              '正典ボクセルGLBを4体読み込んでいます',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('3D初期化に失敗しました\n$error', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
