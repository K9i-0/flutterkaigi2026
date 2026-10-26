import 'dart:math' as math;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_style.dart';
import 'entry_screen.dart';
import 'graphics_settings.dart';
import 'stage_benchmark.dart';
import 'balance.dart';
import 'balance_panel.dart';
import 'fps_overlay.dart';
import 'gallery.dart';
import 'gallery_screen.dart';
import 'l10n.dart';
import 'ranking.dart';
import 'records.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'catch_game.dart';
import 'character.dart';
import 'selection_screen.dart';
import 'catch_scene.dart';
import 'tilt_input.dart';

const gold = brandBlue, cream = brandInk, ink = Colors.white;

/// UI language, above the Navigator so dialogs translate too.
final appLang = ValueNotifier(AppLang.ja);
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
      theme: appTheme(),
      builder: (context, child) => ValueListenableBuilder(
        valueListenable: appLang,
        builder: (context, lang, _) =>
            L10n(strings: Strings(lang), child: child!),
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
  final game = CatchGame();
  final world = CatchScene(), tilt = TiltInput(), records = RecordStore();
  bool showTitle = true;

  /// Opened from the title only, so it never interrupts a round in progress.
  bool showGallery = false;
  final gallery = GalleryController();
  GraphicsSettings graphics = GraphicsSettings.standard;
  StageBenchmark? benchmark;
  bool ready = false,
      paused = false,
      demo = false,
      frozen = false,
          // The result of the current round was offered for the ranking.
          recordPrompted =
          false,
      recordOpen = false;
  GameRecord? lastRecord;
  String? error;
  double inputX = 0, inputY = 0, accumulator = 0, swipe = 0, pinchFrom = 1;
  // Debug/profile only: frame-rate HUD toggled from the debug panel.
  bool showFps = false;
  Map<String, Object>? fpsStats;
  int lastEvent = 0, seed = 1;
  Object? _hudState;

  void refreshHud() {
    final next = (
      game.phase,
      (game.roundSeconds - game.time).ceil(),
      game.countdown.ceil(),
      game.score,
      game.combo,
      game.time < game.messageUntil ? game.message : null,
      game.caught,
      game.bad,
      game.missed,
      game.eventId,
      game.practice,
    );
    if (mounted && next != _hudState) {
      _hudState = next;
      setState(() {});
    }
  }

  AppLifecycleListener? lifecycle;
  @override
  void initState() {
    super.initState();
    tilt.start();
    if (kDebugMode || const bool.fromEnvironment('STAGE_BENCHMARK')) {
      benchmark = StageBenchmark();
    }
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
          'screen': showGallery
              ? 'gallery'
              : showTitle
              ? 'title'
              : !ready
              ? 'loading'
              : game.phase.name,
          'error': error,
          'graphics': graphics.toMap(),
          'showFps': showFps,
          if (fpsStats != null) 'fpsStats': fpsStats,
          'benchmark': benchmark?.inspect(),
          'sensor': tilt.available,
          'demo': demo,
          'paused': paused,
          'lang': appLang.value.id,
          'lastRecord': lastRecord?.toMap(),
          if (lastRecord != null) 'lastRank': records.rankOf(lastRecord!),
          'records': records.records.length,
          ...game.inspect(),
          if (ready) ...world.inspect(),
        }),
      );
      registerMarionetteExtension(
        name: 'madogiwa.catchAction',
        description: 'action=select|configure|start|demo|step|rotate|pause|resume|endPractice|control|zoom|record|ranking|lang|graphics|benchmark|fps. start: practice=true for the no-score mode. control: value=fixed|camera. zoom: value=magnification (clamped to zoomMin..zoomMax), pivot=bridge|character. record: name answers the nickname dialog (omit to skip). ranking opens the board. lang: value=ja|en. fps: value=on|off (debug FPS HUD). graphics: json booleans, persist=true optional. benchmark: label, timeOfDay. select: character ID and/or timeOfDay=day|night. configure: json settings, seed. step seconds 0..25 x/y -1..1. Demo supplies inputs only.',
        callback: (p) async {
          if (!ready) return MarionetteExtensionResult.error(1, 'Not ready');
          switch (p['action']) {
            case 'fps':
              await setFps(p['value'] == 'on');
            case 'lang':
              final lang = AppLang.values
                  .where((l) => l.id == p['value'])
                  .firstOrNull;
              if (lang == null) {
                return MarionetteExtensionResult.invalidParams('value=ja|en');
              }
              await setLang(lang);
            case 'endPractice':
              endPractice();
            case 'control':
              final mode = ControlMode.values
                  .where((m) => m.id == p['value'])
                  .firstOrNull;
              if (mode == null) {
                return MarionetteExtensionResult.invalidParams(
                  'value=fixed|camera',
                );
              }
              await setControl(mode);
            case 'zoom':
              final pivot = ZoomPivot.values
                  .where((z) => z.id == p['pivot'])
                  .firstOrNull;
              final value = double.tryParse(p['value'] ?? '');
              if ((p['pivot'] != null && pivot == null) ||
                  (p['value'] != null && (value == null || !value.isFinite))) {
                return MarionetteExtensionResult.invalidParams(
                  'value=magnification, pivot=bridge|character',
                );
              }
              if (pivot != null) await setPivot(pivot);
              if (value != null) setZoom(value);
              world.update(game, 0);
            case 'record':
              // Answers the open nickname dialog; omit name to skip.
              if (!recordOpen) {
                return MarionetteExtensionResult.invalidParams(
                  'No nickname dialog is open',
                );
              }
              final name = p['name']?.trim() ?? '';
              Navigator.of(context).pop(name.isEmpty ? null : name);
            case 'ranking':
              openRanking(highlight: lastRecord);
            case 'graphics':
              final data =
                  jsonDecode(p['json'] ?? '{}') as Map<String, dynamic>;
              graphics = GraphicsSettings.fromMap({
                ...graphics.toMap(),
                ...data,
              });
              world.lighting.graphics = graphics;
              world.update(game, 0);
              if (p['persist'] == 'true') await saveGraphics();
            case 'benchmark':
              runBenchmark(
                p['label'] ?? 'stage',
                p['timeOfDay'] == 'night' ? StageTime.night : StageTime.day,
                character: CatchCharacter.values
                    .where((c) => c.id == p['character'])
                    .firstOrNull,
              );
              // Diagnostic ablations only; normal gameplay restores visibility.
              if (p['hide'] == 'stage') world.lighting.stage.visible = false;
              if (p['hide'] == 'character') {
                for (final n in world.characters.values) {
                  n.visible = false;
                }
              }
              if (p['hide'] == 'items') {
                for (final slot in world.dropSlots) {
                  for (final item in slot) {
                    item.root.visible = false;
                  }
                }
              }
              if (p['hide'] == 'all3d') {
                world.lighting.stage.visible = false;
                for (final n in world.characters.values) {
                  n.visible = false;
                }
                for (final slot in world.dropSlots) {
                  for (final item in slot) {
                    item.root.visible = false;
                  }
                }
              }
              benchmark?.metadata['hide'] = p['hide'] ?? 'none';
              world.applyRenderProbe(p);
              world.lighting.setTrafficVisible(p['hide'] != 'traffic');
              benchmark?.metadata['animateTraffic'] =
                  p['animateTraffic'] == 'true';
              benchmark?.metadata['animateGameplay'] =
                  p['animateGameplay'] == 'true';
              benchmark?.metadata['orbit'] = p['orbit'] == 'true';
              benchmark?.metadata['probe'] = {
                for (final key in [
                  'aa',
                  'scale',
                  'cascades',
                  'shadowDistance',
                  'shadowSize',
                ])
                  if (p.containsKey(key)) key: p[key],
              };
            case 'select':
              showTitle = false;
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
              start(practice: p['practice'] == 'true');
              frozen = true;
            case 'demo':
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
              checkRoundEnd();
            default:
              return MarionetteExtensionResult.invalidParams('Unknown action');
          }
          setState(() {});
          return MarionetteExtensionResult.success(game.inspect());
        },
      );
      registerMarionetteExtension(
        name: 'madogiwa.inspectGallery',
        description: 'Inspect the gallery tab, subject, orbit camera and clip.',
        callback: (p) async => MarionetteExtensionResult.success({
          'open': showGallery,
          ...gallery.inspect(),
        }),
      );
      registerMarionetteExtension(
        name: 'madogiwa.galleryAction',
        description: 'action=open|close|tab|select|orbit|zoom|pan|focus|reset|clip|play|autoRotate|dark|billboard. tab: value=models|billboards. select: subject id (inspectGallery.subjects). orbit: yaw/pitch degrees (absolute). zoom: distance (absolute, clamped). pan: x/y/z offset. focus: world x/y/z (stage glide, optional distance). clip: value=clip name. play/autoRotate/dark: value=on|off. billboard: index into the list, or close.',
        callback: (p) async {
          final on = p['value'] == 'on';
          double? number(String key) {
            final v = double.tryParse(p[key] ?? '');
            return v != null && v.isFinite ? v : null;
          }

          switch (p['action']) {
            case 'open':
              openGallery();
            case 'close':
              showGallery = false;
            case 'tab':
              final tab = GalleryTab.values
                  .where((g) => g.id == p['value'])
                  .firstOrNull;
              if (tab == null) {
                return MarionetteExtensionResult.invalidParams(
                  'value=models|billboards',
                );
              }
              gallery.setTab(tab);
            case 'select':
              final subject = GallerySubject.byId(p['subject']);
              if (subject == null) {
                return MarionetteExtensionResult.invalidParams(
                  'Unknown subject',
                );
              }
              gallery
                ..tab = GalleryTab.models
                ..select(subject);
            case 'orbit':
              final yaw = number('yaw'), pitch = number('pitch');
              if (yaw == null && pitch == null) {
                return MarionetteExtensionResult.invalidParams(
                  'yaw and/or pitch in degrees',
                );
              }
              gallery.orbit(
                yaw == null ? 0 : yaw * math.pi / 180 - gallery.yaw,
                pitch == null ? 0 : pitch * math.pi / 180 - gallery.pitch,
              );
              gallery.autoRotate = false;
            case 'zoom':
              final distance = number('distance');
              if (distance == null || distance <= 0) {
                return MarionetteExtensionResult.invalidParams('distance > 0');
              }
              gallery.zoom(gallery.distance / distance);
            case 'pan':
              gallery.pan
                ..x = number('x') ?? gallery.pan.x
                ..y = number('y') ?? gallery.pan.y
                ..z = number('z') ?? gallery.pan.z;
            case 'focus':
              final x = number('x'), y = number('y'), z = number('z');
              if (x == null || y == null || z == null) {
                return MarionetteExtensionResult.invalidParams('x, y, z');
              }
              gallery.focus(vm.Vector3(x, y, z), distance: number('distance'));
            case 'reset':
              gallery.reset();
            case 'clip':
              if (!gallery.clips.contains(p['value'])) {
                return MarionetteExtensionResult.invalidParams(
                  'value=${gallery.clips.join('|')}',
                );
              }
              gallery
                ..clip = p['value']
                ..playing = true;
            case 'play':
              gallery.playing = on;
            case 'autoRotate':
              gallery.autoRotate = on;
            case 'dark':
              gallery.dark = on;
            case 'billboard':
              gallery.tab = GalleryTab.billboards;
              final list = await billboardCatalog;
              final index = int.tryParse(p['value'] ?? '');
              if (p['value'] != 'close' &&
                  (index == null || index < 0 || index >= list.length)) {
                return MarionetteExtensionResult.invalidParams(
                  'value=0..${list.length - 1}|close',
                );
              }
              gallery.showBillboard(index);
            default:
              return MarionetteExtensionResult.invalidParams('Unknown action');
          }
          gallery.idle = 0;
          setState(() {});
          return MarionetteExtensionResult.success(gallery.inspect());
        },
      );
    }
  }

  void openGallery() {
    showTitle = true;
    showGallery = true;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentVisual = prefs.getString('yumemi.graphics.v2');
      final visual = currentVisual ?? prefs.getString('yumemi.graphics.v1');
      if (visual != null) {
        try {
          final options = jsonDecode(visual) as Map<String, dynamic>;
          // Adopt the new smooth default once, retaining individual effects.
          if (currentVisual == null) options['fullResolution'] = false;
          graphics = GraphicsSettings.fromMap(options);
        } catch (_) {}
      }
      if (currentVisual == null) {
        await prefs.setString(
          'yumemi.graphics.v2',
          jsonEncode(graphics.toMap()),
        );
      }
      showFps = !kReleaseMode && (prefs.getBool('yumemi.debug.fps') ?? false);
      appLang.value =
          AppLang.values
              .where((l) => l.id == prefs.getString('yumemi.lang'))
              .firstOrNull ??
          AppLang.ja;
      await records.load();
      // Booth defaults since 2026-10-21; v2 keys drop the earlier trial picks.
      game.controlMode =
          ControlMode.values
              .where((m) => m.id == prefs.getString('yumemi.debug.control.v2'))
              .firstOrNull ??
          ControlMode.camera;
      world.zoomPivot =
          ZoomPivot.values
              .where(
                (z) => z.id == prefs.getString('yumemi.debug.zoomPivot.v2'),
              )
              .firstOrNull ??
          ZoomPivot.character;
      final saved = prefs.getString('beerRain.balance.v1');
      if (saved != null) {
        try {
          final data = jsonDecode(saved) as Map<String, dynamic>;
          final values = Map<String, dynamic>.from(data['balance'] as Map);
          // The old 70-110 degree default kept drops facing along the beam;
          // saves still on it adopt the all-around default.
          if (values['facingMin'] == 70 && values['facingMax'] == 110) {
            values
              ..remove('facingMin')
              ..remove('facingMax');
          }
          // 2.5x was the first trial's upper bound; 5x shows character detail.
          if (values['zoomMax'] == 2.5) values.remove('zoomMax');
          final b = Balance.fromMap(values);
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
      world.lighting.graphics = graphics;
      world.update(game, 0);
      if (mounted) {
        setState(() {
          ready = true;
          if (const bool.fromEnvironment('STAGE_BENCHMARK')) {
            graphics = const String.fromEnvironment('STAGE_QUALITY') == 'light'
                ? GraphicsSettings.light
                : GraphicsSettings.standard;
            world.lighting.graphics = graphics;
            runBenchmark(
              'automatic',
              const String.fromEnvironment('STAGE_TIME') == 'night'
                  ? StageTime.night
                  : StageTime.day,
            );
          }
        });
      }
    } catch (e, st) {
      debugPrint('$e\n$st');
      if (mounted) setState(() => error = '$e');
    }
  }

  void runBenchmark(String label, StageTime time, {CatchCharacter? character}) {
    // Fixed snapshot; render loop continues, simulation and camera stay fixed.
    game.phase = Phase.ready;
    game.selectCharacter(character ?? CatchCharacter.ctoOdatetsu);
    game.selectTime(time);
    seed = 1;
    game.balance = Balance.defaults();
    start();
    world.clock = 0;
    world.facing = math.pi;
    for (var i = 0; i < 480; i++) {
      advance(1 / 60, 0, 0);
      world.update(game, 1 / 60);
    }
    frozen = true;
    benchmark?.start({
      'label': label,
      'graphics': graphics.toMap(),
      'timeOfDay': time.id,
      'character': game.roundCharacter.id,
    });
  }

  Future<void> saveGraphics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yumemi.graphics.v2', jsonEncode(graphics.toMap()));
  }

  Future<void> openGraphics() async {
    final wasPaused = paused;
    setState(() => paused = true);
    final selected = await showDialog<GraphicsSettings>(
      context: context,
      builder: (_) => GraphicsDialog(initial: graphics),
    );
    if (!mounted) return;
    setState(() {
      paused = wasPaused;
      if (selected != null) {
        graphics = selected;
        world.lighting.graphics = graphics;
        world.update(game, 0);
      }
    });
    if (selected != null) await saveGraphics();
  }

  Future<void> saveBalance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'beerRain.balance.v1',
      jsonEncode({'seed': seed, 'balance': game.balance.values}),
    );
  }

  Future<void> setFps(bool value) async {
    setState(() {
      showFps = value;
      if (!value) fpsStats = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('yumemi.debug.fps', value);
  }

  Future<void> setControl(ControlMode mode) async {
    setState(() => game.controlMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yumemi.debug.control.v2', mode.id);
  }

  Future<void> setPivot(ZoomPivot pivot) async {
    setState(() => world.zoomPivot = pivot);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yumemi.debug.zoomPivot.v2', pivot.id);
  }

  void setZoom(double value) {
    world.zoom = value.clamp(game.balance['zoomMin'], game.balance['zoomMax']);
  }

  Future<void> setLang(AppLang lang) async {
    appLang.value = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yumemi.lang', lang.id);
  }

  /// A finished scored round asks once for a nickname, then shows the board.
  void checkRoundEnd() {
    if (recordPrompted ||
        game.practice ||
        game.phase != Phase.result ||
        benchmark?.active == true) {
      return;
    }
    recordPrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => promptRecord());
  }

  Future<void> promptRecord() async {
    if (!mounted) return;
    recordOpen = true;
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          RecordDialog(score: game.score, character: game.roundCharacter),
    );
    recordOpen = false;
    if (name == null || !mounted) return;
    final record = GameRecord(
      name: name,
      score: game.score,
      character: game.roundCharacter,
      caught: game.caught,
      bad: game.bad,
      missed: game.missed,
      at: DateTime.now(),
    );
    await records.add(record);
    if (!mounted) return;
    setState(() => lastRecord = record);
    await openRanking(highlight: record);
  }

  Future<void> openRanking({GameRecord? highlight}) => showDialog<void>(
    context: context,
    builder: (_) => RankingDialog(
      store: records,
      initial: highlight?.character ?? game.selectedCharacter,
      highlight: highlight,
    ),
  );

  void endPractice() {
    game
      ..practice = false
      ..phase = Phase.ready
      ..drops.clear();
    paused = false;
    frozen = false;
    world.update(game, 0);
  }

  Future<void> openBalance() async {
    final wasPaused = paused;
    setState(() => paused = true);
    final selected = await showDialog<BalanceSelection>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BalancePanel(
        balance: game.balance,
        seed: seed,
        showFps: showFps,
        onFps: setFps,
        controlMode: game.controlMode,
        onControl: setControl,
        zoomPivot: world.zoomPivot,
        onPivot: setPivot,
      ),
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

  void start({bool practice = false}) {
    showTitle = false;
    game.practice = practice;
    recordPrompted = false;
    lastRecord = null;
    world.zoom = 1;
    world.lighting.setTrafficVisible(true);
    world.applyRenderProbe({});
    game.start(seed: seed);
    tilt.maxDegrees = game.balance['tiltDegrees'];
    tilt.calibrate();
    inputX = 0;
    inputY = 0;
    accumulator = 0;
    lastEvent = 0;
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
    }
    if (demo && game.time > 3) {
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
      if (game.message == GameMessage.bad) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }
  }

  void tick(Duration elapsed, double dt) {
    if (frozen &&
        benchmark?.active == true &&
        benchmark?.metadata['animateGameplay'] == true) {
      accumulator += dt.clamp(0, .1);
      while (accumulator >= 1 / 60) {
        if (game.time >= 16) {
          game.start(seed: 1);
          for (var i = 0; i < 480; i++) {
            game.tick(1 / 60);
          }
        }
        if (benchmark?.metadata['orbit'] == true) {
          game.targetYaw = math.sin(game.time * .8) * math.pi / 3;
        }
        game.tick(1 / 60, inputX: math.sin(game.time * 1.3) * .65);
        accumulator -= 1 / 60;
      }
      world.update(game, dt.clamp(0, .1));
      refreshHud();
    }
    if (frozen &&
        benchmark?.active == true &&
        benchmark?.metadata['animateTraffic'] == true) {
      world.clock += dt.clamp(0, .1);
      world.lighting.update(world.clock);
    }
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
      inputY = game.controlMode == ControlMode.fixed
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
    checkRoundEnd();
    refreshHud();
  }

  @override
  void dispose() {
    benchmark?.dispose();
    tilt.dispose();
    lifecycle?.dispose();
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
  String messageText(Strings t) => switch (game.message) {
    GameMessage.hint => t.hint(game.roundCharacter),
    GameMessage.caught => t.niceCatch(game.messagePoints),
    GameMessage.bad => t.wrongCatch(game.messageKind!, game.messagePoints),
  };
  Widget legend() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      chip(
        '${game.roundCharacter.goodDrops.first.label} +${game.balance['beerPoints'].round()}〜',
        color: gold,
      ),
      const SizedBox(width: 6),
      chip(
        '${game.roundCharacter.badDrop.label} −${game.balance['penalty'].round()}',
        color: const Color(0xff8052a0),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, size) {
          if (ready) {
            final longestSide = View.of(context).physicalSize.longestSide;
            if (world.lighting.viewportLongestSide != longestSide) {
              world.lighting.viewportLongestSide = longestSide;
              world.lighting.configureRenderer(world.scene);
            }
          }
          if (showGallery) {
            if (!ready) {
              return error == null
                  ? const BrandLoading()
                  : Center(child: Text(error!));
            }
            return GalleryScreen(
              controller: gallery,
              world: world,
              game: game,
              onTime: (time) => setState(() {
                game.selectTime(time);
                world.update(game, 0);
              }),
              onBack: () => setState(() => showGallery = false),
            );
          }
          if (showTitle) {
            return TitleScreen(
              onStart: () => setState(() => showTitle = false),
              onGallery: () => setState(openGallery),
              lang: appLang.value,
              onLang: setLang,
            );
          }
          if (!ready && error == null) return const BrandLoading();
          // Dialogs pause the game but keep this screen behind them.
          if (ready &&
              (game.phase == Phase.ready || game.phase == Phase.result)) {
            return SelectionScreen(
              game: game,
              world: world,
              onSelect: (character) => setState(() {
                game.selectCharacter(character);
                world.update(game, 0);
              }),
              onTime: (time) => setState(() {
                game.selectTime(time);
                world.update(game, 0);
              }),
              onStart: () => setState(start),
              onPractice: () => setState(() => start(practice: true)),
              onRanking: openRanking,
              lang: appLang.value,
              onLang: setLang,
              onTitle: () => setState(() => showTitle = true),
              rank: lastRecord == null
                  ? null
                  : t.rankOf(
                      records.rankOf(lastRecord!),
                      records.ranking(lastRecord!.character).length,
                    ),
              onSettings: kReleaseMode ? null : openBalance,
              onGraphics: openGraphics,
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
                    // One finger swipes the camera around; two fingers pinch.
                    onScaleStart: (_) {
                      swipe = 0;
                      pinchFrom = world.zoom;
                    },
                    onScaleUpdate: (e) {
                      if (!playing) return;
                      if (e.pointerCount >= 2) {
                        swipe = 0;
                        setZoom(pinchFrom * e.scale);
                        return;
                      }
                      swipe += e.focalPointDelta.dx;
                      if (swipe.abs() < 60) return;
                      setState(() => game.rotate(swipe < 0 ? 1 : -1));
                      swipe = 0;
                    },
                    child: RepaintBoundary(
                      child: SceneView(
                        world.scene,
                        camera: world.camera,
                        onTick: tick,
                      ),
                    ),
                  ),
                ),
              if (ready)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _BadCatchFlash(
                      eventId: game.eventId,
                      bad: game.fxBad,
                    ),
                  ),
                ),
              if (error != null) Center(child: Text(error!)),
              if (!ready && error == null) const BrandLoading(),
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
                                t.appTitle,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(blurRadius: 8)],
                                ),
                              ),
                              Text(
                                t.player(
                                  t.character(
                                    playing
                                        ? game.roundCharacter
                                        : game.selectedCharacter,
                                  ),
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(blurRadius: 6, color: Colors.black),
                                  ],
                                  fontSize: 12,
                                ),
                              ),
                              if (game.practice)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: chip(t.practiceBadge, color: gold),
                                ),
                            ],
                          ),
                        ),
                        if (showFps)
                          Positioned(
                            left: 0,
                            bottom: 0,
                            child: FpsOverlay(
                              onStats: (s) => fpsStats = s.toMap(),
                            ),
                          ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Row(
                            children: [
                              if (game.practice) ...[
                                FilledButton(
                                  key: const ValueKey('end_practice'),
                                  onPressed: () => setState(endPractice),
                                  child: Text(t.endPractice),
                                ),
                              ] else ...[
                                chip(
                                  t.secondsLeft(
                                    (game.roundSeconds - game.time).ceil(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                chip('${game.score} pt', color: gold),
                              ],
                              IconButton(
                                key: const ValueKey('graphics_settings'),
                                tooltip: t.graphics,
                                onPressed: openGraphics,
                                icon: const Icon(Icons.display_settings),
                              ),
                              if (!kReleaseMode)
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
                            ],
                          ),
                        ),
                        if (playing)
                          Positioned(
                            left: 0,
                            width: 175,
                            top: game.practice ? 100 : 62,
                            child: Center(
                              child: game.phase == Phase.countdown
                                  ? chip(
                                      t.countdown(game.countdown.ceil()),
                                      color: gold,
                                    )
                                  : game.time < game.messageUntil
                                  ? chip(
                                      messageText(t),
                                      color: game.message == GameMessage.bad
                                          ? const Color(0xffb63c32)
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
                                          ? t.paused
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
                                        '足場は細い鉄骨一本。左右に傾けて歩こう。\n缶の向きはばらばら。カメラで表ラベルを見て、発泡酒を避けろ！',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.6,
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    if (!paused) legend(),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        button(
                                          paused
                                              ? t.resume
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
}

/// Edge flash for a bad catch. Ignores pointers so tilt and swipes still land
/// on the scene underneath.
class _BadCatchFlash extends StatefulWidget {
  const _BadCatchFlash({required this.eventId, required this.bad});
  final int eventId;
  final bool bad;

  @override
  State<_BadCatchFlash> createState() => _BadCatchFlashState();
}

class _BadCatchFlashState extends State<_BadCatchFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );

  @override
  void didUpdateWidget(_BadCatchFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.eventId != oldWidget.eventId && widget.bad) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.status == AnimationStatus.dismissed) {
          return const SizedBox.shrink();
        }
        final fade = 1 - _controller.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                const Color(0x00b63c32),
                const Color(0xffb63c32).withValues(alpha: .5 * fade),
              ],
              stops: const [.52, 1],
            ),
          ),
        );
      },
    );
  }
}
