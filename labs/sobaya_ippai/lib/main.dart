import 'dart:math' as math;

import 'package:flutter/scheduler.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pour_game.dart';
import 'pour_scene.dart';
import 'tilt_input.dart';
import 'pour_audio.dart';

const cream = Color(0xfff5ebd2),
    amber = Color(0xffefb84d),
    ink = Color(0xff122520);
void main() async {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'そば屋の一杯',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(primary: amber, surface: ink),
        fontFamily: '.SF Pro Text',
      ),
      home: const IppaiPage(),
    ),
  );
}

class IppaiPage extends StatefulWidget {
  const IppaiPage({super.key});
  @override
  State<IppaiPage> createState() => _IppaiPageState();
}

class _IppaiPageState extends State<IppaiPage> {
  final game = PourGame(), renderer = PourScene(), sensor = TiltInput();
  final audio = PourAudio();
  bool ready = false, paused = false, touch = false, frozen = false;
  String? error;
  double manual = 0, accumulator = 0;
  int best = 0, lastMilestone = 0;
  double? captureTilt;
  int captureTicks = 0;
  SharedPreferences? preferences;
  final _rasterTimes = <double>[], _buildTimes = <double>[];
  void recordTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _rasterTimes.add(t.rasterDuration.inMicroseconds / 1000);
      _buildTimes.add(t.buildDuration.inMicroseconds / 1000);
    }
    if (_rasterTimes.length > 180) {
      _rasterTimes.removeRange(0, _rasterTimes.length - 180);
      _buildTimes.removeRange(0, _buildTimes.length - 180);
    }
  }

  Map<String, Object> frameStats() {
    double percentile(List<double> values, double q) {
      if (values.isEmpty) return 0;
      final sorted = [...values]..sort();
      return sorted[((sorted.length - 1) * q).round()];
    }

    return {
      'samples': _rasterTimes.length,
      'rasterP50ms': percentile(_rasterTimes, .5),
      'rasterP95ms': percentile(_rasterTimes, .95),
      'buildP95ms': percentile(_buildTimes, .95),
    };
  }

  AppLifecycleListener? lifecycle;
  @override
  void initState() {
    super.initState();
    if (kDebugMode) SchedulerBinding.instance.addTimingsCallback(recordTimings);
    sensor.start();
    touch =
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android;
    lifecycle = AppLifecycleListener(
      onStateChange: (s) {
        if (s != AppLifecycleState.resumed && mounted) {
          setState(() {
            paused = true;
            manual = 0;
            audio.flow(0);
          });
        }
      },
    );
    load();
    if (kDebugMode) {
      registerMarionetteExtension(
        name: 'madogiwa.inspectPour',
        description: 'Inspect rendering, input and beer simulation.',
        callback: (p) async => MarionetteExtensionResult.success({
          'ready': ready,
          'error': error,
          'paused': paused,
          'touch': touch,
          'sensor': sensor.available,
          'best': best,
          'frames': frameStats(),
          ...game.inspect(),
        }),
      );
      registerMarionetteExtension(
        name: 'madogiwa.pourAction',
        description: 'action=start|step|serve|resume|pause|capture. capture take=perfect|spill replays real input in real time. step seconds 0..22, tilt 0..1. Runs real fixed-step rules and freezes; never injects scores.',
        callback: (p) async {
          if (!ready) return MarionetteExtensionResult.error(1, 'Not ready');
          switch (p['action']) {
            case 'capture':
              start();
              touch = true;
              captureTilt = p['take'] == 'spill' ? 1 : .694;
              manual = captureTilt!;
              captureTicks = 0;
            case 'start':
              start();
              frozen = true;
            case 'serve':
              game.serve();
            case 'pause':
              paused = true;
              audio.flow(0);
            case 'resume':
              paused = false;
              frozen = false;
            case 'step':
              final seconds = double.tryParse(p['seconds'] ?? '0'),
                  tilt = double.tryParse(p['tilt'] ?? '0');
              if (seconds == null ||
                  tilt == null ||
                  !seconds.isFinite ||
                  !tilt.isFinite ||
                  seconds < 0 ||
                  seconds > 22 ||
                  tilt < 0 ||
                  tilt > 1) {
                return MarionetteExtensionResult.invalidParams(
                  'seconds 0..22, tilt 0..1 required',
                );
              }
              frozen = true;
              paused = false;
              for (var i = 0; i < (seconds * 120).round(); i++) {
                advance(1 / 120, tilt);
              }
            default:
              return MarionetteExtensionResult.invalidParams('Unknown action');
          }
          renderer.update(game, 1);
          setState(() {});
          return MarionetteExtensionResult.success(game.inspect());
        },
      );
    }
  }

  Future<void> load() async {
    try {
      await renderer.load();
      try {
        preferences = await SharedPreferences.getInstance();
        best = preferences!.getInt('best') ?? 0;
      } catch (_) {
        /* Playing does not require storage. */
      }
      if (mounted) setState(() => ready = true);
    } catch (e, st) {
      debugPrint('$e\n$st');
      if (mounted) setState(() => error = '$e');
    }
  }

  void start() {
    audio.flow(0);
    captureTilt = null;
    sensor.calibrate();
    manual = 0;
    lastMilestone = 0;
    paused = false;
    frozen = false;
    accumulator = 0;
    game.start();
    HapticFeedback.selectionClick();
  }

  void advance(double dt, double value) {
    final previous = game.phase;
    if (kDebugMode && captureTilt != null) {
      if (captureTilt == .694 && captureTicks == 1429) {
        game.serve();
        manual = 0;
      }
      value =
          game.phase == PourPhase.pouring || game.phase == PourPhase.approach
          ? captureTilt!
          : 0;
      captureTicks++;
    }
    game.tick(dt, input: value);
    renderer.advance(game, dt);
    if (!frozen) audio.flow(game.flow);
    final milestone = (game.fill * 4).floor();
    if (milestone > lastMilestone) {
      lastMilestone = milestone;
      HapticFeedback.selectionClick();
    }
    if (previous != PourPhase.result && game.phase == PourPhase.result) {
      if (game.angry) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
      if (!frozen && captureTilt == null && game.score > best) {
        best = game.score;
        preferences?.setInt('best', best);
      }
      manual = 0;
      if (!frozen) audio.finish(game.angry);
    }
  }

  void tick(Duration elapsed, double dt) {
    if (!ready || paused || frozen) return;
    accumulator += dt.clamp(0, .1);
    while (accumulator >= 1 / 120) {
      advance(1 / 120, touch || !sensor.available ? manual : sensor.value);
      accumulator -= 1 / 120;
    }
    renderer.update(game, dt);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(recordTimings);
    sensor.dispose();
    audio.dispose();
    lifecycle?.dispose();
    super.dispose();
  }

  Widget label(String text, {Color color = amber}) => Text(
    text,
    style: TextStyle(
      fontSize: 10,
      letterSpacing: 2.5,
      fontWeight: FontWeight.w700,
      color: color,
    ),
  );
  Widget button(String title, VoidCallback action, {String? key}) =>
      FilledButton(
        key: key == null ? null : ValueKey(key),
        onPressed: () => setState(action),
        style: FilledButton.styleFrom(
          backgroundColor: amber,
          foregroundColor: ink,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      );
  Widget panel(Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: ink.withValues(alpha: .96),
      border: Border.all(color: cream.withValues(alpha: .16)),
      borderRadius: BorderRadius.circular(22),
    ),
    child: child,
  );
  @override
  Widget build(BuildContext context) {
    final active = game.phase == PourPhase.pouring,
        ended = game.phase == PourPhase.result;
    final safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: const Color(0xff091813),
      body: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: SizedBox(
            width: math.min(520, constraints.maxWidth),
            height: constraints.maxHeight,
            child: Stack(
              children: [
                if (ready)
                  Positioned.fill(
                    child: SceneView(
                      renderer.scene,
                      camera: renderer.camera,
                      onTick: tick,
                    ),
                  ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xcc071510),
                            Colors.transparent,
                            Colors.transparent,
                            Color(0xff091813),
                          ],
                          stops: [0, .30, .59, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                if (!ready)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (error == null)
                            const CircularProgressIndicator(color: amber),
                          const SizedBox(height: 20),
                          Text(
                            error == null ? '開店準備中…' : '開店できませんでした\n$error',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (ready) ...[
                  Positioned(
                    top: safe.top + 18,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            label('MADOGIWA  /  POURING CLUB'),
                            Text(
                              'BEST  $best',
                              style: const TextStyle(
                                color: cream,
                                fontSize: 11,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                active || game.phase == PourPhase.settling
                                    ? '最後の一滴まで。'
                                    : 'そば屋の一杯',
                                style: const TextStyle(
                                  color: cream,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            if (game.phase != PourPhase.ready)
                              IconButton(
                                key: const ValueKey('pause'),
                                onPressed: () => setState(() {
                                  paused = true;
                                  audio.flow(0);
                                }),
                                icon: const Icon(
                                  Icons.pause_rounded,
                                  color: cream,
                                ),
                              ),
                          ],
                        ),
                        if (active || game.phase == PourPhase.settling) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              metric(
                                '充填率',
                                (game.fill * 100).toStringAsFixed(1),
                                '%',
                              ),
                              metric(
                                '泡の比率',
                                (game.foamRatio * 100).toStringAsFixed(0),
                                '%',
                              ),
                              metric(
                                '残り',
                                game.remaining.toStringAsFixed(1),
                                '秒',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: game.remaining / PourGame.duration,
                              minHeight: 3,
                              color: game.remaining < 5
                                  ? Colors.deepOrangeAccent
                                  : amber,
                              backgroundColor: cream.withValues(alpha: .15),
                            ),
                          ),
                        ] else
                          Text(
                            ended ? '一杯に、性格が出る。' : '勢いよく、繊細に。',
                            style: const TextStyle(
                              color: cream,
                              fontSize: 12,
                              letterSpacing: 3,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (game.phase == PourPhase.approach)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: .8),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          '「ちゃんと注げよ」',
                          style: TextStyle(
                            color: cream,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: safe.bottom + 18,
                    left: 20,
                    right: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (game.phase == PourPhase.ready)
                          panel(
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                label('THE PERFECT POUR'),
                                const SizedBox(height: 9),
                                const Text(
                                  'ビール 7 ： 泡 3',
                                  style: TextStyle(
                                    color: cream,
                                    fontSize: 27,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '18秒で、ぴったり満杯。\n一滴でもこぼしたら OUT。',
                                  style: TextStyle(
                                    color: cream,
                                    height: 1.7,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                inputChoice(),
                                Text(
                                  touch || !sensor.available
                                      ? 'スライダーを右へ。戻すと止まる。'
                                      : '端末を縦に持ち、左右に傾けて注ぐ。\n今の持ち方を、開始時にゼロにします。',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                button('一杯、注ぐ', start, key: 'start'),
                              ],
                            ),
                          ),
                        if (active || game.phase == PourPhase.settling)
                          panel(
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    label('BEER'),
                                    const Spacer(),
                                    Text(
                                      '目標 70 : 30',
                                      style: TextStyle(
                                        color: cream.withValues(alpha: .7),
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Spacer(),
                                    label('FOAM', color: cream),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 13,
                                  child: CustomPaint(
                                    size: const Size(double.infinity, 13),
                                    painter: RatioPainter(
                                      game.foamRatio,
                                      game.fill,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  game.phase == PourPhase.settling
                                      ? '最後の一滴を待っています…'
                                      : game.fill > .9
                                      ? '戻して止める。空中の一滴も入る。'
                                      : game.foamRatio > .36
                                      ? '泡が多め。ゆっくり注いで調整。'
                                      : '大きく傾けると勢いと泡が増える。',
                                  style: TextStyle(
                                    color: game.fill > .9 ? amber : cream,
                                    fontSize: 12,
                                  ),
                                ),
                                if (active) ...[
                                  if (touch || !sensor.available)
                                    Slider(
                                      key: const ValueKey('pour_slider'),
                                      value: manual,
                                      onChanged: (v) =>
                                          setState(() => manual = v),
                                      label: '${(manual * 100).round()}%',
                                      semanticFormatterCallback: (v) =>
                                          '注ぐ勢い ${(v * 100).round()}パーセント',
                                    )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.screen_rotation,
                                            color: amber,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: LinearProgressIndicator(
                                              value: sensor.value,
                                              color: amber,
                                              minHeight: 5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  button(
                                    '止めて、差し出す',
                                    () => game.serve(),
                                    key: 'serve',
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (ended)
                          panel(
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                label(
                                  game.spilled
                                      ? 'SPILLED / OUT'
                                      : game.score >= 100
                                      ? 'PERFECT POUR'
                                      : 'YOUR POUR',
                                  color: game.angry
                                      ? const Color(0xffff8065)
                                      : amber,
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      game.spilled ? 'OUT' : '${game.score}',
                                      style: TextStyle(
                                        fontSize: 64,
                                        height: 1.1,
                                        fontWeight: FontWeight.w900,
                                        color: game.angry
                                            ? const Color(0xffff8065)
                                            : cream,
                                      ),
                                    ),
                                    if (!game.spilled)
                                      const Text(
                                        ' / 100',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 17,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '「${game.verdict}」',
                                  style: const TextStyle(
                                    color: cream,
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '充填 ${(game.fill * 100).toStringAsFixed(1)}%    泡 ${(game.foamRatio * 100).toStringAsFixed(1)}% / 理想30%',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  game.spilled
                                      ? '止めてから入る分を、少し残して。'
                                      : game.score >= 90
                                      ? 'その手つき、もう一杯。'
                                      : '量と泡、両方そろえて100点。',
                                  style: const TextStyle(
                                    color: cream,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                button('もう一杯', start, key: 'retry'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (paused)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black54,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: panel(
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'ひと休み',
                                    style: TextStyle(
                                      color: cream,
                                      fontSize: 25,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  inputChoice(),
                                  const Text(
                                    '再開時の持ち方をゼロに補正します。',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white60,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  button('続ける', () {
                                    sensor.calibrate();
                                    manual = 0;
                                    paused = false;
                                  }, key: 'resume'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget inputChoice() => Row(
    children: [
      IconButton(
        tooltip: audio.enabled ? '消音' : '音を出す',
        onPressed: () => setState(() {
          audio.enabled = !audio.enabled;
          audio.flow(0);
        }),
        icon: Icon(
          audio.enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          size: 18,
          color: cream,
        ),
      ),
      const Icon(Icons.screen_rotation, size: 17, color: amber),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          sensor.available ? '端末の傾きで操作' : 'タッチで操作',
          style: const TextStyle(color: cream, fontSize: 12),
        ),
      ),
      if (sensor.available)
        Switch(
          value: !touch,
          onChanged: (v) => setState(() {
            touch = !v;
            manual = 0;
            sensor.calibrate();
          }),
        ),
      if (!sensor.available)
        const Icon(Icons.touch_app, size: 18, color: cream),
    ],
  );
  Widget metric(String name, String value, String unit) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(name, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      const SizedBox(height: 3),
      Text.rich(
        TextSpan(
          text: value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: cream,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          children: [
            TextSpan(
              text: ' $unit',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class RatioPainter extends CustomPainter {
  RatioPainter(this.ratio, this.fill);
  final double ratio, fill;
  @override
  void paint(Canvas canvas, Size s) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & s,
      const Radius.circular(4),
    );
    canvas.save();
    canvas.clipRRect(rect);
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xff35443b));
    if (fill > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, s.width * (1 - ratio), s.height),
        Paint()..color = amber,
      );
      canvas.drawRect(
        Rect.fromLTWH(s.width * (1 - ratio), 0, s.width * ratio, s.height),
        Paint()..color = cream,
      );
    }
    canvas.drawLine(
      Offset(s.width * .70, 0),
      Offset(s.width * .70, s.height),
      Paint()
        ..color = ink
        ..strokeWidth = 3,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RatioPainter old) =>
      ratio != old.ratio || fill != old.fill;
}
