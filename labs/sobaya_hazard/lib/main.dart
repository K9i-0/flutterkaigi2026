import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:madogiwa_engine/madogiwa_engine.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'game.dart';
import 'rendering.dart';

void main() {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'そば屋ハザード',
      theme: ThemeData.dark(useMaterial3: true),
      home: const HazardPage(),
    ),
  );
}

class HazardPage extends StatefulWidget {
  const HazardPage({super.key});
  @override
  State<HazardPage> createState() => _HazardPageState();
}

class _HazardPageState extends State<HazardPage> {
  final renderer = YardRenderer(), focus = FocusNode();
  final keys = <LogicalKeyboardKey>{};
  late HazardGame game;
  late Map<String, dynamic> layout;
  bool ready = false, paused = true, debugFreeze = false;
  String? error;
  double accumulator = 0;
  AppLifecycleListener? lifecycle;
  @override
  void initState() {
    super.initState();
    load();
    lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state != AppLifecycleState.resumed) {
          keys.clear();
          if (ready) {
            game.forward = game.strafe = 0;
          }
          paused = true;
        }
      },
    );
    if (kDebugMode) {
      registerMarionetteExtension(
        name: 'madogiwa.inspectShooter',
        description: 'Inspect the new shooter simulation and loading state.',
        callback: (p) async => MarionetteExtensionResult.success({
          'ready': ready,
          'error': error,
          'paused': paused,
          'debugFreeze': debugFreeze,
          if (ready) ...game.inspect(),
          if (ready) 'renderedLandmarks': renderer.inspect(),
        }),
      );
      registerMarionetteExtension(
        name: 'madogiwa.shooterAction',
        description: 'action=reset|step|fire|interact|reload|pause|resume. step seconds<=20, forward/right -1..1, yaw radians, sneak=true. Deterministic fixed-step simulation then freeze.',
        callback: (p) async {
          if (!ready) return MarionetteExtensionResult.error(1, 'Not ready');
          switch (p['action']) {
            case 'reset':
              game = HazardGame(layout);
              paused = false;
              debugFreeze = true;
            case 'pause':
              paused = true;
            case 'resume':
              paused = false;
              debugFreeze = false;
            case 'fire':
              game.fire();
            case 'interact':
              game.interact();
            case 'reload':
              game.reload();
            case 'step':
              final seconds = double.tryParse(p['seconds'] ?? '0'),
                  yaw = double.tryParse(p['yaw'] ?? '${game.yaw}');
              final forward = double.tryParse(p['forward'] ?? '0'),
                  right = double.tryParse(p['right'] ?? '0');
              if (seconds == null ||
                  yaw == null ||
                  forward == null ||
                  right == null ||
                  ![seconds, yaw, forward, right].every((v) => v.isFinite) ||
                  seconds < 0 ||
                  seconds > 20 ||
                  forward.abs() > 1 ||
                  right.abs() > 1) {
                return MarionetteExtensionResult.invalidParams(
                  'Invalid bounded input',
                );
              }
              paused = false;
              debugFreeze = true;
              game.yaw = yaw;
              game.forward = forward;
              game.strafe = right;
              game.crouching = p['sneak'] == 'true';
              for (var i = 0; i < (seconds * 60).round(); i++) {
                game.tick(1 / 60);
                renderer.update(game, 1 / 60);
              }
              game.forward = game.strafe = 0;
            default:
              return MarionetteExtensionResult.invalidParams('Unknown action');
          }
          renderer.update(game, 0);
          setState(() {});
          return MarionetteExtensionResult.success(game.inspect());
        },
      );
    }
  }

  Future<void> load() async {
    try {
      layout = jsonDecode(await rootBundle.loadString('assets/yard.json'));
      game = HazardGame(layout);
      await renderer.load(game);
      renderer.update(game, 0);
      if (mounted) setState(() => ready = true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  void tick(Duration elapsed, double dt) {
    if (!ready || paused || debugFreeze) return;
    accumulator += dt.clamp(0, .1);
    while (accumulator >= 1 / 60) {
      game.forward =
          (keys.contains(LogicalKeyboardKey.keyW) ? 1 : 0) -
          (keys.contains(LogicalKeyboardKey.keyS) ? 1 : 0).toDouble();
      game.strafe =
          (keys.contains(LogicalKeyboardKey.keyD) ? 1 : 0) -
          (keys.contains(LogicalKeyboardKey.keyA) ? 1 : 0).toDouble();
      if (keys.contains(LogicalKeyboardKey.keyQ)) game.yaw += .025;
      if (keys.contains(LogicalKeyboardKey.keyE)) game.yaw -= .025;
      game.tick(1 / 60);
      renderer.update(game, 1 / 60);
      accumulator -= 1 / 60;
    }
    if (mounted) setState(() {});
  }

  KeyEventResult key(FocusNode node, KeyEvent event) {
    if (!ready) return KeyEventResult.ignored;
    if (event is KeyUpEvent) {
      keys.remove(event.logicalKey);
      return KeyEventResult.handled;
    }
    keys.add(event.logicalKey);
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) game.fire();
      if (event.logicalKey == LogicalKeyboardKey.keyF) game.interact();
      if (event.logicalKey == LogicalKeyboardKey.keyR) game.reload();
      if (event.logicalKey == LogicalKeyboardKey.keyC) {
        game.crouching = !game.crouching;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) paused = !paused;
      if (event.logicalKey == LogicalKeyboardKey.keyN) {
        game = HazardGame(layout);
        paused = false;
        debugFreeze = false;
      }
    }
    setState(() {});
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    focus.dispose();
    lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111a22),
    body: Focus(
      focusNode: focus,
      autofocus: true,
      onKeyEvent: key,
      child: Stack(
        children: [
          if (ready)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  focus.requestFocus();
                  if (!paused) game.fire();
                },
                onPanUpdate: (d) {
                  game.yaw -= d.delta.dx * .008;
                },
                child: SceneView(
                  renderer.scene,
                  camera: renderer.camera,
                  onTick: tick,
                ),
              ),
            ),
          if (!ready) Center(child: Text(error ?? '搬入口を準備中…')),
          if (ready) ...[
            Positioned(
              top: 28,
              left: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'そば屋ハザード',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    '夜間搬入口  /  巡回をかわせ',
                    style: TextStyle(
                      color: Colors.tealAccent,
                      letterSpacing: 2,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(game.unlocked ? '02  搬出口へ脱出' : '01  制御盤を操作して出口を開く'),
                  const SizedBox(height: 8),
                  Text(
                    '体力 ${game.health}    弾 ${game.ammo} / ${game.reserve}    ${game.crouching ? '隠密移動' : '通常移動'}',
                  ),
                ],
              ),
            ),
            Positioned(
              top: 28,
              right: 28,
              child: Container(
                width: 170,
                height: 240,
                color: Colors.black54,
                child: CustomPaint(painter: YardMap(game)),
              ),
            ),
            Center(
              child: Icon(
                Icons.add,
                size: 24,
                color: game.flash > 0 ? Colors.orangeAccent : Colors.white70,
              ),
            ),
            Positioned(
              bottom: 28,
              left: 28,
              right: 28,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xdd14242b),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.message, style: const TextStyle(fontSize: 17)),
                    const SizedBox(height: 8),
                    const Text(
                      'WASD 移動   ドラッグ / Q・E 視点   C 隠密   Space / クリック 射撃   R 装填   F 操作   Esc 停止   N やり直し',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () {
                            game.crouching = !game.crouching;
                          },
                          child: const Text('隠密 C'),
                        ),
                        TextButton(
                          onPressed: game.fire,
                          child: const Text('射撃'),
                        ),
                        TextButton(
                          onPressed: game.interact,
                          child: const Text('操作 F'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (paused || game.ended)
              Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          game.won
                              ? '脱出成功'
                              : game.health <= 0
                              ? '発見・制圧された'
                              : '一時停止',
                          style: const TextStyle(fontSize: 28),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (game.ended) game = HazardGame(layout);
                              paused = false;
                              debugFreeze = false;
                              keys.clear();
                              focus.requestFocus();
                            });
                          },
                          child: Text(game.ended ? 'もう一度' : '再開'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}

class YardMap extends CustomPainter {
  YardMap(this.game);
  final HazardGame game;
  @override
  void paint(Canvas c, Size size) {
    Offset p(Point2 v) =>
        Offset((v.x + 12) / 24 * size.width, (v.z + 18) / 36 * size.height);
    final paint = Paint()..color = const Color(0xff536975);
    for (final b in game.world.boxes) {
      c.drawRect(
        Rect.fromCenter(
          center: p(Point2(b.x, b.z)),
          width: b.width / 24 * size.width,
          height: b.depth / 36 * size.height,
        ),
        paint,
      );
    }
    for (final g in game.guards.where((g) => g.health > 0)) {
      paint.color = g.awareness.mode == AwarenessMode.chase
          ? Colors.redAccent
          : Colors.orangeAccent;
      c.drawCircle(p(g.position), 4, paint);
      c.drawLine(
        p(g.position),
        p(g.position + Point2(math.sin(g.yaw), math.cos(g.yaw)) * 1.3),
        paint..strokeWidth = 2,
      );
    }
    paint.color = Colors.tealAccent;
    c.drawCircle(p(game.terminal), 5, paint);
    c.drawCircle(p(game.exit), 6, paint);
    paint.color = Colors.white;
    c.drawCircle(p(game.player), 4, paint);
    c.drawLine(p(game.player), p(game.player + game.facing * 1.5), paint);
  }

  @override
  bool shouldRepaint(covariant YardMap oldDelegate) => true;
}
