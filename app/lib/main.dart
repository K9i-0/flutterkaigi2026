import 'dart:math' as math;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_style.dart';
import 'entry_screen.dart';
import 'graphics_settings.dart';
import 'stage_benchmark.dart';
import 'balance.dart';
import 'fps_overlay.dart';
import 'gallery.dart';
import 'gallery_screen.dart';
import 'l10n.dart';
import 'ranking.dart';
import 'records.dart';
import 'settings_dialog.dart';
import 'tas.dart';

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
      recordOpen = false,
      resultOpen = false;
  GameRecord? lastRecord;
  String? error;
  double inputX = 0, inputY = 0, accumulator = 0, swipe = 0, pinchFrom = 1;
  // Frame-rate HUD toggled from the settings.
  bool showFps = false;

  /// TAS mode replays a perfect input from the next round; a round in it is
  /// [tasRound], and waits until [tasInputs] are found.
  bool tasMode = false, tasRound = false;
  List<int>? tasInputs;
  int tasFrame = 0, _tasToken = 0;
  Map<String, Object>? fpsStats;
  int lastEvent = 0;

  /// Debug override of the character's fixed layout; null plays the fixed one.
  int? seed;
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
          'tasMode': tasMode,
          'tasRound': tasRound,
          'tasReady': tasInputs != null,
          'tasFrame': tasFrame,
          'paused': paused,
          'lang': appLang.value.id,
          'lastRecord': lastRecord?.toMap(),
          if (lastRecord?.named ?? false)
            'lastRank': records.rankOf(lastRecord!),
          'resultOpen': resultOpen,
          'records': records.records.length,
          ...game.inspect(),
          if (ready) ...world.inspect(),
        }),
      );
      registerMarionetteExtension(
        name: 'madogiwa.catchAction',
        description: 'action=select|configure|start|demo|step|rotate|pause|resume|endPractice|zoom|record|ranking|lang|graphics|settings|tas|benchmark|fps. settings: tab=graphics|demo|balance opens the settings. tas: value=on|off, TAS mode from the next start. start: practice=true for the no-score mode. zoom: value=magnification (clamped to zoomMin..zoomMax). record: name answers the nickname dialog (omit to cancel); the result dialog opens it with its result_record button. ranking opens the records, tab=ranking|history. lang: value=ja|en. fps: value=on|off (debug FPS HUD). graphics: json booleans, persist=true optional. benchmark: label, timeOfDay. select: character ID and/or timeOfDay=day|night. configure: json settings, seed (an integer, or fixed for the character layout). step seconds 0..25 x/y -1..1. Demo supplies inputs only.',
        callback: (p) async {
          if (!ready) return MarionetteExtensionResult.error(1, 'Not ready');
          switch (p['action']) {
            case 'fps':
              await setFps(p['value'] == 'on');
            case 'tas':
              tasMode = p['value'] == 'on';
            case 'settings':
              openSettings(
                tab:
                    SettingsTab.values
                        .where((t) => t.name == p['tab'])
                        .firstOrNull ??
                    SettingsTab.graphics,
              );
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
            case 'zoom':
              final value = double.tryParse(p['value'] ?? '');
              if (value == null || !value.isFinite) {
                return MarionetteExtensionResult.invalidParams(
                  'value=magnification',
                );
              }
              setZoom(value);
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
              openRecords(
                highlight: lastRecord,
                tab: p['tab'] == 'history'
                    ? RecordsTab.history
                    : RecordsTab.ranking,
              );
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
                final raw = p['seed'];
                final nextSeed = raw == null || raw == 'fixed'
                    ? null
                    : int.tryParse(raw);
                if (raw != null &&
                    raw != 'fixed' &&
                    (nextSeed == null ||
                        nextSeed < 0 ||
                        nextSeed > 999999999)) {
                  return MarionetteExtensionResult.invalidParams(
                    'Invalid seed',
                  );
                }
                game.balance = next;
                if (raw != null) seed = nextSeed;
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
      showFps = (prefs.getBool('yumemi.debug.fps') ?? false);
      appLang.value =
          AppLang.values
              .where((l) => l.id == prefs.getString('yumemi.lang'))
              .firstOrNull ??
          AppLang.ja;
      await records.load();
      final saved = prefs.getString(balanceKey);
      if (saved != null) {
        try {
          final data = jsonDecode(saved) as Map<String, dynamic>;
          final values = Map<String, dynamic>.from(data['balance'] as Map);
          final b = Balance.fromMap(values);
          final n = data['seed'];
          if (n == null || (n is int && n >= 0 && n <= 999999999)) {
            game.balance = b;
            seed = n as int?;
          }
        } catch (_) {
          /* Invalid saved settings fall back to defaults. */
        }
      }
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
    // Seed 1 keeps measurements comparable; later rounds keep the override.
    final override = seed;
    seed = 1;
    game.balance = Balance.defaults();
    start();
    seed = override;
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

  /// v2 since the 100-point score; v1 held raw-point settings and seed 1.
  static const balanceKey = 'yumemi.balance.v2';

  Future<void> saveBalance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      balanceKey,
      jsonEncode({'seed': ?seed, 'balance': game.balance.values}),
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

  void setZoom(double value) {
    world.zoom = value.clamp(game.balance['zoomMin'], game.balance['zoomMax']);
  }

  Future<void> setLang(AppLang lang) async {
    appLang.value = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yumemi.lang', lang.id);
  }

  /// A finished scored round is saved to the history once, then its result
  /// dialog offers to record a nickname for the ranking.
  void checkRoundEnd() {
    if (recordPrompted ||
        game.practice ||
        game.phase != Phase.result ||
        benchmark?.active == true) {
      return;
    }
    recordPrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => showResult());
  }

  Future<void> showResult() async {
    if (!mounted) return;
    if (tasRound) {
      resultOpen = true;
      await showDialog<void>(
        context: context,
        builder: (_) => ResultDialog(
          record: GameRecord(
            name: '',
            score: game.score,
            character: game.roundCharacter,
            caught: game.caught,
            bad: game.bad,
            missed: game.missed,
            at: DateTime.now(),
          ),
        ),
      );
      resultOpen = false;
      return;
    }
    final record = GameRecord(
      name: '',
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
    resultOpen = true;
    final named = await showDialog<GameRecord>(
      context: context,
      builder: (_) =>
          ResultDialog(record: record, onRecord: () => nameRecord(record)),
    );
    resultOpen = false;
    if (named != null && mounted) await openRecords(highlight: named);
  }

  /// Nickname entry for [record]; null when cancelled.
  Future<GameRecord?> nameRecord(GameRecord record) async {
    recordOpen = true;
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          RecordDialog(score: record.score, character: record.character),
    );
    recordOpen = false;
    if (name == null || !mounted) return null;
    final named = await records.rename(record, name);
    if (identical(lastRecord, record)) lastRecord = named;
    if (mounted) setState(() {});
    return named;
  }

  Future<void> openRecords({
    GameRecord? highlight,
    RecordsTab tab = RecordsTab.ranking,
  }) => showDialog<void>(
    context: context,
    builder: (_) => RecordsDialog(
      store: records,
      initial: highlight?.character ?? game.selectedCharacter,
      highlight: highlight,
      tab: tab,
      onName: nameRecord,
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

  Future<void> openSettings({SettingsTab tab = SettingsTab.graphics}) async {
    final wasPaused = paused;
    final inRound =
        game.phase == Phase.playing || game.phase == Phase.countdown;
    setState(() => paused = true);
    final r = await showDialog<SettingsResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SettingsDialog(
        graphics: graphics,
        balance: game.balance,
        seed: seed,
        tas: tasMode,
        fps: showFps,
        inRound: inRound,
        tab: tab,
      ),
    );
    if (!mounted) return;
    if (r == null) {
      setState(() => paused = wasPaused);
      return;
    }
    if (r.fps != showFps) await setFps(r.fps);
    if (r.graphics != graphics) {
      graphics = r.graphics;
      world.lighting.graphics = graphics;
      world.update(game, 0);
      await saveGraphics();
    }
    final balanceChanged = !r.balance.sameAs(game.balance, seed);
    final tasChanged = r.tas != tasMode;
    tasMode = r.tas;
    if (balanceChanged) {
      game.balance = r.balance.balance;
      seed = r.balance.seed;
      await saveBalance();
    }
    if (!mounted) return;
    setState(() {
      if (inRound && (balanceChanged || tasChanged)) {
        start(practice: game.practice);
      } else {
        paused = wasPaused;
        world.update(game, 0);
      }
    });
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
    tasRound = tasMode && !practice;
    tasInputs = null;
    tasFrame = 0;
    if (tasRound) loadTas();
  }

  /// Finds the perfect input for the round that just started.
  Future<void> loadTas() async {
    final token = ++_tasToken;
    final inputs = await tasFor(game.roundCharacter, game.balance, seed: seed);
    if (!mounted || token != _tasToken || !tasRound) return;
    setState(() {
      tasInputs = inputs;
      if (inputs == null) tasRound = false;
    });
    if (inputs == null) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(L10n.of(context).tasNotFound)));
    }
  }

  void advance(double dt, double x, double y) {
    final inputs = tasInputs;
    if (tasRound && inputs != null && !demo) {
      // One TAS frame per 1/60 s step from the first playing step, turned to
      // where the camera will face during that step.
      var u = 0;
      if (game.phase == Phase.playing && tasFrame < inputs.length) {
        u = inputs[tasFrame++];
      }
      final s = tasInput(u, game.yawAfter(dt));
      x = s.x;
      y = s.y;
      inputX = x;
      inputY = y;
    }
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
    if (tasRound && tasInputs == null) {
      // Hold the countdown until the perfect input is found.
      world.update(game, dt.clamp(0, .1));
      refreshHud();
      return;
    }
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
      inputY = axis(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowUp);
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
              onRecords: openRecords,
              lang: appLang.value,
              onLang: setLang,
              onTitle: () => setState(() => showTitle = true),
              onSettings: openSettings,
              tas: tasMode,
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
                                if (tasRound) ...[
                                  chip(
                                    tasInputs == null
                                        ? t.tasSearching
                                        : t.tasBadge,
                                    color: gold,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                chip(
                                  t.secondsLeft(
                                    (game.roundSeconds - game.time).ceil(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                chip(t.points(game.score), color: gold),
                              ],
                              IconButton(
                                key: const ValueKey('settings_open'),
                                tooltip: t.settings,
                                onPressed: openSettings,
                                icon: const Icon(Icons.settings),
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
                        // Ready and result show the selection screen instead.
                        if (paused)
                          Center(
                            child: Container(
                              key: const ValueKey('round_menu'),
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
                                    t.paused,
                                    style: const TextStyle(
                                      fontSize: 27,
                                      fontWeight: FontWeight.bold,
                                      color: cream,
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  button(t.resume, () {
                                    paused = false;
                                    tilt.calibrate();
                                  }, 'resume'),
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
