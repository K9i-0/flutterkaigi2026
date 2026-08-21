import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';

import 'game/island_game_controller.dart';
import 'scene/madogiwa_island_scene.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        !_controller.homeComplete &&
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
            if (_controller.homeComplete) _CompleteOverlay(onReset: _reset),
          ],
        ),
      ),
    );
  }
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

class _IslandHud extends StatelessWidget {
  const _IslandHud({
    required this.controller,
    required this.scene,
    required this.onReset,
  });

  final IslandGameController controller;
  final MadogiwaIslandScene scene;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: _TitleCard()),
              const SizedBox(width: 8),
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
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _MessageCard(message: controller.message)),
              const SizedBox(width: 8),
              _CameraButton(
                tooltip: 'カメラを左へ回転',
                icon: Icons.rotate_left,
                onPressed: () =>
                    scene.orbitCamera(deltaYaw: -0.28, deltaPitch: 0),
              ),
              const SizedBox(width: 5),
              _CameraButton(
                tooltip: 'カメラを右へ回転',
                icon: Icons.rotate_right,
                onPressed: () =>
                    scene.orbitCamera(deltaYaw: 0.28, deltaPitch: 0),
              ),
            ],
          ),
          const Spacer(),
          _BuildProgress(controller: controller),
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
  const _TitleCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xcc092027),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0x556ff0c0)),
      ),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '窓際族・無人島クラフト',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            Text(
              'DAY 1 · 生活基盤を確保せよ',
              style: TextStyle(
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

class _BuildProgress extends StatelessWidget {
  const _BuildProgress({required this.controller});

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProgressPart(label: '床', value: '${controller.floorsBuilt}/4'),
            const _ProgressDivider(),
            _ProgressPart(label: '壁', value: '${controller.wallsBuilt}/4'),
            const _ProgressDivider(),
            _ProgressPart(
              label: '屋根',
              value: controller.roofComplete ? '完成' : '未設置',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressPart extends StatelessWidget {
  const _ProgressPart({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '$label ',
        style: const TextStyle(color: Color(0xff9cb8bd), fontSize: 10),
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressDivider extends StatelessWidget {
  const _ProgressDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 10),
    child: Text('›', style: TextStyle(color: Color(0xff59d8aa))),
  );
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
              label: '採取',
              icon: Icons.hardware,
              selected: controller.tool == IslandTool.gather,
              onPressed: () => scene.selectTool(IslandTool.gather),
            ),
            _ToolButton(
              label: '床',
              icon: Icons.grid_view_rounded,
              selected: controller.tool == IslandTool.floor,
              onPressed: () => scene.selectTool(IslandTool.floor),
            ),
            _ToolButton(
              label: '壁',
              icon: Icons.view_week_rounded,
              selected: controller.tool == IslandTool.wall,
              onPressed: () => scene.selectTool(IslandTool.wall),
            ),
            _ToolButton(
              label: '屋根',
              icon: Icons.roofing_rounded,
              selected: controller.tool == IslandTool.roof,
              onPressed: () => scene.selectTool(IslandTool.roof),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
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
                    'そば屋、やめ太郎、ゆめみん、タコさんは\n無人島へ異動になった。\n木と石を集め、まずは4マスの家を建てよう。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xffbad0d3), height: 1.55),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.handyman_rounded),
                    label: const Text('生活基盤をつくる'),
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

class _CompleteOverlay extends StatelessWidget {
  const _CompleteOverlay({required this.onReset});

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
                  const Text('🏠', style: TextStyle(fontSize: 42)),
                  const SizedBox(height: 8),
                  const Text(
                    '生活拠点、完成！',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '「島流しもメリットです！」\n窓際族の無人島生活は、ここから始まる。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xffc0d1d4), height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(onPressed: onReset, child: const Text('島をリセット')),
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
