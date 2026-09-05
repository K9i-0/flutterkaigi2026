import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show SceneView;

import 'game_controller.dart';
import 'game_state.dart';
import 'game_dialogue.dart';
import 'game_settings.dart';
import 'game_automation.dart';
import 'game_benchmark.dart';

const ivory = Color(0xffe6dec6),
    gold = Color(0xffc8b077),
    ink = Color(0xf0181b17);

class HazardGamePage extends StatefulWidget {
  const HazardGamePage({super.key});
  @override
  State<HazardGamePage> createState() => _HazardGamePageState();
}

class _HazardGamePageState extends State<HazardGamePage> {
  final game = HazardGameController();
  final focus = FocusNode();
  final held = <LogicalKeyboardKey>{};
  GameBenchmark? benchmark;
  String? error;
  AppLifecycleListener? lifecycle;
  double touchX = 0, touchY = 0;
  bool rightMouseHeld = false;
  @override
  void initState() {
    super.initState();
    game.addListener(changed);
    SchedulerBinding.instance.addTimingsCallback(record);
    game
        .load()
        .then((_) {
          if (!mounted) return;
          attachGameAutomation(game);
          if (const bool.fromEnvironment('HAZARD_GAME_BENCHMARK')) {
            benchmark = GameBenchmark(game);
          }
          setState(() {});
        })
        .catchError((Object e) {
          if (mounted) setState(() => error = e.toString());
        });
    lifecycle = AppLifecycleListener(
      onResume: () {
        game.setForeground(true);
      },
      onInactive: () {
        game.setForeground(false);
        held.clear();
        game.state?.stopInput();
        if (game.state?.running ?? false) game.toggle(PlayPhase.paused);
      },
    );
  }

  void record(List<ui.FrameTiming> timings) {
    if (!game.ready) return;
    for (final t in timings) {
      game.frames.add(
        t.buildDuration.inMicroseconds / 1000,
        t.rasterDuration.inMicroseconds / 1000,
      );
    }
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(record);
    detachGameAutomation();
    game.removeListener(changed);
    benchmark?.dispose();
    game.dispose();
    lifecycle?.dispose();
    focus.dispose();
    super.dispose();
  }

  void updateInput() {
    final s = game.state;
    if (s == null) return;
    bool has(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
        held.contains(a) || held.contains(b);
    s.inputX =
        ((has(LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight) ? 1 : 0) -
                (has(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft)
                    ? 1
                    : 0) +
                touchX)
            .clamp(-1, 1)
            .toDouble();
    s.inputY =
        ((has(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp) ? 1 : 0) -
                (has(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown)
                    ? 1
                    : 0) +
                touchY)
            .clamp(-1, 1)
            .toDouble();
    s.sprint =
        held.contains(LogicalKeyboardKey.shiftLeft) ||
        held.contains(LogicalKeyboardKey.shiftRight);
  }

  KeyEventResult onKey(FocusNode node, KeyEvent e) {
    final s = game.state!;
    if (e is KeyUpEvent) {
      held.remove(e.logicalKey);
      updateInput();
      return KeyEventResult.handled;
    }
    held.add(e.logicalKey);
    updateInput();
    if (e is KeyRepeatEvent) return KeyEventResult.handled;
    final k = e.logicalKey;
    if (s.phase == PlayPhase.cinematic) {
      if (k == LogicalKeyboardKey.escape) {
        game.director!.paused = !game.director!.paused;
        setState(() {});
      } else if (k == LogicalKeyboardKey.keyE ||
          k == LogicalKeyboardKey.space) {
        game.advanceEvent();
      }
      return KeyEventResult.handled;
    }
    if (s.phase == PlayPhase.settings) {
      if (k == LogicalKeyboardKey.escape) game.closeSettings();
      return KeyEventResult.handled;
    }
    if (s.phase == PlayPhase.title) return KeyEventResult.ignored;
    if (s.phase == PlayPhase.dialogue) {
      if (k == LogicalKeyboardKey.escape) s.endDialogue();
      if (k == LogicalKeyboardKey.keyE || k == LogicalKeyboardKey.space) {
        if (s.dialogueChoices) {
          s.endDialogue();
        } else {
          s.advanceDialogue();
        }
      }
      setState(() {});
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      game.toggle(PlayPhase.paused);
    } else if (k == LogicalKeyboardKey.tab) {
      game.toggle(PlayPhase.inventory);
    } else if (k == LogicalKeyboardKey.keyM) {
      game.toggle(PlayPhase.mapView);
    } else if (k == LogicalKeyboardKey.keyC) {
      game.toggle(PlayPhase.collection);
    } else if (s.running) {
      if (k == LogicalKeyboardKey.keyQ) {
        s.aiming = !s.aiming;
      } else if (k == LogicalKeyboardKey.space) {
        game.fire();
      } else if (k == LogicalKeyboardKey.keyR) {
        s.reload();
      } else if (k == LogicalKeyboardKey.keyE) {
        s.interact();
      } else if (k == LogicalKeyboardKey.keyH) {
        s.heal();
      } else if (k == LogicalKeyboardKey.keyX) {
        s.evade();
      } else if (k == LogicalKeyboardKey.keyF) {
        s.kick();
      } else if (k == LogicalKeyboardKey.digit1) {
        s.equip('handgun');
      } else if (k == LogicalKeyboardKey.digit2) {
        s.equip('shotgun');
      }
    }
    setState(() {});
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final s = game.state;
    return Scaffold(
      body: error != null
          ? Center(child: SelectableText('読み込みに失敗しました\n$error'))
          : !game.ready || s == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'S O B A Y A   H A Z A R D',
                    style: TextStyle(color: gold, fontSize: 24),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: gold),
                  SizedBox(height: 18),
                  Text('村の記録を読み込んでいます…'),
                ],
              ),
            )
          : Focus(
              focusNode: focus,
              autofocus: true,
              onKeyEvent: onKey,
              onFocusChange: (value) {
                if (!value) {
                  held.clear();
                  touchX = 0;
                  touchY = 0;
                  s.stopInput();
                }
              },
              child: LayoutBuilder(
                builder: (context, bounds) {
                  game.viewport = Size(bounds.maxWidth, bounds.maxHeight);
                  game.devicePixelRatio = View.of(context).devicePixelRatio;
                  return Stack(
                    children: [
                      Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) {
                          focus.requestFocus();
                          if (!s.running) return;
                          if (e.buttons & kSecondaryMouseButton != 0) {
                            rightMouseHeld = true;
                            s.aiming = true;
                          }
                          if (e.buttons & kPrimaryMouseButton != 0 &&
                              s.aiming) {
                            game.fire();
                          }
                        },
                        onPointerUp: (e) {
                          if (e.kind == PointerDeviceKind.mouse &&
                              rightMouseHeld &&
                              e.buttons & kSecondaryMouseButton == 0) {
                            rightMouseHeld = false;
                            s.aiming = false;
                          }
                        },
                        onPointerMove: (e) {
                          if (s.running) game.rotate(e.delta.dx, e.delta.dy);
                        },
                        child: SceneView(
                          game.scene,
                          cameraBuilder: (_) => game.camera(),
                          onTick: (elapsed, delta) {
                            benchmark?.tick();
                            game.tick(elapsed, delta);
                          },
                          warmUp: true,
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
                                  Color(0x88101510),
                                  Colors.transparent,
                                  Colors.transparent,
                                  Color(0xbb101510),
                                ],
                                stops: [0, .24, .67, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (s.phase != PlayPhase.title &&
                          s.phase != PlayPhase.dialogue &&
                          s.phase != PlayPhase.settings &&
                          s.phase != PlayPhase.cinematic) ...[
                        Positioned(
                          left: 28,
                          top: 26,
                          child: IgnorePointer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.chapterLabel,
                                  style: TextStyle(
                                    color: gold,
                                    fontSize: 12,
                                    letterSpacing: 3,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  s.subtitle,
                                  style: TextStyle(
                                    color: ivory,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                for (final boss in s.enemies.where(
                                  (e) =>
                                      e.boss &&
                                      e.alive &&
                                      e.active &&
                                      e.alerted,
                                ))
                                  SizedBox(
                                    width: 300,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 12),
                                        Text(
                                          '最終そば屋  —  ${boss.bossCue}',
                                          style: const TextStyle(
                                            color: gold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        LinearProgressIndicator(
                                          value: (boss.hp / 350).clamp(
                                            0.0,
                                            1.0,
                                          ),
                                          color: gold,
                                          backgroundColor: ink,
                                          minHeight: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Text(
                                  s.objective,
                                  style: const TextStyle(
                                    color: ivory,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 24,
                          top: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: const Color(0xbb151a15),
                                  border: Border.all(
                                    color: const Color(0x558f947d),
                                  ),
                                ),
                                child: CustomPaint(
                                  painter: VillageMapPainter(s),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '記録 ${s.collected.length} / ${s.gallery.length}    ビール ${s.beers}${s.zoneId == 'farm' ? '\n青いメダリオン ${s.medallions.length} / 7' : ''}',
                                style: const TextStyle(
                                  color: ivory,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (s.aiming && s.running)
                          Center(
                            child: CustomPaint(
                              size: const Size(44, 44),
                              painter: ReticlePainter(s.hitFlash > 0),
                            ),
                          ),
                        if (s.running &&
                            s.kickTarget != null &&
                            s.kickTime <= 0)
                          Positioned(
                            bottom: 175,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: FilledButton(
                                key: const ValueKey('game-kick'),
                                onPressed: () {
                                  s.kick();
                                  focus.requestFocus();
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: gold,
                                  foregroundColor: ink,
                                ),
                                child: const Text('F  蹴りで押し返す'),
                              ),
                            ),
                          ),
                        if (s.damageFlash > 0)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xaae0b46f),
                                    width: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(right: 28, bottom: 28, child: healthHud(s)),
                        Positioned(
                          left: 26,
                          bottom: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  pad('up', Icons.keyboard_arrow_up, 0, 1),
                                  pad('left', Icons.keyboard_arrow_left, -1, 0),
                                  pad('down', Icons.keyboard_arrow_down, 0, -1),
                                  pad(
                                    'right',
                                    Icons.keyboard_arrow_right,
                                    1,
                                    0,
                                  ),
                                  const SizedBox(width: 12),
                                  action('aim', '構える Q', () {
                                    s.aiming = !s.aiming;
                                  }),
                                  const SizedBox(width: 6),
                                  action('fire', '撃つ SPACE', game.fire),
                                ],
                              ),
                              const SizedBox(height: 9),
                              const Text(
                                'WASD 移動   SHIFT 走る   ドラッグ 視点   R 装填   E 調べる   X 回避   F 蹴り',
                                style: TextStyle(
                                  color: Color(0xffb8bdac),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  action(
                                    'bag',
                                    '持ち物 TAB',
                                    () => game.toggle(PlayPhase.inventory),
                                  ),
                                  const SizedBox(width: 6),
                                  action(
                                    'collection',
                                    '記録 C',
                                    () => game.toggle(PlayPhase.collection),
                                  ),
                                  const SizedBox(width: 6),
                                  action(
                                    'pause',
                                    '休止 ESC',
                                    () => game.toggle(PlayPhase.paused),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (s.interaction != null && s.running)
                          Positioned(
                            bottom: 160,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: FilledButton.icon(
                                key: const ValueKey('game-interact'),
                                onPressed: s.interact,
                                icon: const Icon(Icons.touch_app_outlined),
                                label: Text('E  ${s.interactionLabel}'),
                              ),
                            ),
                          ),
                        if (s.toastTime > 0 && s.running)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 220,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                color: ink,
                                child: Text(
                                  s.message,
                                  style: const TextStyle(
                                    color: ivory,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                      if (s.phase == PlayPhase.title) title(s),
                      if (s.phase == PlayPhase.cinematic) eventOverlay(),
                      if (s.phase == PlayPhase.settings) settingsPanel(),
                      if (s.phase == PlayPhase.dialogue) dialogue(s),
                      if (s.phase == PlayPhase.inventory) inventory(s),
                      if (s.phase == PlayPhase.mapView) fullMap(s),
                      if (s.phase == PlayPhase.collection) collection(s),
                      if (s.phase == PlayPhase.paused) pause(s),
                      if (s.phase == PlayPhase.dead ||
                          s.phase == PlayPhase.clear)
                        ending(s),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget action(String key, String label, VoidCallback callback) =>
      OutlinedButton(
        key: ValueKey('game-$key'),
        style: OutlinedButton.styleFrom(
          foregroundColor: ivory,
          backgroundColor: const Color(0xaa181c17),
          side: const BorderSide(color: Color(0x557a836d)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onPressed: () {
          callback();
          focus.requestFocus();
        },
        child: Text(label, style: const TextStyle(fontSize: 11)),
      );
  Widget dialogue(HazardGameState s) => Positioned.fill(
    child: Stack(
      children: [
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 34,
          child: ColoredBox(color: Color(0xff0c100c)),
        ),
        Positioned(
          top: 51,
          left: 30,
          child: Text(
            s.talkingTo == 'takosan' ? '補給所  /  たこさん' : '道案内  /  やめ太郎',
            style: TextStyle(
              color: ivory.withValues(alpha: .8),
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 280),
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
            decoration: const BoxDecoration(
              color: Color(0xf00d130e),
              border: Border(top: BorderSide(color: Color(0xff727155))),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.dialogueLine.speaker,
                    style: const TextStyle(
                      color: gold,
                      fontSize: 14,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.dialogueLine.text,
                    key: const ValueKey('game-dialogue-text'),
                    style: const TextStyle(
                      color: ivory,
                      fontSize: 17,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (s.talkingTo == 'takosan' && s.dialogueChoices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '所持ビール  ${s.beers}杯',
                        style: const TextStyle(color: gold),
                      ),
                    ),
                  if (s.dialogueChoices)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (s.talkingTo == 'takosan') ...[
                          for (final offer in tradeOffers)
                            action(
                              'trade-${offer.id}',
                              '${itemNames[offer.kind]} ×${offer.amount}  /  ${offer.price}杯  /  ${s.stockRemaining(offer) == 0 ? '売切' : '残${s.stockRemaining(offer)}'}',
                              () => s.chooseDialogue('trade:${offer.id}'),
                            ),
                        ] else ...[
                          action(
                            'dialogue-route',
                            s.zoneId == 'mountain' ? '脱出路について' : '農場への道',
                            () => s.chooseDialogue('route'),
                          ),
                          action(
                            'dialogue-combat',
                            'そば屋への対処',
                            () => s.chooseDialogue('combat'),
                          ),
                          action(
                            'dialogue-records',
                            '壁の貼り紙',
                            () => s.chooseDialogue('records'),
                          ),
                          if (!s.receivedYametaroAmmo)
                            action(
                              'dialogue-supplies',
                              '予備弾をもらう',
                              () => s.chooseDialogue('supplies'),
                            ),
                        ],
                        action('dialogue-leave', 'E  探索へ戻る', s.endDialogue),
                      ],
                    )
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: action(
                        'dialogue-next',
                        'E  次へ',
                        s.advanceDialogue,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Widget pad(String name, IconData icon, double x, double y) => Listener(
    onPointerDown: (_) {
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
      key: ValueKey('game-move-$name'),
      width: 35,
      height: 35,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: ink,
        border: Border.all(color: const Color(0x667a836d)),
      ),
      child: Icon(icon, color: ivory),
    ),
  );
  Widget healthHud(HazardGameState s) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: ink,
      border: Border.all(color: const Color(0x667a836d)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 68,
          height: 68,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 62,
                height: 62,
                child: CircularProgressIndicator(
                  value: s.health / s.maxHealth,
                  strokeWidth: 5,
                  color: s.health < 35
                      ? Colors.orange
                      : const Color(0xff90ac72),
                  backgroundColor: const Color(0xff353d2e),
                ),
              ),
              Text(
                '${s.health.ceil()}',
                style: const TextStyle(
                  color: ivory,
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FUKUCHAN',
              style: TextStyle(color: gold, letterSpacing: 3, fontSize: 10),
            ),
            Text(
              s.weapon == 'handgun' ? 'HANDGUN' : 'SHOTGUN',
              style: const TextStyle(
                color: ivory,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
            Text(
              s.reloading > 0
                  ? 'RELOADING…'
                  : '${s.loaded.toString().padLeft(2, '0')} / ${s.reserve}',
              style: TextStyle(
                color: ivory,
                fontSize: s.reloading > 0 ? 16 : 27,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ],
    ),
  );
  Widget title(HazardGameState s) => Positioned.fill(
    child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xf010140f), Color(0x5510140f)],
        ),
      ),
      padding: const EdgeInsets.all(64),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '窓 際 族 物 語',
              style: TextStyle(color: gold, fontSize: 15, letterSpacing: 7),
            ),
            const SizedBox(height: 24),
            const Text(
              'SOBAYA\nHAZARD',
              style: TextStyle(
                color: ivory,
                fontFamily: 'Georgia',
                fontSize: 76,
                height: .95,
                letterSpacing: 5,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'そば屋ハザード',
              style: TextStyle(color: ivory, fontSize: 24, letterSpacing: 5),
            ),
            const SizedBox(height: 24),
            const Text(
              '村の広場に、いつもの顔がいる。\n消えた住人のあとには、冷えたビールだけ。',
              style: TextStyle(
                color: Color(0xffb6bda9),
                height: 1.9,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 36),
            if (game.hasCheckpoint) ...[
              FilledButton(
                key: const ValueKey('game-continue'),
                style: FilledButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: ink,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 45,
                    vertical: 18,
                  ),
                ),
                onPressed: () {
                  game.continueRun();
                  focus.requestFocus();
                },
                child: const Text(
                  '続きから',
                  style: TextStyle(fontSize: 17, letterSpacing: 3),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              key: const ValueKey('game-start'),
              style: FilledButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: const Color(0xff1a1f16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 45,
                  vertical: 23,
                ),
              ),
              onPressed: () {
                game.startRun();
                focus.requestFocus();
                setState(() {});
              },
              child: Text(
                game.hasCheckpoint ? '新しく始める' : '村へ入る',
                style: const TextStyle(fontSize: 17, letterSpacing: 3),
              ),
            ),
            TextButton(
              key: const ValueKey('game-title-settings'),
              onPressed: game.openSettings,
              child: const Text('設定', style: TextStyle(color: ivory)),
            ),
            if (game.hasCheckpoint)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '新しく始めると進行の記録を上書きします。収集画像は残ります。',
                  style: TextStyle(color: ivory, fontSize: 11),
                ),
              ),
            if (game.saveStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  game.saveStatus,
                  style: const TextStyle(color: gold, fontSize: 11),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              'COLLECTION  ${s.collected.length} / ${s.gallery.length}',
              style: const TextStyle(
                color: gold,
                letterSpacing: 2,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget modal(String heading, Widget body, {double width = 850}) =>
      Positioned.fill(
        child: Container(
          color: const Color(0xe810130f),
          child: Center(
            child: Container(
              width: width,
              margin: const EdgeInsets.all(30),
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: ink,
                border: Border.all(color: const Color(0xff60654f)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          heading,
                          style: const TextStyle(
                            color: ivory,
                            fontSize: 24,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('game-modal-close'),
                        onPressed: () {
                          if (game.state!.phase == PlayPhase.settings) {
                            game.closeSettings();
                          } else {
                            game.state!.phase = PlayPhase.playing;
                          }
                          focus.requestFocus();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close, color: ivory),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xff484e3d)),
                  Flexible(child: body),
                ],
              ),
            ),
          ),
        ),
      );
  Widget inventory(HazardGameState s) => modal(
    'ATTACHÉ CASE',
    SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ドラッグして整理 ／ クリックして装備・使用・調合',
            style: TextStyle(color: gold, fontSize: 12),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, b) {
              final cell = math.min(66.0, b.maxWidth / 10);
              return SizedBox(
                width: cell * 10,
                height: cell * 6,
                child: Stack(
                  children: [
                    for (var row = 0; row < 6; row++)
                      for (var col = 0; col < 10; col++)
                        Positioned(
                          left: col * cell,
                          top: row * cell,
                          width: cell,
                          height: cell,
                          child: DragTarget<int>(
                            onWillAcceptWithDetails: (_) => true,
                            onAcceptWithDetails: (d) {
                              s.moveBag(d.data, col, row);
                              setState(() {});
                            },
                            builder: (context, candidate, rejected) =>
                                Container(
                                  decoration: BoxDecoration(
                                    color: candidate.isEmpty
                                        ? const Color(0xff24291f)
                                        : const Color(0xff596248),
                                    border: Border.all(
                                      color: const Color(0xff3d4534),
                                    ),
                                  ),
                                ),
                          ),
                        ),
                    for (final item in s.bag)
                      Positioned(
                        left: item.col * cell + 2,
                        top: item.row * cell + 2,
                        width: item.w * cell - 4,
                        height: item.h * cell - 4,
                        child: Draggable<int>(
                          data: item.id,
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: item.w * cell - 4,
                              height: item.h * cell - 4,
                              child: itemTile(item),
                            ),
                          ),
                          childWhenDragging: const SizedBox(),
                          child: GestureDetector(
                            onTap: () {
                              s.useBag(item.id);
                              setState(() {});
                            },
                            child: itemTile(item),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            'ビール  ${s.beers}    ｜    ${s.hasKey ? '紋章の鍵：入手済み' : '紋章の鍵：未入手'}',
            style: const TextStyle(color: ivory),
          ),
          if (s.toastTime > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(s.message, style: const TextStyle(color: gold)),
            ),
        ],
      ),
    ),
  );
  Widget itemTile(BagItem i) => Container(
    decoration: BoxDecoration(
      color: switch (i.kind) {
        'green' => const Color(0xff30492c),
        'red' => const Color(0xff5a342d),
        'yellow' => const Color(0xff615733),
        'ammo' => const Color(0xff50332b),
        _ => const Color(0xff434838),
      },
      border: Border.all(color: gold.withValues(alpha: .5)),
    ),
    padding: const EdgeInsets.all(5),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          switch (i.kind) {
            'handgun' || 'shotgun' => Icons.gps_fixed,
            'ammo' || 'shells' => Icons.view_week,
            _ => Icons.eco_outlined,
          },
          color: ivory,
          size: 22,
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              itemNames[i.kind]!,
              style: const TextStyle(color: ivory, fontSize: 11),
            ),
          ),
        ),
        if (i.count > 1)
          Text(
            '×${i.count}',
            style: const TextStyle(color: gold, fontSize: 11),
          ),
      ],
    ),
  );
  Widget collection(HazardGameState s) => modal(
    '窓際族の記録  ${s.collected.length}/${s.gallery.length}',
    GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      childAspectRatio: .86,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      children: [
        for (final row in s.gallery)
          GestureDetector(
            key: ValueKey('collection-${row['id']}'),
            onTap: () {
              if (s.collected.contains(row['id'])) {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: ink,
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Image.asset(
                              'assets/collection/${row['id']}.png',
                              cacheWidth: 1200,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Text(
                            row['title'],
                            style: const TextStyle(color: ivory),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('閉じる'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xff252b21),
                border: Border.all(color: const Color(0xff4a523f)),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: s.collected.contains(row['id'])
                        ? Image.asset(
                            'assets/collection/${row['id']}.png',
                            cacheWidth: 350,
                            fit: BoxFit.contain,
                          )
                        : const Center(
                            child: Icon(
                              Icons.lock_outline,
                              size: 40,
                              color: Color(0xff59634c),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      s.collected.contains(row['id']) ? row['title'] : '未発見',
                      style: const TextStyle(color: ivory, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
  Widget eventOverlay() {
    final d = game.director!;
    return Positioned.fill(
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 66,
            child: ColoredBox(color: Colors.black),
          ),
          Positioned(
            top: 22,
            left: 30,
            child: Text(
              d.id == 'opening' ? 'SOBAYA HAZARD' : game.state!.chapterLabel,
              style: const TextStyle(
                color: gold,
                letterSpacing: 4,
                fontSize: 14,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              constraints: const BoxConstraints(minHeight: 158),
              padding: const EdgeInsets.fromLTRB(40, 20, 40, 20),
              color: const Color(0xf5000000),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (d.shot.speaker.isNotEmpty)
                          Text(
                            d.shot.speaker,
                            style: const TextStyle(
                              color: gold,
                              fontSize: 16,
                              letterSpacing: 2,
                            ),
                          ),
                        const SizedBox(height: 7),
                        Text(
                          d.shot.text,
                          style: const TextStyle(
                            color: ivory,
                            fontSize: 20,
                            height: 1.65,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      action(
                        'event-next',
                        d.paused ? '再開  E' : '次へ  E',
                        () => game.advanceEvent(),
                      ),
                      const SizedBox(height: 8),
                      action(
                        'event-skip',
                        'スキップ',
                        () => game.advanceEvent(skip: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (d.paused)
            const Center(
              child: Text(
                'PAUSED',
                style: TextStyle(color: ivory, fontSize: 32, letterSpacing: 5),
              ),
            ),
        ],
      ),
    );
  }

  Widget settingsPanel() {
    final options = game.settings;
    return modal(
      'SETTINGS',
      SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('難易度', style: TextStyle(color: gold)),
            DropdownButton<HazardDifficulty>(
              key: const ValueKey('game-difficulty'),
              isExpanded: true,
              dropdownColor: ink,
              value: options.difficulty,
              style: const TextStyle(color: ivory, fontSize: 16),
              items: [
                for (final d in HazardDifficulty.values)
                  DropdownMenuItem(
                    value: d,
                    child: Text(HazardSettings(difficulty: d).difficultyLabel),
                  ),
              ],
              onChanged: (d) {
                if (d != null) game.changeSettings((s) => s.difficulty = d);
              },
            ),
            const Text(
              '被ダメージと敵の接近速度を変更します。探索中も切り替えられます。',
              style: TextStyle(color: ivory, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Text(
              '視点感度  ×${options.sensitivity.toStringAsFixed(1)}',
              style: const TextStyle(color: gold),
            ),
            Slider(
              key: const ValueKey('game-sensitivity'),
              value: options.sensitivity,
              min: .5,
              max: 2,
              divisions: 15,
              label: options.sensitivity.toStringAsFixed(1),
              activeColor: gold,
              onChanged: (v) => game.changeSettings((s) => s.sensitivity = v),
            ),
            Text(
              '全体音量  ${(options.volume * 100).round()}%',
              style: const TextStyle(color: gold),
            ),
            Slider(
              key: const ValueKey('game-volume'),
              value: options.volume,
              divisions: 10,
              activeColor: gold,
              onChanged: (v) => game.changeSettings((s) => s.volume = v),
            ),
            Text(
              '台詞  ${(options.voiceVolume * 100).round()}%',
              style: const TextStyle(color: gold),
            ),
            Slider(
              key: const ValueKey('game-voice-volume'),
              value: options.voiceVolume,
              divisions: 10,
              activeColor: gold,
              onChanged: (v) => game.changeSettings((s) => s.voiceVolume = v),
            ),
            Text(
              '環境音・緊張時の音楽  ${(options.environmentVolume * 100).round()}%',
              style: const TextStyle(color: gold),
            ),
            Slider(
              key: const ValueKey('game-environment-volume'),
              value: options.environmentVolume,
              divisions: 10,
              activeColor: gold,
              onChanged: (v) =>
                  game.changeSettings((s) => s.environmentVolume = v),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                action(
                  'mute',
                  options.muted ? '消音：ON' : '消音：OFF',
                  () => game.changeSettings((s) => s.muted = !s.muted),
                ),
                action(
                  'settings-default',
                  '標準設定に戻す',
                  () => game.changeSettings((s) {
                    s.difficulty = HazardDifficulty.standard;
                    s.volume = 1;
                    s.voiceVolume = 1;
                    s.environmentVolume = 1;
                    s.sensitivity = 1;
                    s.renderScale = .85;
                    s.muted = false;
                  }),
                ),
                action(
                  'quality',
                  '画質：${options.renderScale < .8
                      ? '軽量'
                      : options.renderScale < 1
                      ? '標準'
                      : '高精細'}',
                  () => game.changeSettings(
                    (s) => s.renderScale = s.renderScale < .8
                        ? .85
                        : s.renderScale < 1
                        ? 1
                        : .65,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            action('settings-back', '戻る', game.closeSettings),
          ],
        ),
      ),
      width: 660,
    );
  }

  Widget fullMap(HazardGameState s) => modal(
    '${s.chapterLabel}  /  MAP',
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.objective, style: const TextStyle(color: ivory)),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          width: 300,
          child: CustomPaint(painter: VillageMapPainter(s, detailed: true)),
        ),
        const SizedBox(height: 12),
        const Text(
          '白：現在地  金：門と出口  水色：仲間\n明るい壁：建物  暗い壁：岩壁・柵',
          style: TextStyle(color: ivory, height: 1.6),
        ),
        const SizedBox(height: 12),
        action('close-map', '探索に戻る  M', () => game.toggle(PlayPhase.mapView)),
      ],
    ),
    width: 600,
  );

  Widget pause(HazardGameState s) => modal(
    'PAUSED',
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('探索を再開する準備ができたら、戻ってください。', style: TextStyle(color: ivory)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          children: [
            action('resume', '探索に戻る', () => game.toggle(PlayPhase.paused)),
            action('save', game.saving ? '記録中…' : 'チェックポイントを保存', () {
              game.saveCheckpoint(announce: true);
            }),
            if (game.hasCheckpoint)
              action('load', 'チェックポイントへ戻る', game.continueRun),
            action('restart', '最初から', game.startRun),
            action('settings', '設定', game.openSettings),
          ],
        ),
        const SizedBox(height: 20),
        if (game.saveStatus.isNotEmpty)
          Text(game.saveStatus, style: const TextStyle(color: gold)),
        const SizedBox(height: 8),
        const Text(
          '案内役・補給所での会話後、武器・鍵の取得時、門を開けた時にも自動保存します。',
          style: TextStyle(color: ivory, fontSize: 12),
        ),
        const SizedBox(height: 12),
        const Text(
          '1 / 2 武器切替     H ハーブを使う\n構え中は移動を止めます。木箱や樽はEでも壊せます。',
          style: TextStyle(color: gold, height: 2),
        ),
      ],
    ),
    width: 700,
  );
  Widget ending(HazardGameState s) => Positioned.fill(
    child: Container(
      color: const Color(0xe810130f),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.phase == PlayPhase.clear ? 'DEMO COMPLETE' : 'YOU ARE DOWN',
              style: const TextStyle(
                color: gold,
                fontSize: 38,
                letterSpacing: 5,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              s.phase == PlayPhase.clear
                  ? '最後の一杯を断り、村を抜けた。'
                  : 'ビールの包囲網を抜けられなかった。',
              style: const TextStyle(color: ivory, fontSize: 18),
            ),
            const SizedBox(height: 25),
            Text(
              '撃退 ${s.kills}    ビール ${s.beers}    記録 ${s.collected.length}/${s.gallery.length}\n探索 ${(s.time / 60).floor()}分 ${(s.time % 60).floor()}秒    命中率 ${s.shots == 0 ? '—' : '${(s.hits / s.shots * 100).round()}%'}    ${game.settings.difficultyLabel}',
              style: const TextStyle(color: ivory),
            ),
            const SizedBox(height: 28),
            FilledButton(
              key: const ValueKey('game-retry'),
              onPressed: s.phase == PlayPhase.dead && game.hasCheckpoint
                  ? game.continueRun
                  : game.startRun,
              child: Text(
                s.phase == PlayPhase.dead && game.hasCheckpoint
                    ? 'チェックポイントから再開'
                    : 'もう一度探索する',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ReticlePainter extends CustomPainter {
  ReticlePainter(this.hit);
  final bool hit;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = hit ? gold : ivory
      ..strokeWidth = 1.5;
    final x = s.width / 2, y = s.height / 2;
    for (final d in [
      const Offset(1, 0),
      const Offset(-1, 0),
      const Offset(0, 1),
      const Offset(0, -1),
    ]) {
      c.drawLine(Offset(x, y) + d * 6, Offset(x, y) + d * 16, p);
    }
    c.drawCircle(Offset(x, y), 1.5, p);
  }

  @override
  bool shouldRepaint(ReticlePainter old) => old.hit != hit;
}

class VillageMapPainter extends CustomPainter {
  VillageMapPainter(this.state, {this.detailed = false});
  final bool detailed;
  final HazardGameState state;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    // Boundary cliffs extend beyond the playable area; keep both maps inside
    // their viewport instead of painting over the surrounding controls.
    c.clipRect(Offset.zero & size);
    Offset at(double x, double z) =>
        Offset((x + 24) / 48 * size.width, (27 - z) / 54 * size.height);
    final p = Paint()..color = const Color(0xff30362e);
    c.drawRect(Offset.zero & size, p);
    p.color = const Color(0xff454c3e);
    for (final o in state.obstacles) {
      if (o.bottom > 1.5 || (o.id == 'gate' && state.gateOpen)) continue;
      c.drawRect(
        Rect.fromPoints(
          at(o.x - o.w / 2, o.z + o.d / 2),
          at(o.x + o.w / 2, o.z - o.d / 2),
        ),
        p,
      );
    }
    p.color = const Color(0xff657057);
    for (final h in state.map['houses']) {
      final a = at(
            (h['x'] - h['w'] / 2).toDouble(),
            (h['z'] + h['d'] / 2).toDouble(),
          ),
          b = at(
            (h['x'] + h['w'] / 2).toDouble(),
            (h['z'] - h['d'] / 2).toDouble(),
          );
      c.drawRect(Rect.fromPoints(a, b), p);
    }
    p.color = gold;
    c.drawCircle(
      at(
        (state.gate['x'] as num).toDouble(),
        (state.gate['z'] as num).toDouble(),
      ),
      3,
      p,
    );
    if (detailed) {
      for (final e in state.map['exits'] as List? ?? []) {
        c.drawCircle(
          at((e['x'] as num).toDouble(), (e['z'] as num).toDouble()),
          5,
          p,
        );
      }
      p.color = const Color(0xff9cd0cc);
      for (final n in state.npcs) {
        c.drawCircle(
          at((n['x'] as num).toDouble(), (n['z'] as num).toDouble()),
          4,
          p,
        );
      }
    }
    p.color = ivory;
    c.drawCircle(at(state.x, state.z), 3, p);
    final center = at(state.x, state.z);
    c.drawLine(
      center,
      center + Offset(math.sin(state.heading), -math.cos(state.heading)) * 9,
      p..strokeWidth = 2,
    );
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
