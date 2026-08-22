import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:marionette_flutter/marionette_flutter.dart';

import 'automation/automation_state.dart';
import 'automation/marionette_extensions.dart';
import 'game/island_game_controller.dart';
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
  final Set<_MoveDirection> _touchDirections = {};
  bool _ready = false;
  bool _showIntro = true;
  bool _showVisualSettings = false;
  bool _showCrafting = false;
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
    _gameFocus.dispose();
    _islandScene.dispose();
    _controller.dispose();
    super.dispose();
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

  void _setTouchDirection(_MoveDirection direction, bool active) {
    if (active) {
      _touchDirections.add(direction);
    } else {
      _touchDirections.remove(direction);
    }
    _applyMovementInput();
  }

  void _applyMovementInput() {
    final left =
        _pressedKeys.contains(LogicalKeyboardKey.keyA) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowLeft) ||
        _touchDirections.contains(_MoveDirection.left);
    final right =
        _pressedKeys.contains(LogicalKeyboardKey.keyD) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowRight) ||
        _touchDirections.contains(_MoveDirection.right);
    final forward =
        _pressedKeys.contains(LogicalKeyboardKey.keyW) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowUp) ||
        _touchDirections.contains(_MoveDirection.forward);
    final backward =
        _pressedKeys.contains(LogicalKeyboardKey.keyS) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowDown) ||
        _touchDirections.contains(_MoveDirection.backward);
    _islandScene.setMoveInput(
      right: (right ? 1 : 0) - (left ? 1 : 0),
      forward: (forward ? 1 : 0) - (backward ? 1 : 0),
    );
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
        !_showVisualSettings &&
        _gestureLatest != null) {
      _islandScene.handleTap(_gestureLatest!, viewSize);
    }
    _gestureStart = null;
    _gestureLatest = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_error case final error?) return _ErrorScreen(error: error);
    if (!_ready) return const _LoadingScreen();

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
              child: ListenableBuilder(
                listenable: Listenable.merge([_controller, _islandScene]),
                builder: (context, _) => _IslandHud(
                  controller: _controller,
                  scene: _islandScene,
                  onReset: _reset,
                  onSettings: () => setState(() => _showVisualSettings = true),
                  onCrafting: () => setState(() => _showCrafting = true),
                  onObjective: _islandScene.performNearbyObjective,
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 112, 14, 0),
                  child: IgnorePointer(
                    child: ListenableBuilder(
                      listenable: _islandScene,
                      builder: (context, _) =>
                          _IslandMiniMap(scene: _islandScene),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 0, 68),
                  child: _MovementPad(onChanged: _setTouchDirection),
                ),
              ),
            ),
            if (_showIntro)
              _IntroOverlay(
                onStart: () {
                  setState(() => _showIntro = false);
                  _gameFocus.requestFocus();
                },
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
            if (_showVisualSettings)
              _VisualSettingsOverlay(
                scene: _islandScene,
                onClose: () => setState(() => _showVisualSettings = false),
              ),
          ],
        ),
      ),
    );
  }
}

class _IslandMiniMap extends StatelessWidget {
  const _IslandMiniMap({required this.scene});

  final MadogiwaIslandScene scene;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xe6091d24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x776ff0c0)),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 14)],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                size: const Size.square(146),
                painter: _IslandMapPainter(scene),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IslandMapPainter extends CustomPainter {
  const _IslandMapPainter(this.scene);

  final MadogiwaIslandScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff061216),
    );
    final scale = size.width / IslandWorld.worldSize;
    final sand = Paint()
      ..color = const Color(0xffc8aa6d)
      ..isAntiAlias = false;
    final grass = Paint()
      ..color = const Color(0xff3f8d55)
      ..isAntiAlias = false;
    final quarry = Paint()
      ..color = const Color(0xff687779)
      ..isAntiAlias = false;
    final marsh = Paint()
      ..color = const Color(0xff356a5a)
      ..isAntiAlias = false;
    final summit = Paint()
      ..color = const Color(0xff8a7b69)
      ..isAntiAlias = false;
    final ocean = Paint()
      ..color = const Color(0xff17445c)
      ..isAntiAlias = false;
    for (
      var z = -IslandWorld.worldHalfSize;
      z < IslandWorld.worldHalfSize;
      z++
    ) {
      for (
        var x = -IslandWorld.worldHalfSize;
        x < IslandWorld.worldHalfSize;
        x++
      ) {
        if (!scene.isExplored(x, z)) continue;
        final paint = !IslandWorld.isLand(x, z)
            ? ocean
            : switch (IslandWorld.biomeCode(x, z)) {
                0 => sand,
                1 => grass,
                2 => quarry,
                3 => marsh,
                _ => summit,
              };
        canvas.drawRect(
          Rect.fromLTWH(
            (x + IslandWorld.worldHalfSize) * scale,
            (z + IslandWorld.worldHalfSize) * scale,
            scale + 0.2,
            scale + 0.2,
          ),
          paint,
        );
      }
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
  bool shouldRepaint(covariant _IslandMapPainter oldDelegate) => true;
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

class _VisualSettingsOverlay extends StatelessWidget {
  const _VisualSettingsOverlay({required this.scene, required this.onClose});

  final MadogiwaIslandScene scene;
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
                listenable: scene,
                builder: (context, _) {
                  final options = scene.visualOptions;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 10, 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xffffc26b),
                            ),
                            const SizedBox(width: 9),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ビジュアル・デバッグ',
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '負荷比較用に各機能を個別切り替え',
                                    style: TextStyle(
                                      color: Color(0xff8fb4bc),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              key: const ValueKey('visual_settings_close'),
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
                            _TimeDebugger(scene: scene),
                            const SizedBox(height: 6),
                            _VisualSwitch(
                              option: 'dayNightCycle',
                              label: '昼夜サイクル',
                              description: '実時間10分でゲーム内24時間',
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
                              option: 'shadows',
                              label: '太陽・月の影',
                              description: '3 cascades / 56マス / 1024px',
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
                              description: '近い8本まで暖色Point Light',
                              value: options['torchLights']!,
                              scene: scene,
                            ),
                            _VisualSwitch(
                              option: 'torchParticles',
                              label: '松明の火の粉',
                              description: '各6枚までの加算合成パーティクル',
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
                              description: '14 stepsの限定的なGod Rays',
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
                              description: '低解像度SSRと時間帯別マテリアル',
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

class _IslandHud extends StatelessWidget {
  const _IslandHud({
    required this.controller,
    required this.scene,
    required this.onReset,
    required this.onSettings,
    required this.onCrafting,
    required this.onObjective,
  });

  final IslandGameController controller;
  final MadogiwaIslandScene scene;
  final VoidCallback onReset;
  final VoidCallback onSettings;
  final VoidCallback onCrafting;
  final VoidCallback onObjective;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _TitleCard(controller: controller)),
              const SizedBox(width: 8),
              _ClockChip(scene: scene),
              const SizedBox(width: 6),
              _ResourceChip(
                icon: Icons.forest,
                value: controller.wood,
                color: const Color(0xff9ee078),
              ),
              const SizedBox(width: 6),
              _ResourceChip(
                icon: Icons.landscape,
                value: controller.stone,
                color: const Color(0xffc3d0d2),
              ),
              const SizedBox(width: 6),
              _CameraButton(
                key: const ValueKey('crafting_open'),
                tooltip: 'インベントリとクラフト',
                icon: Icons.inventory_2_rounded,
                onPressed: onCrafting,
              ),
              const SizedBox(width: 5),
              _CameraButton(
                key: const ValueKey('visual_settings'),
                tooltip: 'ビジュアル設定',
                icon: Icons.tune_rounded,
                onPressed: onSettings,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _MessageCard(message: controller.message)),
              if (scene.nearbyLandmark case final landmark?) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const ValueKey('objective_action'),
                  onPressed: onObjective,
                  icon: const Icon(Icons.settings_input_antenna_rounded),
                  label: Text('${landmark.label}を調べる'),
                ),
              ],
              const SizedBox(width: 8),
              _CameraButton(
                key: const ValueKey('camera_left'),
                tooltip: 'カメラを左へ回転',
                icon: Icons.rotate_left,
                onPressed: () =>
                    scene.orbitCamera(deltaYaw: -0.28, deltaPitch: 0),
              ),
              const SizedBox(width: 5),
              _CameraButton(
                key: const ValueKey('camera_right'),
                tooltip: 'カメラを右へ回転',
                icon: Icons.rotate_right,
                onPressed: () =>
                    scene.orbitCamera(deltaYaw: 0.28, deltaPitch: 0),
              ),
            ],
          ),
          const Spacer(),
          _QuestProgress(controller: controller),
          const SizedBox(height: 8),
          _ToolBar(controller: controller, scene: scene),
          const SizedBox(height: 8),
          Text(
            'POS ${scene.playerX},${scene.playerZ} · '
            'CHUNK ${scene.playerChunkX},${scene.playerChunkZ} · '
            '${scene.activeChunkCount}/256 ACTIVE · '
            '${scene.terrainQuadCount} QUADS · '
            '${scene.characterMeshCount} CHARACTER MESHES · '
            '${scene.loadDuration.inMilliseconds}ms',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

enum _MoveDirection { forward, left, right, backward }

class _MovementPad extends StatelessWidget {
  const _MovementPad({required this.onChanged});

  final void Function(_MoveDirection direction, bool active) onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'プレイヤー移動パッド',
      child: SizedBox(
        width: 142,
        height: 142,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: _HoldDirectionButton(
                icon: Icons.keyboard_arrow_up_rounded,
                tooltip: '前進（W）',
                onChanged: (active) =>
                    onChanged(_MoveDirection.forward, active),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _HoldDirectionButton(
                icon: Icons.keyboard_arrow_left_rounded,
                tooltip: '左へ移動（A）',
                onChanged: (active) => onChanged(_MoveDirection.left, active),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _HoldDirectionButton(
                icon: Icons.keyboard_arrow_right_rounded,
                tooltip: '右へ移動（D）',
                onChanged: (active) => onChanged(_MoveDirection.right, active),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _HoldDirectionButton(
                icon: Icons.keyboard_arrow_down_rounded,
                tooltip: '後退（S）',
                onChanged: (active) =>
                    onChanged(_MoveDirection.backward, active),
              ),
            ),
            Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xcc0d2a31),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x6672efbc)),
                ),
                child: const Icon(Icons.explore_rounded, size: 17),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoldDirectionButton extends StatelessWidget {
  const _HoldDirectionButton({
    required this.icon,
    required this.tooltip,
    required this.onChanged,
  });

  final IconData icon;
  final String tooltip;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTapDown: (_) => onChanged(true),
        onTapUp: (_) => onChanged(false),
        onTapCancel: () => onChanged(false),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xe617343a),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0x6672efbc)),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 8),
            ],
          ),
          child: Icon(icon, size: 31),
        ),
      ),
    );
  }
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({required this.controller});

  final IslandGameController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xcc092027),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0x556ff0c0)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '窓際族・無人島クラフト',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            Text(
              '通信 Lv.${controller.signalLevel} · ${controller.chapter.label}',
              style: const TextStyle(
                color: Color(0xff72efbc),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceChip extends StatelessWidget {
  const _ResourceChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xdd091d24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _ClockChip extends StatelessWidget {
  const _ClockChip({required this.scene});

  final MadogiwaIslandScene scene;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xdd091d24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        child: Column(
          children: [
            Icon(
              scene.phaseLabel == '夜'
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              color: const Color(0xffffc36b),
              size: 16,
            ),
            Text(
              scene.clockLabel,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xbb092027),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _CameraButton extends StatelessWidget {
  const _CameraButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(backgroundColor: const Color(0xcc17343a)),
    );
  }
}

class _QuestProgress extends StatelessWidget {
  const _QuestProgress({required this.controller});

  final IslandGameController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xdd091d24),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0x556ff0c0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.chapterObjective,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              '${controller.progressLabel} · 探索半径 ${controller.explorationLimit.round()}マス',
              style: const TextStyle(color: Color(0xff9cb8bd), fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolBar extends StatelessWidget {
  const _ToolBar({required this.controller, required this.scene});

  final IslandGameController controller;
  final MadogiwaIslandScene scene;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xe6091d24),
        borderRadius: BorderRadius.circular(19),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolButton(
              key: const ValueKey('tool_gather'),
              label: '採取',
              icon: Icons.hardware,
              selected: controller.tool == IslandTool.gather,
              onPressed: () => scene.selectTool(IslandTool.gather),
            ),
            _ToolButton(
              key: const ValueKey('tool_floor'),
              label: '床',
              icon: Icons.grid_view_rounded,
              selected: controller.tool == IslandTool.floor,
              onPressed: () => scene.selectTool(IslandTool.floor),
            ),
            _ToolButton(
              key: const ValueKey('tool_wall'),
              label: '壁',
              icon: Icons.view_week_rounded,
              selected: controller.tool == IslandTool.wall,
              onPressed: () => scene.selectTool(IslandTool.wall),
            ),
            _ToolButton(
              key: const ValueKey('tool_roof'),
              label: '屋根',
              icon: Icons.roofing_rounded,
              selected: controller.tool == IslandTool.roof,
              onPressed: () => scene.selectTool(IslandTool.roof),
            ),
            _ToolButton(
              key: const ValueKey('tool_torch'),
              label: '松明',
              icon: Icons.local_fire_department_rounded,
              selected: controller.tool == IslandTool.torch,
              onPressed: () => scene.selectTool(IslandTool.torch),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: selected
              ? const Color(0xff62dda8)
              : const Color(0xff17343a),
          foregroundColor: selected ? const Color(0xff062018) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

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
