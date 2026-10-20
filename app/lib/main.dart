import 'dart:math' as math;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'balance.dart';
import 'balance_panel.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

import 'catch_game.dart';
import 'character.dart';
import 'selection_screen.dart';
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
  final game = CatchGame()
    ..lane = true
    ..z = 0;
  final world = CatchScene(), tilt = TiltInput(), sound = AudioPlayer();
  bool ready = false,
      paused = false,
      demo = false,
      mute = false,
      frozen = false;
  String? error;
  double inputX = 0, inputY = 0, accumulator = 0, swipe = 0;
  int lastEvent = 0, turn = 0, seed = 1;
  AppLifecycleListener? lifecycle;
  @override
  void initState() {
    super.initState();
    tilt.start();
    lifecycle = AppLifecycleListener(
      onInactive: () {
        if (mounted &&
            (game.phase == Phase.playing || game.phase == Phase.countdown)) {
          setState(() => paused = true);
        }
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
          ...world.inspect(),
        }),
      );
      registerMarionetteExtension(
        name: 'madogiwa.catchAction',
        description: 'action=select|configure|start|demo|step|rotate|pause|resume. select: character ID and/or timeOfDay=day|night. configure: json settings, seed. step seconds 0..25 x/y -1..1. Demo supplies inputs only.',
        callback: (p) async {
          if (!ready) return MarionetteExtensionResult.error(1, 'Not ready');
          switch (p['action']) {
            case 'select':
              final character = CatchCharacter.values
                  .where((c) => c.id == p['character'])
                  .firstOrNull;
              final time = StageTime.values
                  .where((t) => t.id == p['timeOfDay'])
                  .firstOrNull;
              if ((p['character'] != null &&
                      (character == null ||
                          !game.selectCharacter(character))) ||
                  (p['timeOfDay'] != null &&
                      (time == null || !game.selectTime(time))) ||
                  (character == null && time == null)) {
                return MarionetteExtensionResult.invalidParams(
                  'Select a known character or timeOfDay=day|night on the ready or result screen',
                );
              }
              world.update(game, 0);
            case 'configure':
              try {
                final data =
                    jsonDecode(p['json'] ?? '{}') as Map<String, dynamic>;
                final next = Balance.fromMap({...game.balance.values, ...data});
                final nextSeed = int.tryParse(p['seed'] ?? '$seed');
                if (nextSeed == null || nextSeed < 0 || nextSeed > 999999999) {
                  return MarionetteExtensionResult.invalidParams(
                    'Invalid seed',
                  );
                }
                game.balance = next;
                seed = nextSeed;
                await saveBalance();
                start();
                frozen = true;
              } catch (e) {
                return MarionetteExtensionResult.invalidParams('$e');
              }
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
                world.update(game, 1 / 60);
              }
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
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('beerRain.balance.v1');
      if (saved != null) {
        try {
          final data = jsonDecode(saved) as Map<String, dynamic>;
          final b = Balance.fromMap(
            Map<String, dynamic>.from(data['balance'] as Map),
          );
          final n = data['seed'];
          if (n is int && n >= 0 && n <= 999999999) {
            game.balance = b;
            seed = n;
          }
        } catch (_) {
          /* Invalid saved settings fall back to defaults. */
        }
      }
      game.seed = seed;
      await world.load();
      world.update(game, 0);
      if (mounted) setState(() => ready = true);
    } catch (e, st) {
      debugPrint('$e\n$st');
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> saveBalance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'beerRain.balance.v1',
      jsonEncode({'seed': seed, 'balance': game.balance.values}),
    );
  }

  Future<void> openBalance() async {
    final wasPaused = paused;
    setState(() => paused = true);
    final selected = await showDialog<BalanceSelection>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BalancePanel(balance: game.balance, seed: seed),
    );
    if (!mounted) return;
    if (selected == null) {
      setState(() => paused = wasPaused);
      return;
    }
    game.balance = selected.balance;
    seed = selected.seed;
    await saveBalance();
    if (!mounted) return;
    setState(start);
  }

  void start() {
    game.start(seed: seed);
    tilt.maxDegrees = game.balance['tiltDegrees'];
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
    if (demo && game.lane && game.time > 3) {
      final targets = game.drops
          .where((d) => !d.resolved && d.spawn <= game.time)
          .toList();
      if (targets.isNotEmpty) {
        final target =
            targets.first.facing.sign *
            game.balance['cameraLimit'] *
            math.pi /
            180;
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
    if (!tilt.available) {
      // Simulator fallback without on-screen controls: arrow keys.
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      double axis(LogicalKeyboardKey neg, LogicalKeyboardKey pos) =>
          (keys.contains(pos) ? 1.0 : 0.0) - (keys.contains(neg) ? 1.0 : 0.0);
      inputX = axis(
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
      );
      inputY = game.lane
          ? 0
          : axis(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowUp);
    }
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
      chip(
        '${game.lane ? game.roundCharacter.goodDrops.first.label : 'ビール'} +${game.balance['beerPoints'].round()}〜',
        color: gold,
      ),
      const SizedBox(width: 6),
      chip(
        '${game.lane ? game.roundCharacter.badDrop.label : '紫帯の発泡酒'} −${game.balance['penalty'].round()}',
        color: const Color(0xffcca8fa),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, size) {
        if (ready &&
            game.lane &&
            !paused &&
            (game.phase == Phase.ready || game.phase == Phase.result)) {
          return SelectionScreen(
            game: game,
            world: world,
            seed: seed,
            onSelect: (character) => setState(() {
              game.selectCharacter(character);
              world.update(game, 0);
            }),
            onTime: (time) => setState(() {
              game.selectTime(time);
              world.update(game, 0);
            }),
            onStart: () => setState(start),
            onMode: () => setState(() {
              game.lane = false;
              start();
              game.phase = Phase.ready;
              world.update(game, 0);
            }),
            onSeed: () => setState(() => seed++),
            onSettings: kDebugMode ? openBalance : null,
          );
        }
        final playing =
            game.phase == Phase.playing || game.phase == Phase.countdown;
        return Stack(
          children: [
            if (ready)
              Positioned.fill(
                // Horizontal swipes orbit the camera; movement is tilt only.
                child: GestureDetector(
                  key: const ValueKey('camera_swipe'),
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) => swipe = 0,
                  onHorizontalDragUpdate: (e) {
                    if (!playing) return;
                    swipe += e.delta.dx;
                    if (swipe.abs() < 60) return;
                    setState(() => game.rotate(swipe < 0 ? 1 : -1));
                    swipe = 0;
                  },
                  child: SceneView(
                    world.scene,
                    camera: world.camera,
                    onTick: tick,
                  ),
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
                              game.lane ? 'ゆめみ採用試験' : 'ゆめみ採用試験 / 面移動版',
                              style: TextStyle(
                                color: cream,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(blurRadius: 8)],
                              ),
                            ),
                            Text(
                              'プレイヤー：${(game.lane ? (playing ? game.roundCharacter : game.selectedCharacter) : CatchCharacter.sobaya).label}',
                              style: const TextStyle(
                                color: cream,
                                fontSize: 12,
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
                              '残り ${(game.roundSeconds - game.time).ceil()} 秒',
                            ),
                            const SizedBox(width: 8),
                            chip('${game.score} pt', color: gold),
                            if (kDebugMode)
                              IconButton(
                                key: const ValueKey('balance_debug'),
                                tooltip: 'バランス調整',
                                onPressed: openBalance,
                                icon: const Icon(Icons.tune),
                              ),
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
                      if (game.phase == Phase.ready ||
                          game.phase == Phase.result ||
                          paused)
                        Center(
                          child: SingleChildScrollView(
                            key: const ValueKey('round_menu'),
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
                                      'あたり ${game.caught}  ／  はずれ ${game.bad}  ／  取り逃し ${game.missed}',
                                      style: const TextStyle(color: gold),
                                    )
                                  else if (!paused)
                                    Text(
                                      game.lane
                                          ? '足場は細い鉄骨一本。左右に傾けて歩こう。\n缶の向きはばらばら。カメラで表ラベルを見て、発泡酒を避けろ！'
                                          : '小さく傾けて、前後左右へ。\n左右にスワイプして見回そう。紫帯の発泡酒は避けろ！',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.6,
                                      ),
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
                                            ? '鉄骨編  ↔  面移動版に切替'
                                            : '面移動版  ↔  鉄骨編に切替',
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
                                          onPressed: () =>
                                              setState(() => seed++),
                                          child: Text('配置 #$seed'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
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
