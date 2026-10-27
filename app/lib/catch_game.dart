import 'dart:math' as math;

import 'balance.dart';
import 'character.dart';
import 'drop_kind.dart';
import 'stage_time.dart';
export 'drop_kind.dart';
export 'stage_time.dart';

enum Phase { ready, countdown, playing, result }

/// Message shown in the HUD; screens render the text in the chosen language.
enum GameMessage { hint, caught, bad }

/// Height where a drop meets the character's hands.
const catchHeight = 1.15;

class Drop {
  Drop(
    this.id,
    this.kind,
    this.x,
    this.spawn, {
    this.facing = 0,
    this.fallSeconds = 3.1,
  });
  final int id;
  final CanKind kind;
  final double x, spawn, facing, fallSeconds;
  bool resolved = false, caught = false;
  double get landing => spawn + fallSeconds;
  double height(double time) {
    final p = ((time - spawn) / fallSeconds).clamp(0.0, 1.0);
    return resolved && !caught
        ? math.max(.35, catchHeight - (time - landing) * 4)
        : catchHeight + 4.7 * (1 - math.pow(p, 1.25));
  }

  bool visible(double time) => time >= spawn && time < landing + .65 && !caught;
}

class CatchGame {
  static const duration = 20.0, halfX = 3.9;

  /// A round scores 0-100: the share of good drops caught, minus a penalty
  /// per bad catch. Reaching [passScore] passes the exam.
  static const passScore = 80;

  Balance balance = Balance.defaults();
  /// Layout of the current round; set by [start].
  int seed = 0;
  CatchCharacter _selectedCharacter = CatchCharacter.ctoOdatetsu;
  CatchCharacter get selectedCharacter => _selectedCharacter;
  CatchCharacter _roundCharacter = CatchCharacter.ctoOdatetsu;
  CatchCharacter get roundCharacter => _roundCharacter;
  double _baseMoveSpeed = 2.6, _baseCatchRadius = .72;
  double get baseMoveSpeed => _baseMoveSpeed;
  double get baseCatchRadius => _baseCatchRadius;
  double get moveSpeed => baseMoveSpeed;
  double get catchRadius => baseCatchRadius;
  bool selectCharacter(CatchCharacter character) {
    if (phase != Phase.ready && phase != Phase.result) return false;
    _selectedCharacter = character;
    return true;
  }

  /// Time of day of the beam stage; like the character, fixed during a round.
  StageTime timeOfDay = StageTime.day;
  bool selectTime(StageTime time) {
    if (phase != Phase.ready && phase != Phase.result) return false;
    timeOfDay = time;
    return true;
  }

  double get spawnInterval =>
      (balance['spawnInterval'] * roundCharacter.spawnMultiplier).clamp(
        .5,
        4.5,
      );
  double get fallSeconds =>
      (balance['fallSeconds'] * roundCharacter.fallMultiplier).clamp(1, 6);
  double get badRatio =>
      (balance['badRatio'] * roundCharacter.badMultiplier).clamp(0, 1);

  double get roundSeconds => balance['roundSeconds'];

  /// Practice: no time limit, drops keep coming, score and counters stay 0.
  bool practice = false;

  Phase phase = Phase.ready;
  double time = 0, countdown = 0, x = 0, vx = 0, yaw = 0, targetYaw = 0;
  int score = 0, combo = 0, caught = 0, bad = 0, missed = 0, eventId = 0;

  /// World X of the latest catch, good or bad. Null until the first catch after
  /// start. Only changes together with [eventId].
  double? fxX;

  /// True when [fxX] is a bad catch (happoshu, toxic chikuwa, yametaro).
  bool fxBad = false;
  GameMessage message = GameMessage.hint;
  CanKind? messageKind;
  int? messagePoints;
  double messageUntil = 0;
  final drops = <Drop>[];

  /// Good drops in this round; catching all of them without a bad one is 100.
  int goodTotal = 0;
  bool get passed => score >= passScore;
  final events = <Map<String, Object>>[];
  late math.Random _random;
  int _nextId = 0;

  /// Without [seed] the round uses the character's fixed, verified layout.
  void start({int? seed}) {
    _roundCharacter = selectedCharacter;
    this.seed = seed ?? roundCharacter.layoutSeed;
    _baseMoveSpeed = roundCharacter.moveSpeed;
    _baseCatchRadius = roundCharacter.catchRadius;
    phase = Phase.countdown;
    time = 0;
    countdown = 2;
    x = 0;
    vx = 0;
    yaw = 0;
    targetYaw = 0;
    score = 0;
    combo = 0;
    caught = 0;
    bad = 0;
    missed = 0;
    eventId = 0;
    fxX = null;
    fxBad = false;
    events.clear();
    drops.clear();
    message = GameMessage.hint;
    messageUntil = 2;
    _random = math.Random(this.seed);
    _nextId = 0;
    _spawnUntil(practice ? 30 : roundSeconds - fallSeconds - 1);
    goodTotal = drops.where((d) => !d.kind.isBad).length;
  }

  int get _score => math.max(
    0,
    (100 * caught / math.max(1, goodTotal)).round() -
        bad * balance['penalty'].round(),
  );

  /// Appends drops whose spawn time is at most [until]; practice streams more.
  void _spawnUntil(double until) {
    final r = _random;
    for (; _nextId * spawnInterval <= until; _nextId++) {
      final i = _nextId;
      final kind = ((i + 1) * badRatio).floor() > (i * badRatio).floor()
          ? roundCharacter.badDrop
          : roundCharacter.goodDrops[i % roundCharacter.goodDrops.length];
      drops.add(
        Drop(
          i,
          kind,
          (r.nextDouble() - .5) * 6.2,
          i * spawnInterval,
          fallSeconds: fallSeconds,
          facing:
              (r.nextDouble() < .5 ? -1 : 1) *
              (balance['facingMin'] +
                  r.nextDouble() *
                      (balance['facingMax'] - balance['facingMin'])) *
              math.pi /
              180,
        ),
      );
    }
  }

  void rotate(int direction) {
    targetYaw += direction.sign * balance['cameraStep'] * math.pi / 180;
    // Full orbit: keep angles in (-pi, pi] and shift the eased yaw by the
    // same turn so the camera keeps gliding instead of spinning back.
    while (targetYaw > math.pi + 1e-9) {
      targetYaw -= 2 * math.pi;
      yaw -= 2 * math.pi;
    }
    while (targetYaw <= -math.pi + 1e-9) {
      targetYaw += 2 * math.pi;
      yaw += 2 * math.pi;
    }
  }

  /// Input x is screen right; y is screen up (away from the camera).
  static ({double x, double z}) toWorld(double x, double y, double yaw) => (
    x: -math.cos(yaw) * x - math.sin(yaw) * y,
    z: math.sin(yaw) * x - math.cos(yaw) * y,
  );
  static ({double x, double y}) toScreen(double x, double z, double yaw) => (
    x: -math.cos(yaw) * x + math.sin(yaw) * z,
    y: -math.sin(yaw) * x - math.cos(yaw) * z,
  );
  void tick(double dt, {double inputX = 0, double inputY = 0}) {
    if (!dt.isFinite || dt <= 0 || !inputX.isFinite || !inputY.isFinite) return;
    var left = math.min(dt, .25);
    while (left > 1e-8) {
      final h = math.min(left, 1 / 60);
      left -= h;
      _step(h, inputX, inputY);
    }
  }

  void _step(double dt, double ix, double iy) {
    yaw += (targetYaw - yaw) * (1 - math.exp(-7 * dt));
    if (phase == Phase.countdown) {
      countdown -= dt;
      if (countdown <= 0) phase = Phase.playing;
      return;
    }
    if (phase != Phase.playing) return;
    time += dt;
    final len = math.sqrt(ix * ix + iy * iy);
    if (len > 1) {
      ix /= len;
      iy /= len;
    }
    // The tilt is read in screen space and projected onto the beam, so after
    // turning the camera you tilt toward where you want to walk.
    final dir = toWorld(ix, iy, yaw).x,
        a = 1 - math.exp(-balance['acceleration'] * dt);
    vx += (dir * moveSpeed - vx) * a;
    final previousX = x;
    x = (x + vx * dt).clamp(-halfX, halfX);
    // Animation uses actual displacement, including the end stops.
    vx = (x - previousX) / dt;
    for (final d in drops) {
      if (d.resolved || time < d.landing) continue;
      d.resolved = true;
      d.caught = (d.x - x).abs() < catchRadius;
      if (d.caught) {
        eventId++;
        fxX = d.x;
        fxBad = d.kind.isBad;
        messageKind = d.kind;
        messageUntil = time + 1.4;
      }
      if (d.caught && practice) {
        message = d.kind.isBad ? GameMessage.bad : GameMessage.caught;
        messagePoints = null;
      } else if (d.caught) {
        final before = score;
        if (d.kind.isBad) {
          bad++;
          combo = 0;
          message = GameMessage.bad;
        } else {
          caught++;
          combo++;
          message = GameMessage.caught;
        }
        score = _score;
        // No "-0" when the score is already at zero or the penalty is off.
        final change = (score - before).abs();
        messagePoints = change == 0 ? null : change;
        events.add({
          'time': time,
          'id': d.id,
          'kind': d.kind.name,
          'score': score,
          'x': x,
        });
      } else if (!d.kind.isBad && !practice) {
        missed++;
        combo = 0;
      }
    }
    if (practice) {
      drops.removeWhere((d) => d.resolved && time > d.landing + 1);
      if (_nextId * spawnInterval < time + 10) _spawnUntil(time + 30);
      return;
    }
    if (time >= roundSeconds) {
      time = roundSeconds;
      phase = Phase.result;
      vx = 0;
    }
  }

  Map<String, Object> inspect() => {
    'balance': balance.values,
    'seed': seed,
    'layoutSeed': roundCharacter.layoutSeed,
    'selectedCharacter': selectedCharacter.id,
    'timeOfDay': timeOfDay.id,
    'roundCharacter': roundCharacter.id,
    'difficulty': roundCharacter.difficulty,
    'spawnInterval': spawnInterval,
    'fallSeconds': fallSeconds,
    'badRatio': badRatio,
    'dropKinds': drops.map((d) => d.kind.name).toSet().toList(),
    'baseMoveSpeed': baseMoveSpeed,
    'baseCatchRadius': baseCatchRadius,
    'moveSpeed': moveSpeed,
    'catchRadius': catchRadius,
    'vx': vx,
    'dropCount': drops.length,
    'practice': practice,
    'goodTotal': goodTotal,
    'passed': passed,
    'phase': phase.name,
    'time': time,
    'x': x,
    'yaw': yaw,
    'score': score,
    'combo': combo,
    'caught': caught,
    'happoshu': bad,
    'missed': missed,
    'fxBad': fxBad,
    'fxX': ?fxX,
    'activeCans': drops
        .where((d) => d.visible(time))
        .map(
          (d) => {
            'id': d.id,
            'kind': d.kind.name,
            'facing': d.facing,
            'x': d.x,
            'height': d.height(time),
            'landing': d.landing,
          },
        )
        .toList(),
    'events': events,
  };

  /// A recording controller supplies only movement/camera inputs, never scores.
  ({double x, double y}) demoInput() {
    final candidates =
        drops
            .where(
              (d) =>
                  !d.resolved &&
                  d.spawn <= time &&
                  (!d.kind.isBad || d.id == 3),
            )
            .toList()
          ..sort((a, b) => a.landing.compareTo(b.landing));
    if (candidates.isEmpty) return (x: 0, y: 0);
    final d = candidates.first;
    return toScreen((d.x - x) * 2.6, 0, yaw);
  }
}
