import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:marionette_flutter/marionette_flutter.dart';

import 'automation/extensions.dart';
import 'lab/benchmark.dart';
import 'lab/lab_controller.dart';
import 'lab/simulation.dart';

const accent = Color(0xffe7b76a),
    muted = Color(0xff99aaa7),
    panel = Color(0xff17201f);
void main() {
  if (kDebugMode && !kIsWeb) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(const HazardLabApp());
}

class HazardLabApp extends StatelessWidget {
  const HazardLabApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'そば屋ハザード · 3D検証室',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xff0e1514),
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        surface: panel,
      ),
      sliderTheme: const SliderThemeData(trackHeight: 3),
    ),
    home: const LabPage(),
  );
}

class LabPage extends StatefulWidget {
  const LabPage({super.key});
  @override
  State<LabPage> createState() => _LabPageState();
}

class _LabPageState extends State<LabPage> {
  final lab = LabController();
  final focus = FocusNode(debugLabel: '3D viewport');
  final keys = <LogicalKeyboardKey>{};
  Timer? refresh;
  AppLifecycleListener? lifecycle;
  LabBenchmark? benchmark;
  String? error;
  double touchX = 0, touchY = 0;
  @override
  void initState() {
    super.initState();
    attachLabAutomation(lab);
    lab.addListener(changed);
    SchedulerBinding.instance.addTimingsCallback(record);
    lifecycle = AppLifecycleListener(
      onInactive: clearInput,
      onHide: clearInput,
      onPause: clearInput,
    );
    refresh = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
    lab
        .load()
        .then((_) {
          if (mounted && const bool.fromEnvironment('LAB_BENCHMARK')) {
            benchmark = LabBenchmark(lab);
          }
        })
        .catchError((Object e, StackTrace stack) {
          debugPrint('Sobaya Lab: $e\n$stack');
          if (mounted) setState(() => error = e.toString());
        });
  }

  void changed() {
    if (mounted) setState(() {});
  }

  void clearInput() {
    keys.clear();
    touchX = 0;
    touchY = 0;
    lab.inputX = 0;
    lab.inputY = 0;
    lab.sprint = false;
  }

  void record(List<ui.FrameTiming> timings) {
    if (!lab.ready) return;
    for (final t in timings) {
      if (lab.warmupFrames > 0) {
        lab.warmupFrames--;
        continue;
      }
      lab.frames.add(
        t.buildDuration.inMicroseconds / 1000,
        t.rasterDuration.inMicroseconds / 1000,
      );
    }
  }

  @override
  void dispose() {
    refresh?.cancel();
    benchmark?.dispose();
    lifecycle?.dispose();
    SchedulerBinding.instance.removeTimingsCallback(record);
    detachLabAutomation(lab);
    lab.removeListener(changed);
    lab.dispose();
    focus.dispose();
    super.dispose();
  }

  void updateInput() {
    double held(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
        keys.contains(a) || keys.contains(b) ? 1 : 0;
    lab.inputX =
        (held(LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight) -
                held(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft) +
                touchX)
            .clamp(-1, 1);
    lab.inputY =
        (held(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp) -
                held(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown) +
                touchY)
            .clamp(-1, 1);
    lab.sprint =
        keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
  }

  KeyEventResult keyEvent(FocusNode node, KeyEvent e) {
    const allowed = [
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
    ];
    if (!allowed.contains(e.logicalKey)) return KeyEventResult.ignored;
    if (e is KeyUpEvent) {
      keys.remove(e.logicalKey);
    } else {
      keys.add(e.logicalKey);
    }
    updateInput();
    return KeyEventResult.handled;
  }

  void mode(LabMode next) {
    clearInput();
    lab.open(next);
    focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, size) {
          final wide = size.maxWidth >= 1000;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
                child: Row(
                  children: [
                    Container(width: 5, height: 38, color: accent),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SOBA HAZARD / FIELD LAB',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 2,
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'そば屋ハザード · 3D検証室',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (size.maxWidth > 620)
                      const Text(
                        'Flutter 3.47.2\nScene 0.23.0',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          color: muted,
                          height: 1.7,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    for (final e in [
                      (LabMode.model, Icons.view_in_ar_outlined, 'モデル観察'),
                      (LabMode.movement, Icons.directions_walk, '移動・衝突'),
                      (LabMode.crowd, Icons.groups_outlined, '群集負荷'),
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ChoiceChip(
                            key: ValueKey('mode-${e.$1.name}'),
                            selected: lab.mode == e.$1,
                            onSelected: lab.ready ? (_) => mode(e.$1) : null,
                            avatar: Icon(e.$2, size: 17),
                            label: Text(e.$3),
                            showCheckmark: false,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: viewport()),
                          SizedBox(width: 320, child: settings()),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: viewport()),
                          SizedBox(
                            height: size.maxHeight < 650 ? 175 : 240,
                            child: settings(),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
  Widget viewport() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 16, 18),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xff242f2d),
              child: error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SelectableText('読込エラー\n$error'),
                      ),
                    )
                  : !lab.ready
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 20),
                          Text('4Kモデルを準備しています…'),
                        ],
                      ),
                    )
                  : Focus(
                      focusNode: focus,
                      autofocus: true,
                      onKeyEvent: keyEvent,
                      onFocusChange: (v) {
                        if (!v) clearInput();
                      },
                      child: Listener(
                        onPointerSignal: (e) {
                          if (e is PointerScrollEvent) {
                            lab.zoom(e.scrollDelta.dy * .007);
                          }
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => focus.requestFocus(),
                          onPanStart: (_) => focus.requestFocus(),
                          onPanUpdate: (d) => lab.orbit(d.delta.dx, d.delta.dy),
                          child: LayoutBuilder(
                            builder: (context, bounds) {
                              lab.viewportWidth = bounds.maxWidth;
                              lab.viewportHeight = bounds.maxHeight;
                              lab.devicePixelRatio =
                                  MediaQuery.devicePixelRatioOf(context);
                              return SceneView(
                                lab.scene,
                                key: const ValueKey('scene-viewport'),
                                cameraBuilder: (_) => lab.camera(),
                                onTick: lab.tick,
                                warmUp: true,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            left: 18,
            top: 16,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tag(switch (lab.mode) {
                    LabMode.model => '01 / ASSET INSPECTION',
                    LabMode.movement => '02 / MOVEMENT TEST',
                    LabMode.crowd => '03 / CROWD BENCHMARK',
                  }),
                  const SizedBox(height: 7),
                  Text(
                    lab.mode == LabMode.crowd
                        ? 'SOBA × ${lab.count.toString().padLeft(2, '0')}'
                        : 'SOBAYA',
                    style: const TextStyle(
                      fontSize: 25,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'P2.0  /  4K PBR  /  1.80 m',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: 14,
            child: tag(
              lab.ready ? '●  READY' : '●  LOADING',
              color: const Color(0xff88c6aa),
            ),
          ),
          if (lab.ready)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lab.mode == LabMode.movement)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        pad(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            lab.collisionTest
                                ? lab.testResult
                                : 'WASD / 矢印で移動 · Shiftで走る\nドラッグで視点 · ホイールで距離',
                            style: const TextStyle(fontSize: 11, height: 1.6),
                          ),
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final v in [
                          ('front', '正面'),
                          ('side', '側面'),
                          ('back', '背面'),
                        ])
                          OutlinedButton(
                            key: ValueKey('view-${v.$1}'),
                            onPressed: () => lab.setView(v.$1),
                            child: Text(v.$2),
                          ),
                        if (lab.mode == LabMode.model)
                          OutlinedButton.icon(
                            key: const ValueKey('turntable'),
                            onPressed: () =>
                                lab.option('turntable', !lab.turntable),
                            icon: Icon(
                              lab.turntable ? Icons.pause : Icons.rotate_right,
                              size: 16,
                            ),
                            label: const Text('回転'),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    '原型モデル · リグなし（歩行アニメーション未実装）',
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
  Widget tag(String label, {Color color = accent}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xe619211f),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        letterSpacing: .8,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
  Widget pad() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      moveButton('up', Icons.keyboard_arrow_up, 0, 1),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          moveButton('left', Icons.keyboard_arrow_left, -1, 0),
          moveButton('down', Icons.keyboard_arrow_down, 0, -1),
          moveButton('right', Icons.keyboard_arrow_right, 1, 0),
        ],
      ),
    ],
  );
  Widget moveButton(String name, IconData icon, double x, double y) => Listener(
    onPointerDown: (_) {
      focus.requestFocus();
      touchX = x;
      touchY = y;
      updateInput();
    },
    onPointerUp: (_) {
      touchX = 0;
      touchY = 0;
      updateInput();
    },
    onPointerCancel: (_) {
      touchX = 0;
      touchY = 0;
      updateInput();
    },
    child: Container(
      key: ValueKey('move-$name'),
      width: 43,
      height: 38,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xea17201f),
        border: Border.all(color: const Color(0xff4b6159)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, color: accent),
    ),
  );
  Widget section(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        color: muted,
        fontSize: 11,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
  Widget metric(String label, double? value) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff202d29),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: muted)),
          const SizedBox(height: 5),
          Text(
            value == null ? '—' : '${value.toStringAsFixed(1)} ms',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: value != null && value > 16.7
                  ? const Color(0xffffa18d)
                  : Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
  Widget toggle(String key, String title, bool value) =>
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        dense: true,
        key: ValueKey('option-$key'),
        title: Text(title, style: const TextStyle(fontSize: 13)),
        value: value,
        onChanged: lab.ready ? (v) => lab.option(key, v) : null,
      );
  Widget settings() => Container(
    margin: const EdgeInsets.fromLTRB(0, 0, 20, 18),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xff293832)),
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section('FRAME TIMING / P95'),
          Row(
            children: [
              metric('UI / Dart', lab.frames.uiP95),
              const SizedBox(width: 8),
              metric('Raster', lab.frames.rasterP95),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            '${lab.frames.count} / 240 frames · 60 fps目安 16.7 ms',
            style: const TextStyle(fontSize: 10, color: muted),
          ),
          if (kDebugMode)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'DEBUG参考値 · 性能判断はprofileで',
                style: TextStyle(fontSize: 10, color: accent),
              ),
            ),
          section('SCENARIO'),
          if (lab.mode == LabMode.model) ...[
            const Text(
              '仮面・肌・背面を確認',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              '21,068 triangles / 1 material\n4Kの原型をそのまま観察します。',
              style: TextStyle(fontSize: 12, color: muted, height: 1.7),
            ),
          ],
          if (lab.mode == LabMode.movement) ...[
            Text(
              'X ${lab.simulation.x.toStringAsFixed(2)}   Z ${lab.simulation.z.toStringAsFixed(2)} m',
              style: const TextStyle(
                fontSize: 17,
                fontFeatures: [ui.FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '移動 ${lab.simulation.distanceTravelled.toStringAsFixed(2)} m / 接触 ${lab.simulation.collisionFrames} frames\nカメラ距離 ${(lab.cameraCompression * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 11, color: muted, height: 1.7),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('collision-test'),
              onPressed: lab.ready ? lab.runCollisionTest : null,
              icon: const Icon(Icons.science_outlined, size: 17),
              label: const Text('壁衝突テスト'),
            ),
            Text(
              lab.testResult,
              key: const ValueKey('test-result'),
              style: const TextStyle(fontSize: 11, color: accent),
            ),
          ],
          if (lab.mode == LabMode.crowd) ...[
            Wrap(
              spacing: 7,
              children: [
                for (final n in [1, 4, 8, 12])
                  ChoiceChip(
                    key: ValueKey('count-$n'),
                    label: Text('$n体'),
                    selected: lab.count == n,
                    onSelected: lab.ready ? (_) => lab.setCount(n) : null,
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '配置三角面 ${(21068 * lab.count / 1000).toStringAsFixed(1)}K（概算）\n同一メッシュ・材質を共有。スキン負荷は含みません。',
              style: const TextStyle(fontSize: 11, color: muted, height: 1.7),
            ),
            toggle('motion', '原型を一斉に移動', lab.crowdMotion),
          ],
          section('RENDER CONTROLS'),
          toggle('shadows', '影を描画', lab.shadows),
          toggle('ao', '接地の陰影（AO）', lab.ao),
          toggle('collision', '足元の衝突半径を表示', lab.showCollision),
          Row(
            children: [
              const Expanded(
                child: Text('描画解像度', style: TextStyle(fontSize: 12)),
              ),
              Text(
                '${(lab.renderScale * 100).round()}%',
                style: const TextStyle(color: accent),
              ),
            ],
          ),
          Slider(
            key: const ValueKey('render-scale'),
            value: lab.renderScale,
            min: .5,
            max: 1,
            divisions: 2,
            onChanged: lab.ready ? (v) => lab.option('scale', v) : null,
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('reset-metrics'),
                  onPressed: () {
                    lab.resetMeasurement();
                    changed();
                  },
                  child: const Text('計測リセット'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey('copy-report'),
                tooltip: '検証結果JSONをコピー',
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: const JsonEncoder.withIndent('  ')
                          .convert(lab.inspect()),
                    ),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('検証結果をコピーしました')),
                    );
                  }
                },
                icon: const Icon(Icons.content_copy, size: 18),
              ),
            ],
          ),
          OutlinedButton.icon(
            key: const ValueKey('reset-scene'),
            onPressed: lab.ready ? () => mode(lab.mode) : null,
            icon: const Icon(Icons.restart_alt, size: 17),
            label: const Text('シーンを初期位置へ'),
          ),
          section('ASSET / SOBAYA v01'),
          Text(
            '読込 ${lab.loadMs} ms · GLB 10.3 MiB\nImagegen → Tripo P2.0 → Blender',
            style: const TextStyle(fontSize: 10, color: muted, height: 1.7),
          ),
          const SizedBox(height: 18),
        ],
      ),
    ),
  );
}
