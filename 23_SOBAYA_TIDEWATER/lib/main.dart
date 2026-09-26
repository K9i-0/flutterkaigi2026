import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:marionette_flutter/marionette_flutter.dart';

import 'island_game.dart';

void main() {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const IslandPage(),
    ),
  );
}

class IslandPage extends StatefulWidget {
  const IslandPage({super.key});
  @override
  State<IslandPage> createState() => _IslandPageState();
}

class _IslandPageState extends State<IslandPage> {
  final game = IslandGame();
  final focus = FocusNode();
  final keys = <LogicalKeyboardKey>{};
  String? error;
  bool active = true;
  AppLifecycleListener? lifecycle;
  @override
  void initState() {
    super.initState();
    lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        active = state == AppLifecycleState.resumed;
        clear();
        if (mounted) setState(() {});
      },
    );
    if (kDebugMode) {
      registerMarionetteExtension(
        name: 'madogiwa.inspectTidewater',
        description: 'Island port readiness, camera and source versions.',
        callback: (_) async =>
            MarionetteExtensionResult.success(game.inspect()),
      );
      registerMarionetteExtension(
        name: 'madogiwa.openTidewater',
        description: 'name= pier | village | overview',
        callback: (p) async {
          final name = p['name'];
          if (!['pier', 'village', 'overview'].contains(name)) {
            return MarionetteExtensionResult.invalidParams(
              'name=pier|village|overview',
            );
          }
          if (!game.ready) {
            return MarionetteExtensionResult.error(1, 'Not ready');
          }
          game.open('$name');
          if (mounted) setState(() {});
          return MarionetteExtensionResult.success(game.inspect());
        },
      );
    }
    game
        .load()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((Object e, StackTrace s) {
          debugPrint('$e\n$s');
          if (mounted) setState(() => error = e.toString());
        });
  }

  void clear() {
    keys.clear();
    game.clearInput();
  }

  void input() {
    double held(LogicalKeyboardKey k) => keys.contains(k) ? 1 : 0;
    game.forward =
        held(LogicalKeyboardKey.keyW) - held(LogicalKeyboardKey.keyS);
    game.strafe = held(LogicalKeyboardKey.keyD) - held(LogicalKeyboardKey.keyA);
    game.vertical =
        held(LogicalKeyboardKey.space) - held(LogicalKeyboardKey.keyC);
    game.sprint =
        keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
  }

  KeyEventResult key(FocusNode _, KeyEvent e) {
    final movement = {
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.keyC,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
    };
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.keyF) {
      setState(() => game.flying = !game.flying);
      clear();
      return KeyEventResult.handled;
    }
    if (!movement.contains(e.logicalKey)) return KeyEventResult.ignored;
    if (e is KeyUpEvent) {
      keys.remove(e.logicalKey);
    } else {
      keys.add(e.logicalKey);
    }
    input();
    return KeyEventResult.handled;
  }

  Widget move(String label, double forward, double strafe) {
    return Listener(
      onPointerDown: (_) {
        clear();
        game.forward = forward;
        game.strafe = strafe;
      },
      onPointerUp: (_) => clear(),
      onPointerCancel: (_) => clear(),
      child: Container(
        width: 48,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(fontSize: 24)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Focus(
      focusNode: focus,
      autofocus: true,
      onKeyEvent: key,
      onFocusChange: (has) {
        if (!has) clear();
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: error != null
                ? Center(child: SelectableText(error!))
                : !game.ready
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('島を読み込んでいます…'),
                      ],
                    ),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => focus.requestFocus(),
                    onPanStart: (_) => focus.requestFocus(),
                    onPanUpdate: (d) => game.look(d.delta.dx, d.delta.dy),
                    child: TickerMode(
                      enabled: active,
                      child: RepaintBoundary(
                        child: SceneView(
                          game.scene,
                          camera: game.camera,
                          onTick: game.tick,
                        ),
                      ),
                    ),
                  ),
          ),
          if (game.ready) ...[
            const Center(
              child: Text(
                '·',
                style: TextStyle(fontSize: 30, color: Colors.white70),
              ),
            ),
            Positioned(
              top: 20,
              left: 24,
              right: 24,
              child: SafeArea(
                child: Row(
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'そば屋ハザード',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(blurRadius: 8)],
                          ),
                        ),
                        Text(
                          'TIDEWATER · 島の移植プレビュー',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const Spacer(),
                    for (final item in [
                      ('pier', '桟橋'),
                      ('village', '村'),
                      ('overview', '島を見渡す'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: FilledButton.tonal(
                          onPressed: () {
                            clear();
                            game.open(item.$1);
                            focus.requestFocus();
                            setState(() {});
                          },
                          child: Text(item.$2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 24,
              child: SafeArea(
                child: Column(
                  children: [
                    move('↑', 1, 0),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        move('←', 0, -1),
                        const SizedBox(width: 5),
                        move('↓', -1, 0),
                        const SizedBox(width: 5),
                        move('→', 0, 1),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              right: 24,
              child: SafeArea(
                child: Text(
                  game.flying
                      ? '飛行中 · WASD / Space 上昇 / C 下降 / F 歩行へ\nドラッグで見回す・Shiftで加速'
                      : 'WASD / 画面の矢印で移動 · ドラッグで見回す\nShiftで走る · Fで飛行',
                  textAlign: TextAlign.right,
                  style: const TextStyle(shadows: [Shadow(blurRadius: 5)]),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
  @override
  void dispose() {
    lifecycle?.dispose();
    game.dispose();
    focus.dispose();
    super.dispose();
  }
}
