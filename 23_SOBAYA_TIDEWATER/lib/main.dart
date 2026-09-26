import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'water_benchmark.dart';

import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:marionette_flutter/marionette_flutter.dart';

import 'island_game.dart';
import 'atmosphere_panel.dart';
import 'atmosphere_settings.dart';

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
  bool active = true, settingsOpen = false;
  void toggleSettings() {
    if (game.atmosphere == null) return;
    clear();
    setState(() => settingsOpen = !settingsOpen);
    if (!settingsOpen) {
      game.atmosphere?.save();
      focus.requestFocus();
    }
  }

  WaterBenchmark? benchmark;
  AppLifecycleListener? lifecycle;
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(settingsKey);
    lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        active = state == AppLifecycleState.resumed;
        game.sound.setActive(active);
        if (!active) game.atmosphere?.save();
        clear();
        if (mounted) setState(() {});
      },
    );
    if (kDebugMode) {
      registerMarionetteExtension(
        name: 'madogiwa.setAtmosphere',
        description: 'hour=0..23.99, weather=clear|cloudy|mist|rain|storm; other AtmosphereSettings fields.',
        callback: (p) async {
          final a = game.atmosphere;
          if (a == null) return MarionetteExtensionResult.error(1, 'Not ready');
          final values = <String, dynamic>{...a.settings.toJson()};
          for (final e in p.entries) {
            values[e.key] = e.key == 'autoTime'
                ? e.value == 'true'
                : double.tryParse(e.value) ?? e.value;
          }
          a.set(AtmosphereSettings.fromJson(values));
          return MarionetteExtensionResult.success(a.inspect());
        },
      );
      registerMarionetteExtension(
        name: 'madogiwa.drivePlayer',
        description: 'Deterministic collision/jump QA: seconds 0..3, forward/right -1..1, jump=true, pitch optional.',
        callback: (p) async {
          if (!game.ready) {
            return MarionetteExtensionResult.error(1, 'Not ready');
          }
          double num(String k, double fallback) =>
              double.tryParse('${p[k]}') ?? fallback;
          final seconds = num('seconds', 0).clamp(0.0, 3.0);
          game.forward = num('forward', 0).clamp(-1.0, 1.0);
          game.strafe = num('right', 0).clamp(-1.0, 1.0);
          if (p['pitch'] != null) {
            game.pitch = num('pitch', 0).clamp(-1.45, 1.45);
          }
          if (p['jump'] == 'true') game.jump();
          for (var i = 0; i < (seconds * 120).round(); i++) {
            game.tick(
              Duration(microseconds: (game.waterTime * 1e6).round()),
              1 / 120,
            );
          }
          game.clearInput();
          game.syncCamera();
          return MarionetteExtensionResult.success(game.inspect());
        },
      );
      registerMarionetteExtension(
        name: 'madogiwa.inspectSoundscape',
        description:
            'Audio readiness, bed positions, levels, and surf event counts.',
        callback: (_) async =>
            MarionetteExtensionResult.success(await game.sound.inspect()),
      );
      registerMarionetteExtension(
        name: 'madogiwa.setWaterPreview',
        description: 'frozen=true|false; reflection=true|false. For deterministic screenshots.',
        callback: (p) async {
          for (final key in ['frozen', 'reflection']) {
            if (p[key] != null && !['true', 'false'].contains('${p[key]}')) {
              return MarionetteExtensionResult.invalidParams('$key=true|false');
            }
          }
          if (p['frozen'] != null) {
            game.freezeWater = '${p['frozen']}' == 'true';
          }
          if (p['reflection'] != null && game.reflector != null) {
            game.reflector!.enabled = '${p['reflection']}' == 'true';
          }
          return MarionetteExtensionResult.success(game.inspect());
        },
      );
      registerMarionetteExtension(
        name: 'madogiwa.inspectTidewater',
        description: 'Island port readiness, camera and source versions.',
        callback: (_) async =>
            MarionetteExtensionResult.success(game.inspect()),
      );
      registerMarionetteExtension(
        name: 'madogiwa.openTidewater',
        description: 'name= pier | village | overview | shore | water',
        callback: (p) async {
          final name = p['name'];
          if (![
            'pier',
            'village',
            'overview',
            'shore',
            'water',
          ].contains(name)) {
            return MarionetteExtensionResult.invalidParams(
              'name=pier|village|overview|shore|water',
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
          if (mounted && IslandGame.benchmark) {
            benchmark = WaterBenchmark(game, () => active);
          }
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

  KeyEventResult settingsKey(KeyEvent e) {
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.escape &&
        game.ready) {
      toggleSettings();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult key(FocusNode _, KeyEvent e) {
    if (settingsOpen) return KeyEventResult.ignored;
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
      setState(game.toggleFlight);
      clear();
      return KeyEventResult.handled;
    }
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.space &&
        !game.flying) {
      game.jump();
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
                        Text('島と描画を準備しています…'),
                      ],
                    ),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => focus.requestFocus(),
                    onPanStart: (_) => focus.requestFocus(),
                    onPanUpdate: (d) {
                      if (!settingsOpen) game.look(d.delta.dx, d.delta.dy);
                    },
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
          if (game.ready && !settingsOpen) ...[
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
                    if (game.atmosphere != null)
                      IconButton.filledTonal(
                        key: const ValueKey('open-atmosphere'),
                        tooltip: '時間と天気の設定',
                        onPressed: toggleSettings,
                        icon: const Icon(Icons.tune),
                      ),
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
              bottom: 142,
              right: 24,
              child: SafeArea(
                child: FilledButton.tonal(
                  key: const ValueKey('jump'),
                  onPressed: game.flying
                      ? null
                      : () {
                          game.jump();
                          focus.requestFocus();
                        },
                  child: const Text('ジャンプ'),
                ),
              ),
            ),
            Positioned(
              bottom: 86,
              right: 24,
              child: SafeArea(
                child: IconButton.filledTonal(
                  tooltip: game.sound.muted ? '環境音をオン' : '環境音をミュート',
                  onPressed: () async {
                    await game.sound.toggleMute();
                    if (mounted) setState(() {});
                  },
                  icon: Icon(
                    game.sound.muted ? Icons.volume_off : Icons.volume_up,
                  ),
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
                      : 'WASD / 画面の矢印で移動 · ドラッグで見回す\nSpaceでジャンプ · Shiftで走る · Fで飛行',
                  textAlign: TextAlign.right,
                  style: const TextStyle(shadows: [Shadow(blurRadius: 5)]),
                ),
              ),
            ),
          ],
          if (settingsOpen && game.atmosphere != null) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: toggleSettings,
                child: const ColoredBox(color: Color(0x16000000)),
              ),
            ),
            Positioned(
              top: 16,
              bottom: 16,
              right: 16,
              width: (MediaQuery.sizeOf(context).width - 32).clamp(0.0, 400.0),
              child: SafeArea(
                child: AtmospherePanel(
                  atmosphere: game.atmosphere!,
                  onClose: toggleSettings,
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
    FocusManager.instance.removeEarlyKeyEventHandler(settingsKey);
    benchmark?.dispose();
    lifecycle?.dispose();
    game.dispose();
    focus.dispose();
    super.dispose();
  }
}
