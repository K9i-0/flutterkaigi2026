import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

import 'catch_game.dart';
import 'catch_scene.dart';
import 'tilt_input.dart';

const gold = Color(0xffefbd63),
    cream = Color(0xfff6edda),
    ink = Color(0xff102725);
void main() async {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(primary: gold, surface: ink),
        useMaterial3: true,
      ),
      home: const RainPage(),
    ),
  );
}

class RainPage extends StatefulWidget {
  const RainPage({super.key});
  @override
  State<RainPage> createState() => _RainState();
}

class _RainState extends State<RainPage> {
  final game = CatchGame()..lane = true;
  final world = CatchScene(), tilt = TiltInput(), sound = AudioPlayer();
  bool ready = false,
      paused = false,
      demo = false,
      mute = false,
      frozen = false;
  String? error;
  double inputX = 0, inputY = 0, accumulator = 0;
  int lastEvent = 0, turn = 0, seed = 1;
  AppLifecycleListener? lifecycle;
  @override
  void initState() {
    super.initState();
    tilt.start();
    lifecycle = AppLifecycleListener(
      onInactive: () {
        if (mounted) setState(() => paused = true);
      },
    );
    load();
    if (kDebugMode) {
      registerMarionetteExtension(
        name: 'madogiwa.inspectCatch',
        description: 'Inspect real simulation, sensor and camera.',
        callback: (p) async => MarionetteExtensionResult.success({
          'ready': ready,
          'error': error,
          'sensor': tilt.available,
          'demo': demo,
          'paused': paused,
          ...game.inspect(),
        }),
      );
      registerMarionetteExtension(
        name: 'madogiwa.catchAction',
        description: 'action=start|demo|step|rotate|pause|resume. step seconds 0..25 x/y -1..1. Demo supplies inputs only.',
        callback: (p) async {
          if (!ready) return MarionetteExtensionResult.error(1, 'Not ready');
          switch (p['action']) {
            case 'start':
              if (p['mode'] != null) game.lane = p['mode'] == 'lane';
              start();
              frozen = true;
            case 'demo':
              if (p['mode'] != null) game.lane = p['mode'] == 'lane';
              start();
              demo = true;
            case 'rotate':
              game.rotate(int.tryParse(p['direction'] ?? '1') ?? 1);
            case 'pause':
              paused = true;
            case 'resume':
              paused = false;
              frozen = false;
              tilt.calibrate();
            case 'step':
              final seconds = double.tryParse(p['seconds'] ?? '0') ?? -1,
                  x = double.tryParse(p['x'] ?? '0') ?? 2,
                  y = double.tryParse(p['y'] ?? '0') ?? 2;
              if (!seconds.isFinite ||
                  seconds < 0 ||
                  seconds > 25 ||
                  !x.isFinite ||
                  !y.isFinite ||
                  x.abs() > 1 ||
                  y.abs() > 1) {
                return MarionetteExtensionResult.invalidParams(
                  'seconds 0..25, x/y -1..1',
                );
              }
              frozen = true;
              for (var i = 0; i < (seconds * 60).round(); i++) {
                advance(1 / 60, x, y);
              }
              world.update(game, 1 / 60);
            default:
              return MarionetteExtensionResult.invalidParams('Unknown action');
          }
          setState(() {});
          return MarionetteExtensionResult.success(game.inspect());
        },
      );
    }
  }

  Future<void> load() async {
    try {
      await world.load();
      if (mounted) setState(() => ready = true);
    } catch (e, st) {
      debugPrint('$e\n$st');
      if (mounted) setState(() => error = '$e');
    }
  }

  void start() {
    game.start(seed: seed);
    tilt.calibrate();
    inputX = 0;
    inputY = 0;
    accumulator = 0;
    lastEvent = 0;
    turn = 0;
    paused = false;
    frozen = false;
    demo = false;
  }

  void advance(double dt, double x, double y) {
    if (demo) {
      final input = game.demoInput();
      x = input.x;
      y = input.y;
      final length = math.max(1.0, math.sqrt(x * x + y * y));
      inputX = x / length;
      inputY = y / length;
      if (!game.lane && game.time > 6 && turn == 0) {
        game.rotate(1);
        turn++;
      }
      if (!game.lane && game.time > 12 && turn == 1) {
        game.rotate(-1);
        turn++;
      }
    }
    if (demo && game.lane) {
      final targets = game.drops
          .where((d) => !d.resolved && d.spawn <= game.time)
          .toList();
      if (targets.isNotEmpty) {
        final target = targets.first.facing.sign * math.pi / 3;
        if ((game.targetYaw - target).abs() > .1) {
          game.rotate(target > game.targetYaw ? 1 : -1);
        }
      }
    }
    game.tick(dt, inputX: x, inputY: y);
    if (game.eventId != lastEvent) {
      lastEvent = game.eventId;
      if (game.message.startsWith('これ')) {
        HapticFeedback.heavyImpact();
        play('miss.wav');
      } else {
        HapticFeedback.selectionClick();
        play('catch.wav');
      }
    }
  }

  Future<void> play(String file) async {
    if (mute || frozen) return;
    try {
      await sound.play(AssetSource('audio/$file'), volume: .5);
    } catch (_) {}
  }

  void tick(Duration elapsed, double dt) {
    if (!ready || paused || frozen) return;
    accumulator += dt.clamp(0, .1);
    while (accumulator >= 1 / 60) {
      advance(
        1 / 60,
        tilt.available ? tilt.x : inputX,
        tilt.available ? tilt.y : inputY,
      );
      accumulator -= 1 / 60;
    }
    world.update(game, dt.clamp(0, .1));
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    tilt.dispose();
    lifecycle?.dispose();
    sound.dispose();
    super.dispose();
  }

  Widget chip(String text, {Color color = cream}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: ink.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: .22)),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
  Widget button(String text, VoidCallback f, String key) => FilledButton(
    key: ValueKey(key),
    onPressed: () => setState(f),
    child: Text(text),
  );
  Widget legend() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      chip('ビール +100〜', color: gold),
      const SizedBox(width: 6),
      chip('紫帯の発泡酒 −200', color: const Color(0xffcca8fa)),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, size) {
        final playing =
            game.phase == Phase.playing || game.phase == Phase.countdown;
        return Stack(
          children: [
            if (ready)
              Positioned.fill(
                child: SceneView(
                  world.scene,
                  camera: world.camera,
                  onTick: tick,
                ),
              ),
            if (error != null) Center(child: Text(error!)),
            if (!ready && error == null)
              const Center(child: CircularProgressIndicator()),
            if (ready)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              game.lane ? 'そば屋のビール雨 / 左右版' : 'そば屋のビール雨',
                              style: TextStyle(
                                color: cream,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(blurRadius: 8)],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              demo
                                  ? 'SIMULATOR / 傾き入力を再生中'
                                  : tilt.available
                                  ? 'TILT TO CATCH  /  傾きで移動'
                                  : 'SIMULATOR / 左下パッドで移動',
                              style: const TextStyle(
                                color: gold,
                                fontSize: 10,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Row(
                          children: [
                            chip(
                              '残り ${(CatchGame.duration - game.time).ceil()} 秒',
                            ),
                            const SizedBox(width: 8),
                            chip('${game.score} pt', color: gold),
                            IconButton(
                              key: const ValueKey('pause'),
                              onPressed: () => setState(() {
                                paused = !paused;
                                if (!paused) tilt.calibrate();
                              }),
                              icon: Icon(
                                paused ? Icons.play_arrow : Icons.pause,
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => mute = !mute),
                              icon: Icon(
                                mute ? Icons.volume_off : Icons.volume_up,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (playing)
                        Positioned(
                          left: 0,
                          width: 175,
                          top: 62,
                          child: Center(
                            child: game.phase == Phase.countdown
                                ? chip(
                                    '準備！ ${game.countdown.ceil()}',
                                    color: gold,
                                  )
                                : game.time < game.messageUntil
                                ? chip(
                                    game.message,
                                    color: game.message.startsWith('これ')
                                        ? const Color(0xffff927a)
                                        : cream,
                                  )
                                : game.combo > 1
                                ? chip('${game.combo} COMBO', color: gold)
                                : const SizedBox(),
                          ),
                        ),
                      if (playing)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              legend(),
                              const SizedBox(width: 10),
                              Text(
                                game.lane ? '見回して表ラベルを確認' : '影の位置へ先回り',
                                style: TextStyle(
                                  color: cream.withValues(alpha: .8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (playing)
                        Positioned(
                          right: 0,
                          bottom: 45,
                          child: Row(
                            children: [
                              button(
                                game.lane ? '↶ 30°' : '↶ 45°',
                                () => game.rotate(-1),
                                'camera_left',
                              ),
                              const SizedBox(width: 8),
                              button(
                                game.lane ? '30° ↷' : '45° ↷',
                                () => game.rotate(1),
                                'camera_right',
                              ),
                            ],
                          ),
                        ),
                      if (playing)
                        Positioned(
                          left: 4,
                          bottom: 35,
                          child: GestureDetector(
                            key: const ValueKey('move_pad'),
                            onPanUpdate: (e) {
                              if (demo || tilt.available) return;
                              setState(() {
                                inputX = ((e.localPosition.dx - 48) / 40).clamp(
                                  -1,
                                  1,
                                );
                                inputY = game.lane
                                    ? 0
                                    : ((48 - e.localPosition.dy) / 40).clamp(
                                        -1,
                                        1,
                                      );
                              });
                            },
                            onPanCancel: () => setState(() {
                              inputX = 0;
                              inputY = 0;
                            }),
                            onPanEnd: (_) => setState(() {
                              inputX = 0;
                              inputY = 0;
                            }),
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ink.withValues(alpha: .75),
                                border: Border.all(
                                  color: gold.withValues(alpha: .5),
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    tilt.available || demo
                                        ? Icons.screen_rotation
                                        : Icons.open_with,
                                    color: gold.withValues(alpha: .35),
                                    size: 32,
                                  ),
                                  Transform.translate(
                                    offset: Offset(
                                      (tilt.available && !demo
                                              ? tilt.x
                                              : inputX) *
                                          28,
                                      -(game.lane
                                              ? 0
                                              : tilt.available && !demo
                                              ? tilt.y
                                              : inputY) *
                                          28,
                                    ),
                                    child: Container(
                                      width: 15,
                                      height: 15,
                                      decoration: const BoxDecoration(
                                        color: gold,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  const Positioned(
                                    bottom: 8,
                                    child: Text(
                                      'MOVE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: gold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (game.phase == Phase.ready ||
                          game.phase == Phase.result ||
                          paused)
                        Center(
                          child: Container(
                            width: math.min(570, size.maxWidth - 80),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: ink.withValues(alpha: .97),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: gold.withValues(alpha: .35),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  paused
                                      ? 'ひと休み'
                                      : game.phase == Phase.result
                                      ? '${game.score} pt'
                                      : '降ってくるのは、ビールだけ？',
                                  style: const TextStyle(
                                    fontSize: 27,
                                    fontWeight: FontWeight.bold,
                                    color: cream,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (game.phase == Phase.result)
                                  Text(
                                    'ビール ${game.caught}本  ／  発泡酒 ${game.bad}本  ／  取り逃し ${game.missed}本',
                                    style: const TextStyle(color: gold),
                                  )
                                else if (!paused)
                                  Text(
                                    game.lane
                                        ? '左右に傾けて一本道を歩こう。\n缶の向きはばらばら。カメラで表ラベルを見て、発泡酒を避けろ！'
                                        : '小さく傾けて、前後左右へ。\n左右のカメラボタンで見回そう。紫帯の発泡酒は避けろ！',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 14, height: 1.6),
                                  ),
                                const SizedBox(height: 12),
                                if (!paused) legend(),
                                if (!paused)
                                  TextButton(
                                    key: const ValueKey('mode_toggle'),
                                    onPressed: () => setState(() {
                                      game.lane = !game.lane;
                                      start();
                                      game.phase = Phase.ready;
                                      world.update(game, 0);
                                    }),
                                    child: Text(
                                      game.lane
                                          ? '左右移動版  ↔  面移動版に切替'
                                          : '面移動版  ↔  左右移動版に切替',
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    button(
                                      paused
                                          ? '持ち方を合わせて再開'
                                          : game.phase == Phase.result
                                          ? 'もう一回！'
                                          : 'キャッチ開始',
                                      () {
                                        if (paused) {
                                          paused = false;
                                          tilt.calibrate();
                                        } else {
                                          start();
                                        }
                                      },
                                      paused ? 'resume' : 'start',
                                    ),
                                    if (!paused) ...[
                                      const SizedBox(width: 10),
                                      TextButton(
                                        key: const ValueKey('new_seed'),
                                        onPressed: () => setState(() => seed++),
                                        child: Text('配置 #$seed'),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
