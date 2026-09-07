import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:marionette_flutter/marionette_flutter.dart';

import 'automation.dart';
import 'catalog.dart';
import 'motion_controller.dart';

const ink = Color(0xff0b121b), panel = Color(0xff111d29);
const accent = Color(0xff82e4cc), muted = Color(0xff8ba1b4);

void main() {
  if (kDebugMode && !kIsWeb) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(const MotionApp());
}

class MotionApp extends StatelessWidget {
  const MotionApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'そば屋モーションラボ',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: ink,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        surface: panel,
      ),
      dividerColor: const Color(0xff253444),
      sliderTheme: const SliderThemeData(trackHeight: 3),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 13, height: 1.5),
      ),
    ),
    home: const MotionPage(),
  );
}

class MotionPage extends StatefulWidget {
  const MotionPage({super.key});
  @override
  State<MotionPage> createState() => _MotionPageState();
}

class _MotionPageState extends State<MotionPage> {
  final lab = MotionController();
  final search = TextEditingController();
  final focus = FocusNode();
  Timer? timer;
  AppLifecycleListener? lifecycle;
  String? error;
  bool resumeOnFocus = false;
  @override
  void initState() {
    super.initState();
    lab.addListener(changed);
    attachMotionAutomation(lab);
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && !lab.clock.paused) setState(() {});
    });
    lifecycle = AppLifecycleListener(
      onInactive: () {
        resumeOnFocus = !lab.clock.paused;
        lab.clock.paused = true;
        changed();
      },
      onResume: () {
        if (resumeOnFocus) lab.clock.paused = false;
        changed();
      },
    );
    lab.load().catchError((Object e, StackTrace stack) {
      debugPrint('$e\n$stack');
      if (mounted) setState(() => error = '$e');
    });
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    timer?.cancel();
    lifecycle?.dispose();
    detachMotionAutomation(lab);
    lab.removeListener(changed);
    lab.dispose();
    search.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: error != null
        ? Center(child: SelectableText('読み込みに失敗しました\n$error'))
        : !lab.ready
        ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('モデルとモーションを準備しています…'),
              ],
            ),
          )
        : Column(
            children: [
              header(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final sidebarWidth = constraints.maxWidth > 1000
                        ? 258.0
                        : 218.0;
                    return Row(
                      children: [
                        SizedBox(width: sidebarWidth, child: sidebar()),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(child: viewport()),
                              transport(),
                            ],
                          ),
                        ),
                        if (constraints.maxWidth >= 1150) ...[
                          const VerticalDivider(width: 1),
                          SizedBox(width: 246, child: inspector()),
                        ],
                      ],
                    );
                  },
                ),
              ),
              footer(),
            ],
          ),
  );

  Widget header() => Container(
    height: 86,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xff253444))),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.accessibility_new, color: accent),
        ),
        const SizedBox(width: 14),
        const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HUMAN MOTION LAB',
              style: TextStyle(
                color: accent,
                fontSize: 10,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'そば屋モーションラボ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const Spacer(),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('体格を比較'),
              icon: Icon(Icons.people_outline),
            ),
            ButtonSegment(
              value: true,
              label: Text('手法を比較'),
              icon: Icon(Icons.view_week_outlined),
            ),
          ],
          selected: {lab.compareMethods},
          onSelectionChanged: (v) => lab.layout(v.first),
        ),
        const SizedBox(width: 16),
        if (lab.compareMethods)
          DropdownButton<String>(
            value: lab.character,
            items: [
              for (final p in lab.profiles)
                DropdownMenuItem(value: p.id, child: Text(p.label)),
            ],
            onChanged: (v) {
              if (v != null) lab.setCharacter(v);
            },
          ),
      ],
    ),
  );

  Widget sidebar() {
    final query = search.text.trim().toLowerCase();
    final entries = lab.entries
        .where(
          (e) => '${e.label} ${e.name} ${e.category}'.toLowerCase().contains(
            query,
          ),
        )
        .toList();
    return Material(
      color: panel.withValues(alpha: .55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 20, 18, 10),
            child: Text(
              '01  アニメーションの手法',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ),
          for (final method in MotionMethod.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: Material(
                color: lab.method == method
                    ? const Color(0xff213c41)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  key: ValueKey('method-${method.name}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    search.clear();
                    lab.chooseMethod(method);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 28,
                          decoration: BoxDecoration(
                            color: lab.method == method
                                ? accent
                                : const Color(0xff344354),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                method.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: lab.method == method
                                      ? accent
                                      : Colors.white,
                                ),
                              ),
                              Text(
                                method.badge,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 9,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${lab.selectedBody.clips.where((e) => e.method == method).length}',
                          style: const TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 21, 18, 10),
            child: Text(
              '02  動作を選ぶ',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              key: const ValueKey('motion-search'),
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '歩行、会話、回避…',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text('一致する動作がありません', style: TextStyle(color: muted)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final e = entries[index];
                      return ListTile(
                        key: ValueKey('clip-${e.name}'),
                        dense: true,
                        selected: lab.action == e.action,
                        selectedColor: accent,
                        selectedTileColor: accent.withValues(alpha: .07),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        title: Text(e.label),
                        subtitle: Text(
                          '${e.category}  ·  ${e.duration.toStringAsFixed(2)} s',
                          style: const TextStyle(fontSize: 10, color: muted),
                        ),
                        trailing: Icon(
                          e.loop ? Icons.repeat : Icons.play_arrow,
                          size: 15,
                        ),
                        onTap: () {
                          lab.choose(e.action);
                          focus.requestFocus();
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${entries.length} clips  /  2 characters',
              style: const TextStyle(
                color: muted,
                fontSize: 10,
                letterSpacing: .5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget viewport() => Focus(
    focusNode: focus,
    autofocus: true,
    onKeyEvent: (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.space) {
        lab.togglePause();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        lab.seek(lab.clock.seconds + 1 / 30);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        lab.seek(lab.clock.seconds - 1 / 30);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: Stack(
      children: [
        Positioned.fill(
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) lab.zoom(event.scrollDelta.dy);
            },
            child: GestureDetector(
              onTap: () => focus.requestFocus(),
              onPanUpdate: (d) => lab.orbit(d.delta.dx, d.delta.dy),
              child: SceneView(
                lab.scene,
                key: const ValueKey('motion-viewport'),
                autoTick: !lab.clock.paused,
                cameraBuilder: (_) => lab.camera(),
                onTick: lab.tick,
                warmUp: true,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: SkeletonPainter(lab)),
          ),
        ),
        Positioned(
          top: 22,
          left: 22,
          right: 22,
          child: IgnorePointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    badge(lab.method.badge),
                    const SizedBox(width: 8),
                    badge('30 FPS', color: muted),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  lab.selected.label,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  lab.compareMethods
                      ? '同じ動作を、4つの手法で並べて確認'
                      : '同じ動作を、それぞれの身体に合わせて再生',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 72,
          left: 18,
          right: 18,
          child: IgnorePointer(
            child: Row(
              children: [
                for (final slot in lab.slots)
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: .82),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xff344558)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              lab.compareMethods
                                  ? slot.method.label
                                  : slot.profile.label,
                              style: TextStyle(
                                color: slot.entry == null ? muted : accent,
                                fontSize: lab.compareMethods ? 10 : 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              slot.entry == null
                                  ? 'この動作は未収録'
                                  : '${slot.profile.height.toStringAsFixed(2)} m  ·  ${slot.profile.bones} bones',
                              style: const TextStyle(
                                fontSize: 10,
                                color: muted,
                              ),
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
        Positioned(
          bottom: 18,
          left: 18,
          child: Wrap(
            spacing: 6,
            children: [
              for (final (id, label) in [
                ('front', '正面'),
                ('side', '側面'),
                ('back', '背面'),
              ])
                OutlinedButton(
                  key: ValueKey('view-$id'),
                  onPressed: () => lab.setView(id),
                  child: Text(label),
                ),
            ],
          ),
        ),
        Positioned(
          bottom: 22,
          right: 18,
          child: FilterChip(
            key: const ValueKey('skeleton-toggle'),
            label: const Text('骨格を表示'),
            selected: lab.skeleton,
            onSelected: lab.setSkeleton,
          ),
        ),
      ],
    ),
  );

  Widget transport() => Container(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
    color: panel,
    child: Column(
      children: [
        Row(
          children: [
            Text(
              '${lab.clock.seconds.toStringAsFixed(2)} s',
              style: const TextStyle(fontSize: 11, color: accent),
            ),
            Expanded(
              child: Slider(
                key: const ValueKey('timeline'),
                value: lab.clock.seconds.clamp(0, lab.duration),
                max: lab.duration,
                onChanged: lab.seek,
              ),
            ),
            Text(
              '${lab.duration.toStringAsFixed(2)} s',
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              key: const ValueKey('replay'),
              tooltip: '最初から',
              onPressed: lab.replay,
              icon: const Icon(Icons.replay),
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('play-pause'),
              onPressed: lab.togglePause,
              icon: Icon(lab.clock.paused ? Icons.play_arrow : Icons.pause),
              label: Text(lab.clock.paused ? '再生' : '一時停止'),
            ),
            IconButton(
              key: const ValueKey('frame-next'),
              tooltip: '1フレーム進む',
              onPressed: () => lab.seek(lab.clock.seconds + 1 / 30),
              icon: const Icon(Icons.skip_next),
            ),
            const SizedBox(width: 10),
            DropdownButton<double>(
              key: const ValueKey('playback-speed'),
              value: lab.clock.speed,
              items: [
                for (final speed in [.25, .5, 1.0, 1.5, 2.0])
                  DropdownMenuItem(value: speed, child: Text('${speed}x')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => lab.clock.speed = v);
              },
            ),
            const Spacer(),
            FilterChip(
              key: const ValueKey('repeat-toggle'),
              label: const Text('ループ'),
              selected: lab.clock.repeat,
              onSelected: (v) => setState(() => lab.clock.repeat = v),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'ON: 同じ周期の位置。OFF: 同じ経過秒数。',
              child: FilterChip(
                label: const Text('位相を同期'),
                selected: lab.syncPhase,
                onSelected: (v) => setState(() {
                  lab.syncPhase = v;
                  lab.pose();
                }),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget inspector() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'BODY & MOTION',
        style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1.6),
      ),
      const SizedBox(height: 18),
      Text(
        lab.method.label,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      Text(
        lab.method.description,
        style: const TextStyle(color: muted, fontSize: 12, height: 1.7),
      ),
      const SizedBox(height: 20),
      const Divider(),
      const SizedBox(height: 18),
      const Text('体格ごとの骨格', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      const Text(
        '見た目を拡大縮小せず、各モデルの関節間の長さを使用。',
        style: TextStyle(color: muted, fontSize: 11),
      ),
      const SizedBox(height: 16),
      for (final body in lab.profiles) ...[
        Text(
          body.label,
          style: TextStyle(
            color: body.id == 'sobaya' ? accent : const Color(0xffffc384),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        measurement('脚の長さ', body.leg),
        measurement('腕の長さ', body.arm),
        measurement('肩の幅', body.shoulder),
        const SizedBox(height: 15),
      ],
      const Divider(),
      const SizedBox(height: 16),
      const Text('接地のチェック', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      for (final body in lab.profiles)
        if (body.find(lab.method, lab.action)?.minSole != null) ...[
          Text(
            '${body.label}  ${(body.find(lab.method, lab.action)!.minSole! * 1000).toStringAsFixed(1)} mm',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 6),
        ],
      const Text(
        '全キーフレームの靴底の最低値。負の値は床へのめり込みです。足滑りの測定値ではありません。',
        style: TextStyle(color: muted, fontSize: 10, height: 1.6),
      ),
      const SizedBox(height: 20),
      const Divider(),
      const SizedBox(height: 16),
      const Text('素材', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(
        lab.method == MotionMethod.captured
            ? '既存のMixamo収録動作'
            : lab.method == MotionMethod.procedural
            ? '独自の数式・2ボーンIK'
            : 'Mesh2Motion / Quaternius\nCC0 1.0 · 改変・商用利用可',
        style: const TextStyle(color: muted, fontSize: 11, height: 1.7),
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        key: const ValueKey('copy-report'),
        onPressed: () async {
          await Clipboard.setData(
            ClipboardData(
              text: const JsonEncoder.withIndent('  ').convert(lab.inspect()),
            ),
          );
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('比較設定をJSONでコピーしました')));
          }
        },
        icon: const Icon(Icons.copy, size: 15),
        label: const Text('比較設定をコピー'),
      ),
    ],
  );

  Widget measurement(String label, double value) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: muted, fontSize: 11)),
        const Spacer(),
        Text(
          '${(value * 100).toStringAsFixed(1)} cm',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),
  );

  Widget badge(String text, {Color color = accent}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: ink.withValues(alpha: .75),
      border: Border.all(color: color.withValues(alpha: .4)),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 9, letterSpacing: 1),
    ),
  );
  Widget footer() => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: const Row(
      children: [
        Text(
          'SOBAYA HAZARD  /  ANIMATION WORKSPACE',
          style: TextStyle(color: muted, fontSize: 9, letterSpacing: 1),
        ),
        Spacer(),
        Text(
          'ドラッグ: 回転   スクロール: 距離   Space: 再生 / 停止   ← →: コマ送り',
          style: TextStyle(color: muted, fontSize: 10),
        ),
      ],
    ),
  );
}

/// Draw in screen space so the mesh cannot occlude the diagnostic skeleton.
class SkeletonPainter extends CustomPainter {
  SkeletonPainter(this.lab) : super(repaint: lab.poseSignal);
  final MotionController lab;
  @override
  void paint(Canvas canvas, Size size) {
    if (!lab.skeleton) return;
    final camera = lab.camera();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final slot in lab.slots) {
      if (slot.entry == null) continue;
      final paint = Paint()
        ..color = slot.profile.id == 'sobaya' ? accent : const Color(0xffffc384)
        ..strokeWidth = 1.5;
      for (final (a, b) in slot.boneLines) {
        final start = camera.worldToScreen(
          a.globalTransform.getTranslation(),
          size,
        );
        final end = camera.worldToScreen(
          b.globalTransform.getTranslation(),
          size,
        );
        if (start == null || end == null) continue;
        canvas.drawLine(start, end, paint);
        canvas.drawCircle(end, 2.3, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) =>
      oldDelegate.lab != lab;
}
