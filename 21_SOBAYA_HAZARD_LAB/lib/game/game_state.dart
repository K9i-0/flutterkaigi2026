import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

import 'game_dialogue.dart';

enum PlayPhase {
  title,
  settings,
  cinematic,
  playing,
  dialogue,
  transition,
  paused,
  inventory,
  mapView,
  collection,
  dead,
  clear,
}

class Obstacle {
  Obstacle(Map<String, dynamic> j)
    : x = (j['x'] as num).toDouble(),
      z = (j['z'] as num).toDouble(),
      w = (j['w'] as num).toDouble(),
      d = (j['d'] as num).toDouble(),
      bottom = (j['bottom'] as num).toDouble(),
      top = (j['top'] as num).toDouble(),
      id = j['id'] as String?;
  final double x, z, w, d, bottom, top;
  final String? id;
  bool overlaps(double px, double pz, double radius, double y) {
    if (y + 1.65 <= bottom + .03 || y >= top - .08) return false;
    final dx = px - px.clamp(x - w / 2, x + w / 2),
        dz = pz - pz.clamp(z - d / 2, z + d / 2);
    return dx * dx + dz * dz < radius * radius;
  }

  double? ray(vm.Vector3 origin, vm.Vector3 direction, double maxDistance) {
    var near = 0.0, far = maxDistance;
    final lo = [x - w / 2, bottom, z - d / 2], hi = [x + w / 2, top, z + d / 2];
    for (var i = 0; i < 3; i++) {
      if (direction[i].abs() < 1e-7) {
        if (origin[i] < lo[i] || origin[i] > hi[i]) return null;
        continue;
      }
      var a = (lo[i] - origin[i]) / direction[i],
          b = (hi[i] - origin[i]) / direction[i];
      if (a > b) {
        final t = a;
        a = b;
        b = t;
      }
      near = math.max(near, a);
      far = math.min(far, b);
      if (near > far) return null;
    }
    return near;
  }
}

class Pickup {
  Pickup(this.id, this.kind, this.x, this.y, this.z, {this.amount = 1});
  final String id, kind;
  final double x, y, z;
  final int amount;
  bool taken = false;
  factory Pickup.fromJson(Map<String, dynamic> j) => Pickup(
    j['id'],
    j['kind'],
    (j['x'] as num).toDouble(),
    (j['y'] as num).toDouble(),
    (j['z'] as num).toDouble(),
    amount: j['amount'],
  );
}

enum BossMove {
  ready,
  chargeWindup,
  charging,
  swipeWindup,
  slamWindup,
  recovery,
}

class Enemy {
  Enemy(this.id, this.x, this.z, {this.boss = false}) {
    hp = boss ? 350 : 100;
  }
  BossMove bossMove = BossMove.ready;
  BossMove bossAttack = BossMove.ready;
  double bossTimer = 0, bossRecoveryDuration = 0;
  int bossSequence = 0;
  bool chargeHit = false;
  String get bossCue => switch (bossMove) {
    BossMove.chargeWindup => '突進 — 横へ避けろ',
    BossMove.charging => '突進',
    BossMove.swipeWindup => 'ジョッキの一撃 — 距離を取れ',
    BossMove.slamWindup => '叩きつけ — 離れろ',
    BossMove.recovery => '反撃のチャンス',
    BossMove.ready => hp <= 175 ? '怒りのラストオーダー' : 'ラストオーダー',
  };
  final bool boss;
  final int id;
  double x,
      z,
      heading = 0,
      hp = 100,
      windup = 0,
      cooldown = 0,
      stun = 0,
      vanish = 0,
      notice = 0,
      moved = 0;
  bool alerted = false;
  bool alive = true, dropped = false, active = false, attackPending = false;
}

class Breakable {
  Breakable(this.id, this.kind, this.x, this.z);
  final String id, kind;
  final double x, z;
  bool broken = false;
}

class BagItem {
  BagItem(this.id, this.kind, this.count, this.col, this.row, this.w, this.h);
  final int id, w, h;
  final String kind;
  int count, col, row;
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'count': count,
    'col': col,
    'row': row,
    'w': w,
    'h': h,
  };
}

const itemNames = {
  'handgun': 'ハンドガン',
  'shotgun': 'ショットガン',
  'ammo': 'ハンドガンの弾',
  'shells': 'ショットガンの弾',
  'green': 'グリーンハーブ',
  'red': 'レッドハーブ',
  'yellow': 'イエローハーブ',
  'mixed': '調合ハーブ',
  'key': '紋章の鍵',
  'beer': 'ビール',
};

class HazardGameState {
  HazardGameState(this.map, {Set<String>? savedCollection, this.catalog})
    : collected = {...?savedCollection} {
    restart();
  }
  final Map<String, dynamic> map;
  final List<Map<String, dynamic>>? catalog;
  List<Map<String, dynamic>> get gallery => catalog ?? images;
  String get zoneId => map['id'] as String? ?? 'village';
  String get chapterLabel => map['label'] as String? ?? 'CHAPTER 01  /  PUEBLO';
  String get subtitle => map['subtitle'] as String? ?? '静かな村、騒がしい住人。';
  Map<String, dynamic> get gate => map['gate'] as Map<String, dynamic>;
  String get gateMode => gate['mode'] as String? ?? 'key';
  bool get bossAlive => enemies.any((e) => e.boss && e.alive);
  bool get canOpenGate =>
      gateMode == 'free' || (gateMode == 'boss' ? !bossAlive : hasKey);
  String get objective => zoneId == 'farm'
      ? '納屋で補給し、東の門から山道へ'
      : zoneId == 'mountain'
      ? (bossAlive ? '廃屋の前のそば屋を撃退し、脱出路を開け' : '東の脱出路から村を抜けろ')
      : gateOpen
      ? '農場への門をくぐれ'
      : hasKey
      ? '北東の門を紋章の鍵で開けろ'
      : '村を探索し、紋章の鍵を探せ';
  Map<String, dynamic>? exitRequested;
  final medallions = <String>{};
  final seenEvents = <String>{};
  List<Map<String, dynamic>> get targets =>
      (map['targets'] as List? ?? const []).cast<Map<String, dynamic>>();
  final Set<String> collected;
  late List<Obstacle> obstacles;
  final enemies = <Enemy>[],
      pickups = <Pickup>[],
      crates = <Breakable>[],
      bag = <BagItem>[];
  PlayPhase phase = PlayPhase.title;
  double x = 0,
      y = 0,
      z = -21,
      heading = 0,
      yaw = math.pi,
      pitch = .12,
      health = 100,
      maxHealth = 100,
      time = 0,
      inputX = 0,
      inputY = 0;
  double fireCooldown = 0,
      reloading = 0,
      hitFlash = 0,
      damageFlash = 0,
      toastTime = 0,
      footDistance = 0,
      noiseTime = 0;
  double invulnerable = 0,
      evadeTime = 0,
      evadeCooldown = 0,
      kickTime = 0,
      kickCooldown = 0,
      hurtTime = 0,
      recoil = 0;
  double _evadeX = 0, _evadeZ = 0;
  double damageScale = 1, enemySpeedScale = 1;
  bool sprint = false,
      aiming = false,
      gateOpen = false,
      hasKey = false,
      collectionDirty = false;
  String weapon = 'handgun', message = '村に残された記録を探し、農場への門を開けろ。';
  int pistolLoaded = 10,
      shotgunLoaded = 5,
      beers = 0,
      kills = 0,
      shots = 0,
      hits = 0,
      nextBagId = 0;
  String? lastSound;
  vm.Vector3? shotEnd;
  String? interaction;
  String? talkingTo;
  String dialogueTopic = 'intro';
  String dialogueOwner = 'yametaro', tradeMessage = '';
  int dialogueIndex = 0;
  bool metYametaro = false, receivedYametaroAmmo = false;
  bool metTakosan = false;
  final tradePurchases = <String, int>{};
  bool checkpointRequested = false;
  List<Map<String, dynamic>> get npcs =>
      (map['npcs'] as List? ?? const []).cast<Map<String, dynamic>>();
  List<DialogueLine> get dialogueLines => dialogueOwner == 'takosan'
      ? dialogueTopic == 'trade_result'
            ? [DialogueLine('たこさん', tradeMessage)]
            : takosanDialogue[dialogueTopic]!
      : zoneId == 'mountain' &&
            ['intro', 'greeting', 'route'].contains(dialogueTopic)
      ? [
          DialogueLine(
            'やめ太郎',
            bossAlive
                ? '廃屋の前にいるそば屋が、帰り道を塞いでる。\nジョッキを大きく振り上げたら、横か後ろへ。振り終わりを狙おう。'
                : '福ちゃん、やったね！ 東側の門から帰ろう。\n今日はもう、乾杯は遠慮したいな。',
          ),
        ]
      : yametaroDialogue[dialogueTopic]!;
  DialogueLine get dialogueLine => dialogueLines[dialogueIndex];
  bool get dialogueChoices => dialogueIndex == dialogueLines.length - 1;
  final Map<int, int> _flow = {};
  double _flowTimer = 0;
  int get reserve => bag
      .where((i) => i.kind == (weapon == 'handgun' ? 'ammo' : 'shells'))
      .fold(0, (n, i) => n + i.count);
  int get loaded => weapon == 'handgun' ? pistolLoaded : shotgunLoaded;
  int get capacity => weapon == 'handgun' ? 10 : 5;
  bool get hasShotgun => bag.any((i) => i.kind == 'shotgun');
  bool get running => phase == PlayPhase.playing;
  List<Map<String, dynamic>> get images =>
      (map['collection'] as List).cast<Map<String, dynamic>>();
  void say(String text) {
    message = text;
    toastTime = 3.5;
  }

  void restart() {
    x = (map['spawn']['x'] as num).toDouble();
    z = (map['spawn']['z'] as num).toDouble();
    y = 0;
    yaw = (map['spawn']['yaw'] as num? ?? math.pi).toDouble();
    heading = yaw + math.pi;
    health = 100;
    maxHealth = 100;
    obstacles = (map['solids'] as List).map((j) => Obstacle(j)).toList();
    enemies.clear();
    for (final j in map['enemies']) {
      enemies.add(
        Enemy(
          j['id'],
          (j['x'] as num).toDouble(),
          (j['z'] as num).toDouble(),
          boss: j['boss'] == true,
        )..active = j['active'] as bool? ?? j['id'] < 4,
      );
    }
    pickups
      ..clear()
      ..addAll((map['items'] as List).map((j) => Pickup.fromJson(j)));
    crates
      ..clear()
      ..addAll(
        (map['crates'] as List).map(
          (j) => Breakable(
            j['id'],
            j['kind'],
            (j['x'] as num).toDouble(),
            (j['z'] as num).toDouble(),
          ),
        ),
      );
    bag.clear();
    nextBagId = 0;
    addItem('handgun', 1);
    addItem('ammo', 40);
    addItem('green', 1);
    pistolLoaded = 10;
    shotgunLoaded = 5;
    beers = 0;
    kills = 0;
    shots = 0;
    hits = 0;
    weapon = 'handgun';
    gateOpen = false;
    hasKey = false;
    time = 0;
    reloading = 0;
    fireCooldown = 0;
    hitFlash = damageFlash = noiseTime = footDistance = 0;
    invulnerable = evadeTime = evadeCooldown = kickTime = kickCooldown =
        hurtTime = recoil = 0;
    shotEnd = null;
    interaction = null;
    lastSound = null;
    talkingTo = null;
    metYametaro = receivedYametaroAmmo = false;
    metTakosan = false;
    tradePurchases.clear();
    dialogueOwner = 'yametaro';
    tradeMessage = '';
    checkpointRequested = false;
    exitRequested = null;
    medallions.clear();
    seenEvents.clear();
    dialogueTopic = 'intro';
    dialogueIndex = 0;
    sprint = false;
    pitch = .12;
    inputX = 0;
    inputY = 0;
    aiming = false;
    _flowTimer = 0;
    _flow.clear();
    phase = PlayPhase.playing;
    say(objective);
  }

  void stopInput() {
    inputX = 0;
    inputY = 0;
    sprint = false;
    aiming = false;
  }

  void toggle(PlayPhase p) {
    if (phase == PlayPhase.dialogue) {
      if (p == PlayPhase.paused) endDialogue();
      return;
    }
    if ([
      PlayPhase.dead,
      PlayPhase.clear,
      PlayPhase.title,
      PlayPhase.settings,
      PlayPhase.cinematic,
    ].contains(phase)) {
      return;
    }
    phase = phase == p ? PlayPhase.playing : p;
    stopInput();
  }

  bool addItem(String kind, int count) {
    if (kind == 'beer') {
      beers += count;
      return true;
    }
    if (kind == 'key') {
      hasKey = true;
      return true;
    }
    final stack = kind == 'ammo'
        ? 50
        : kind == 'shells'
        ? 15
        : 1;
    final existing = bag
        .where((i) => i.kind == kind && i.count + count <= stack)
        .firstOrNull;
    if (existing != null) {
      existing.count += count;
      return true;
    }
    final w = kind == 'shotgun'
        ? 7
        : kind == 'handgun'
        ? 3
        : kind == 'ammo' || kind == 'shells'
        ? 2
        : 1;
    final h = kind == 'ammo' || kind == 'shells' ? 1 : 2;
    for (var row = 0; row <= 6 - h; row++) {
      for (var col = 0; col <= 10 - w; col++) {
        if (bag.every(
          (i) =>
              col + w <= i.col ||
              col >= i.col + i.w ||
              row + h <= i.row ||
              row >= i.row + i.h,
        )) {
          bag.add(BagItem(nextBagId++, kind, count, col, row, w, h));
          return true;
        }
      }
    }
    return false;
  }

  bool moveBag(int id, int col, int row) {
    final i = bag.where((i) => i.id == id).firstOrNull;
    if (i == null || col < 0 || row < 0 || col + i.w > 10 || row + i.h > 6) {
      return false;
    }
    if (bag.any(
      (j) =>
          j != i &&
          col + i.w > j.col &&
          col < j.col + j.w &&
          row + i.h > j.row &&
          row < j.row + j.h,
    )) {
      return false;
    }
    i.col = col;
    i.row = row;
    return true;
  }

  void useBag(int id) {
    final item = bag.where((i) => i.id == id).firstOrNull;
    if (item == null) return;
    if (['handgun', 'shotgun'].contains(item.kind)) {
      equip(item.kind);
      return;
    }
    if (['green', 'mixed'].contains(item.kind)) {
      if (health >= maxHealth) {
        say('体力は満タンです。');
        return;
      }
      health = math.min(maxHealth, health + (item.kind == 'mixed' ? 100 : 35));
      bag.remove(item);
      lastSound = 'heal';
      say('体力を回復した。');
    } else if (item.kind == 'red' || item.kind == 'yellow') {
      final herb = bag.where((i) => i.kind == 'green').firstOrNull;
      if (herb == null) {
        say('グリーンハーブと組み合わせられる。');
        return;
      }
      if (item.kind == 'yellow') {
        maxHealth += 20;
        health = math.min(maxHealth, health + 55);
        bag.remove(herb);
        bag.remove(item);
        say('最大体力が上がった。');
      } else {
        bag.remove(item);
        final index = bag.indexOf(herb);
        bag[index] = BagItem(
          herb.id,
          'mixed',
          1,
          herb.col,
          herb.row,
          herb.w,
          herb.h,
        );
        say('ハーブを調合した。');
      }
    }
  }

  void heal() {
    final i = bag
        .where((i) => i.kind == 'green' || i.kind == 'mixed')
        .firstOrNull;
    if (i != null) {
      useBag(i.id);
    } else {
      say('回復アイテムがない。');
    }
  }

  void equip(String name) {
    if (name == 'shotgun' && !hasShotgun) {
      say('ショットガンは民家の二階にある。');
      return;
    }
    weapon = name;
    reloading = 0;
    lastSound = 'equip';
  }

  void reload() {
    if (!running ||
        reloading > 0 ||
        loaded >= capacity ||
        evadeTime > 0 ||
        kickTime > 0) {
      return;
    }
    if (reserve == 0) {
      say('予備の弾がない。');
      return;
    }
    reloading = weapon == 'handgun' ? 1.3 : 2.0;
    lastSound = 'reload';
  }

  void _finishReload() {
    var needed = capacity - loaded;
    var moved = 0;
    for (final i in bag.where(
      (i) => i.kind == (weapon == 'handgun' ? 'ammo' : 'shells'),
    )) {
      final n = math.min(needed, i.count);
      i.count -= n;
      needed -= n;
      moved += n;
    }
    bag.removeWhere((i) => i.count == 0);
    if (weapon == 'handgun') {
      pistolLoaded += moved;
    } else {
      shotgunLoaded += moved;
    }
  }

  bool blocked(double px, double pz, double py, {double radius = .29}) {
    if (px.abs() > 22.3 || pz < -24.4 || pz > 30) return true;
    if (obstacles.any(
      (o) => !(o.id == 'gate' && gateOpen) && o.overlaps(px, pz, radius, py),
    )) {
      return true;
    }
    if (py < 1.3 &&
        npcs.any(
          (n) =>
              math.pow(px - (n['x'] as num), 2) +
                  math.pow(pz - (n['z'] as num), 2) <
              math.pow(radius + .32, 2),
        )) {
      return true;
    }
    return crates.any(
      (c) =>
          !c.broken &&
          (c.x - px).abs() < .45 + radius &&
          (c.z - pz).abs() < .45 + radius &&
          py < 1,
    );
  }

  double floorHeight(double px, double pz, double previous) {
    for (final r in map['ramps']) {
      if ((px - r['x']).abs() < r['w'] / 2 && pz >= r['z0'] && pz <= r['z1']) {
        return ((pz - r['z0']) / (r['z1'] - r['z0']) * r['height']).toDouble();
      }
    }
    for (final h in map['houses']) {
      if (h['two'] == true &&
          previous > 2.65 &&
          (px - h['x']).abs() < h['w'] / 2 - .2 &&
          (pz - h['z']).abs() < h['d'] / 2 - .2) {
        return 3.03;
      }
    }
    if (map['tower'] != null &&
        previous > 3.8 &&
        (px + 13.5).abs() < 1.7 &&
        (pz + 6.5).abs() < 1.7) {
      return 4.22;
    }
    return 0;
  }

  void move(double dx, double dz, double dt, {double? speed}) {
    final magnitude = math.sqrt(dx * dx + dz * dz);
    if (magnitude < 1e-5) return;
    final length = (speed ?? (sprint ? 2.8 : 1.25)) * dt;
    dx /= math.max(1, magnitude);
    dz /= math.max(1, magnitude);
    final steps = math.max(1, (length / .05).ceil());
    final oldX = x, oldZ = z;
    for (var n = 0; n < steps; n++) {
      final nx = x + dx * length / steps, nz = z + dz * length / steps;
      if (!blocked(nx, z, y)) x = nx;
      if (!blocked(x, nz, y)) z = nz;
      final floor = floorHeight(x, z, y);
      y = floor > y - .25 ? floor : math.max(floor, y - 5 * dt / steps);
    }
    final distance = math.sqrt(math.pow(x - oldX, 2) + math.pow(z - oldZ, 2));
    footDistance += distance;
    if (distance > .0001) heading = math.atan2(dx, dz);
  }

  void tick(double delta) {
    if (!running) return;
    final dt = delta.clamp(0.0, .05);
    time += dt;
    fireCooldown = math.max(0, fireCooldown - dt);
    hitFlash = math.max(0, hitFlash - dt);
    damageFlash = math.max(0, damageFlash - dt);
    toastTime = math.max(0, toastTime - dt);
    noiseTime = math.max(0, noiseTime - dt);
    invulnerable = math.max(0, invulnerable - dt);
    evadeCooldown = math.max(0, evadeCooldown - dt);
    kickCooldown = math.max(0, kickCooldown - dt);
    hurtTime = math.max(0, hurtTime - dt);
    recoil *= math.exp(-dt * 15);
    final oldKick = kickTime;
    kickTime = math.max(0, kickTime - dt);
    if (oldKick > .42 && kickTime <= .42) _kickImpact();
    if (reloading > 0) {
      reloading -= dt;
      if (reloading <= 0) _finishReload();
    }
    if (evadeTime > 0) {
      final oldHeading = heading;
      move(_evadeX, _evadeZ, dt, speed: 3.7);
      heading = oldHeading;
      evadeTime = math.max(0, evadeTime - dt);
    } else if (kickTime > 0 || hurtTime > .2 || reloading > 0) {
      // Authored actions hold the feet; their hit moments use the same clock.
    } else if (!aiming) {
      move(
        -inputY * math.sin(yaw) - inputX * math.cos(yaw),
        -inputY * math.cos(yaw) + inputX * math.sin(yaw),
        dt,
      );
    } else {
      heading = math.atan2(-math.sin(yaw), -math.cos(yaw));
    }
    _flowTimer -= dt;
    if (_flowTimer <= 0) {
      _flowTimer = .7;
      _buildFlow();
    }
    for (final e in enemies) {
      e.moved = 0;
      if (!e.alive) {
        e.vanish += dt;
        if (e.vanish >= .65 && !e.dropped) {
          e.dropped = true;
          pickups.add(Pickup('beer_${e.id}', 'beer', e.x, .25, e.z));
        }
        continue;
      }
      if (!e.active) continue;
      if (e.boss && x < 1 && !e.alerted) continue;
      e.cooldown = math.max(0, e.cooldown - dt);
      e.stun = math.max(0, e.stun - dt);
      final dx = x - e.x, dz = z - e.z, dist = math.sqrt(dx * dx + dz * dz);
      if (!e.alerted) {
        final facing = dist < .01
            ? 1.0
            : (dx * math.sin(e.heading) + dz * math.cos(e.heading)) / dist;
        final sees =
            dist < 13 &&
            (dist < 5 || facing > -.2) &&
            wallDistance(
                  vm.Vector3(e.x, 1.3, e.z),
                  vm.Vector3(dx, 0, dz).normalized(),
                  dist,
                ) >=
                dist - .1;
        e.notice = sees ? e.notice + dt : math.max(0, e.notice - dt * 2);
        if (dist < 2.5 || e.notice > .45 || (noiseTime > 0 && dist < 20)) {
          e.alerted = true;
        }
        if (!e.alerted) continue;
      }
      if (e.boss && _tickBoss(e, dt, dx, dz, dist)) continue;
      if (!e.boss && e.attackPending) {
        e.windup -= dt;
        if (e.windup <= 0) {
          e.attackPending = false;
          e.cooldown = e.boss ? 2.2 : 1.5;
          if (dist < (e.boss ? 2.0 : 1.65) &&
              invulnerable <= 0 &&
              (dist < .01 ||
                  (dx * math.sin(e.heading) + dz * math.cos(e.heading)) / dist >
                      .35) &&
              y < 1 &&
              wallDistance(
                    vm.Vector3(e.x, 1, e.z),
                    vm.Vector3(dx, 0, dz).normalized(),
                    dist,
                  ) >=
                  dist - .1) {
            health -= (e.boss ? 30 : 15) * damageScale;
            invulnerable = .8;
            hurtTime = .45;
            reloading = 0;
            damageFlash = .4;
            lastSound = 'hurt';
            if (health <= 0) {
              health = 0;
              phase = PlayPhase.dead;
              stopInput();
            }
          }
        }
        continue;
      }
      if (e.stun > 0) continue;
      if (!e.boss && dist < 1.15 && y < 1 && e.cooldown <= 0) {
        e.attackPending = true;
        e.heading = math.atan2(dx, dz);
        e.windup = e.boss ? 1.15 : .7;
        lastSound = 'enemy';
        continue;
      }
      if (dist > 17 && noiseTime <= 0) continue;
      var tx = x, tz = z;
      final cell = _cell(e.x, e.z);
      var best = _flow[cell] ?? 999999;
      for (final n in _neighbors(cell)) {
        final value = _flow[n] ?? 999999;
        if (value < best) {
          best = value;
          tx = _cx(n);
          tz = _cz(n);
        }
      }
      var vx = tx - e.x, vz = tz - e.z;
      final len = math.sqrt(vx * vx + vz * vz);
      if (len < .05) continue;
      vx /= len;
      vz /= len;
      for (final other in enemies) {
        if (other == e || !other.alive || !other.active) continue;
        final ox = e.x - other.x, oz = e.z - other.z;
        final sep = math.sqrt(ox * ox + oz * oz);
        if (sep > .01 && sep < .85) {
          vx += ox / sep * (.85 - sep) * 2;
          vz += oz / sep * (.85 - sep) * 2;
        }
      }
      e.heading = math.atan2(vx, vz);
      final speed = (e.boss ? 1.15 : .8) * enemySpeedScale * dt;
      final oldX = e.x, oldZ = e.z;
      if (!blocked(e.x + vx * speed, e.z, 0, radius: .37)) e.x += vx * speed;
      if (!blocked(e.x, e.z + vz * speed, 0, radius: .37)) e.z += vz * speed;
      e.moved = math.sqrt(math.pow(e.x - oldX, 2) + math.pow(e.z - oldZ, 2));
    }
    if (running) {
      for (final exit in map['exits'] as List? ?? const []) {
        if (exit['requiresGate'] == true && !gateOpen) continue;
        if (y < 1 &&
            math.pow(x - exit['x'], 2) + math.pow(z - exit['z'], 2) <
                math.pow(exit['radius'], 2)) {
          exitRequested = Map<String, dynamic>.from(exit);
          phase = exit['target'] == 'ending'
              ? PlayPhase.clear
              : PlayPhase.transition;
          stopInput();
          lastSound = exit['target'] == 'ending' ? 'clear' : 'gate';
          break;
        }
      }
    }
    interaction = _nearestInteraction();
  }

  // Heading locks at the start of a tell: the player can step out of the path.
  // Committed attacks take damage but cannot be held still by repeated bullets.
  bool _tickBoss(Enemy e, double dt, double dx, double dz, double dist) {
    void recover(double seconds) {
      e.bossMove = BossMove.recovery;
      e.bossTimer = seconds;
      e.bossRecoveryDuration = seconds;
      e.attackPending = false;
      e.windup = 0;
    }

    bool clearToPlayer() =>
        y < 1 &&
        (dist < .001 ||
            wallDistance(
                  vm.Vector3(e.x, 1, e.z),
                  vm.Vector3(dx, 0, dz).normalized(),
                  dist,
                ) >=
                dist - .1);

    void hurt(double damage) {
      if (invulnerable > 0 || !running) return;
      health = math.max(0, health - damage * damageScale);
      invulnerable = .8;
      hurtTime = .45;
      reloading = 0;
      damageFlash = .4;
      lastSound = 'hurt';
      if (health <= 0) {
        phase = PlayPhase.dead;
        stopInput();
      }
    }

    if (e.bossMove != BossMove.ready) {
      e.bossTimer = math.max(0, e.bossTimer - dt);
      e.windup = e.bossTimer;
      switch (e.bossMove) {
        case BossMove.chargeWindup:
          if (e.bossTimer == 0) {
            e.bossMove = BossMove.charging;
            e.bossTimer = 1.1;
            e.attackPending = false;
            e.chargeHit = false;
          }
        case BossMove.charging:
          final distance = 5.2 * enemySpeedScale * dt;
          final steps = (distance / .05).ceil().clamp(1, 100);
          for (var i = 0; i < steps; i++) {
            final nx = e.x + math.sin(e.heading) * distance / steps;
            final nz = e.z + math.cos(e.heading) * distance / steps;
            if (blocked(nx, nz, 0, radius: .45)) {
              recover(2.5);
              break;
            }
            e.x = nx;
            e.z = nz;
            e.moved += distance / steps;
            if (!e.chargeHit &&
                y < 1 &&
                math.pow(x - e.x, 2) + math.pow(z - e.z, 2) < .9 * .9 &&
                wallDistance(
                      vm.Vector3(e.x, 1, e.z),
                      vm.Vector3(x - e.x, 0, z - e.z).normalized(),
                      .9,
                    ) >=
                    math.sqrt(math.pow(x - e.x, 2) + math.pow(z - e.z, 2)) -
                        .1) {
              e.chargeHit = true;
              hurt(25);
            }
          }
          if (e.bossMove == BossMove.charging && e.bossTimer == 0) recover(1.8);
        case BossMove.swipeWindup:
        case BossMove.slamWindup:
          if (e.bossTimer == 0) {
            final slam = e.bossMove == BossMove.slamWindup;
            final facing = dist < .001
                ? 1.0
                : (dx * math.sin(e.heading) + dz * math.cos(e.heading)) / dist;
            if (dist < (slam ? 2.6 : 1.95) &&
                (slam || facing > .35) &&
                clearToPlayer()) {
              hurt(slam ? 35 : 30);
            }
            recover(slam ? 2.2 : 1.6);
          }
        case BossMove.recovery:
          if (e.bossTimer == 0) e.bossMove = BossMove.ready;
        case BossMove.ready:
          break;
      }
      return true;
    }
    if (e.stun > 0 || e.cooldown > 0) return true;
    if (y >= 1 || !clearToPlayer()) return false;
    if (dist >= 3 && dist <= 9) {
      e.bossMove = BossMove.chargeWindup;
      e.bossTimer = 1.15;
    } else if (dist < 1.8 || (e.hp <= 175 && dist < 2.5)) {
      final slam = e.hp <= 175 && e.bossSequence.isOdd;
      e.bossMove = slam ? BossMove.slamWindup : BossMove.swipeWindup;
      e.bossTimer = slam ? 1.25 : .85;
    } else {
      return false;
    }
    e.bossAttack = e.bossMove;
    e.bossSequence++;
    e.heading = math.atan2(dx, dz);
    e.windup = e.bossTimer;
    e.attackPending = true;
    lastSound = 'enemy';
    return true;
  }

  int _cell(double px, double pz) => (pz.floor() + 25) * 46 + (px.floor() + 23);
  double _cx(int c) => (c % 46) - 22.5;
  double _cz(int c) => (c ~/ 46) - 24.5;
  Iterable<int> _neighbors(int c) sync* {
    final col = c % 46, row = c ~/ 46;
    if (col > 0) yield c - 1;
    if (col < 45) yield c + 1;
    if (row > 0) yield c - 46;
    if (row < 54) yield c + 46;
  }

  void _buildFlow() {
    _flow.clear();
    final start = _cell(x, z);
    final queue = <int>[start];
    _flow[start] = 0;
    for (var i = 0; i < queue.length; i++) {
      final cell = queue[i], depth = _flow[cell]!;
      for (final n in _neighbors(cell)) {
        if (_flow.containsKey(n) || blocked(_cx(n), _cz(n), 0, radius: .4)) {
          continue;
        }
        _flow[n] = depth + 1;
        queue.add(n);
      }
    }
  }

  double wallDistance(
    vm.Vector3 origin,
    vm.Vector3 direction,
    double maxDistance, {
    bool ignoreGate = false,
  }) {
    var limit = maxDistance;
    for (final o in obstacles) {
      if (o.id == 'gate' && (gateOpen || ignoreGate)) continue;
      final t = o.ray(origin, direction, limit);
      if (t != null) limit = math.min(limit, t);
    }
    return limit;
  }

  void shoot(vm.Vector3 origin, vm.Vector3 direction) {
    if (!running ||
        !aiming ||
        fireCooldown > 0 ||
        reloading > 0 ||
        evadeTime > 0 ||
        kickTime > 0 ||
        hurtTime > .2) {
      return;
    }
    if (loaded == 0) {
      lastSound = 'empty';
      say('Rでリロード');
      fireCooldown = .25;
      return;
    }
    if (weapon == 'handgun') {
      pistolLoaded--;
    } else {
      shotgunLoaded--;
    }
    shots++;
    noiseTime = 4;
    fireCooldown = weapon == 'handgun' ? .32 : .9;
    recoil = weapon == 'handgun' ? .065 : .15;
    lastSound = weapon == 'handgun' ? 'shot' : 'shotgun';
    final dir = direction.normalized();
    var distance = wallDistance(origin, dir, 60);
    Enemy? victim;
    Breakable? crate;
    Map<String, dynamic>? medallion;
    bool head = false;
    for (final c in crates.where((c) => !c.broken)) {
      final o = Obstacle({
        'x': c.x,
        'z': c.z,
        'w': .85,
        'd': .85,
        'bottom': 0,
        'top': 1.0,
      });
      final t = o.ray(origin, dir, distance);
      if (t != null && t < distance) {
        distance = t;
        crate = c;
        victim = null;
      }
    }
    for (final e in enemies.where((e) => e.alive && e.active)) {
      final center = vm.Vector3(e.x, .95, e.z), to = center - origin;
      final along = to.dot(dir);
      if (along <= 0 || along > distance) continue;
      final at = origin + dir * along;
      final radius = weapon == 'shotgun' ? .45 + along * .025 : .43;
      if ((at.x - e.x) * (at.x - e.x) + (at.z - e.z) * (at.z - e.z) <
              radius * radius &&
          at.y > .05 &&
          at.y < (e.boss ? 2.22 : 1.85)) {
        distance = along;
        victim = e;
        crate = null;
        head = at.y > 1.48;
      }
    }
    for (final target in targets.where((t) => !medallions.contains(t['id']))) {
      final center = vm.Vector3(
        (target['x'] as num).toDouble(),
        (target['y'] as num).toDouble(),
        (target['z'] as num).toDouble(),
      );
      final to = center - origin, along = to.dot(dir);
      final radius = (target['radius'] as num).toDouble();
      final perpendicular = to.length2 - along * along;
      if (along > 0 && perpendicular < radius * radius) {
        final near =
            along - math.sqrt(math.max(0, radius * radius - perpendicular));
        if (near < distance) {
          distance = near;
          medallion = target;
          victim = null;
          crate = null;
        }
      }
    }
    shotEnd = origin + dir * distance;
    // A camera ray cannot shoot through cover between the player and its hit.
    final muzzle = vm.Vector3(x, y + 1.25, z), toHit = shotEnd! - muzzle;
    if (wallDistance(muzzle, toHit.normalized(), toHit.length) <
        toHit.length - .5) {
      victim = null;
      crate = null;
      medallion = null;
    }
    if (medallion != null) {
      medallions.add(medallion['id']);
      hits++;
      hitFlash = .18;
      checkpointRequested = true;
      final count = targets.where((t) => medallions.contains(t['id'])).length;
      if (count == targets.length) {
        beers += 3;
        say('青いメダリオン $count / ${targets.length} — 達成報酬 ビール ×3');
      } else {
        say('青いメダリオン $count / ${targets.length}');
      }
    }
    if (crate != null) {
      hits++;
      breakCrate(crate);
      hitFlash = .15;
    }
    if (victim != null) {
      hits++;
      hitFlash = .18;
      victim.alerted = true;
      if (!victim.boss) {
        victim.stun = head ? 1.4 : .5;
        victim.attackPending = false;
      } else if (victim.bossMove == BossMove.ready && head) {
        victim.stun = .35;
      }
      victim.hp -= weapon == 'shotgun'
          ? 100
          : head
          ? 65
          : 35;
      if (victim.hp <= 0) {
        _defeat(victim);
      }
    }
  }

  void evade() {
    if (!running || evadeCooldown > 0 || kickTime > 0 || hurtTime > .2) return;
    _evadeX = -inputY * math.sin(yaw) - inputX * math.cos(yaw);
    _evadeZ = -inputY * math.cos(yaw) + inputX * math.sin(yaw);
    final length = math.sqrt(_evadeX * _evadeX + _evadeZ * _evadeZ);
    if (length < .01) {
      _evadeX = -math.sin(heading);
      _evadeZ = -math.cos(heading);
    } else {
      _evadeX /= length;
      _evadeZ /= length;
    }
    evadeTime = .42;
    evadeCooldown = 1.45;
    invulnerable = .32;
    aiming = false;
    reloading = 0;
    lastSound = 'step';
  }

  Enemy? get kickTarget => enemies
      .where(
        (e) =>
            e.alive &&
            e.active &&
            e.stun > 0 &&
            y < 1 &&
            math.pow(e.x - x, 2) + math.pow(e.z - z, 2) < 3.24 &&
            _reachable(e.x, e.z),
      )
      .firstOrNull;

  void kick() {
    if (!running ||
        kickTime > 0 ||
        kickCooldown > 0 ||
        evadeTime > 0 ||
        hurtTime > .2) {
      return;
    }
    final target = kickTarget;
    if (target == null) {
      say('ひるんだそば屋に近づくと蹴りを出せる。');
      return;
    }
    heading = math.atan2(target.x - x, target.z - z);
    kickTime = .78;
    kickCooldown = 1.1;
    aiming = false;
    reloading = 0;
  }

  void _kickImpact() {
    for (final e in enemies) {
      final dx = e.x - x, dz = e.z - z, dist = math.sqrt(dx * dx + dz * dz);
      if (!e.alive ||
          !e.active ||
          dist > 2.05 ||
          y > 1 ||
          !_reachable(e.x, e.z)) {
        continue;
      }
      if (dist > .01 &&
          (dx * math.sin(heading) + dz * math.cos(heading)) / dist < .15) {
        continue;
      }
      e.hp -= 50;
      e.stun = 1.5;
      e.alerted = true;
      e.attackPending = false;
      if (e.boss) {
        e.bossMove = BossMove.recovery;
        e.bossTimer = 1.5;
      }
      if (dist > .01) {
        for (var i = 0; i < 12; i++) {
          final nx = e.x + dx / dist * .055, nz = e.z + dz / dist * .055;
          if (!blocked(nx, nz, 0, radius: .37)) {
            e.x = nx;
            e.z = nz;
          }
        }
      }
      if (e.hp <= 0) _defeat(e);
    }
    lastSound = 'hurt';
    hitFlash = .15;
  }

  void _defeat(Enemy e) {
    if (!e.alive) return;
    e.alive = false;
    e.attackPending = false;
    e.bossMove = BossMove.ready;
    e.bossTimer = 0;
    e.vanish = 0;
    kills++;
    say(e.boss ? '最後のそば屋を撃退した。脱出路の門へ！' : 'そば屋を倒した。ビールを回収しよう。');
    if (e.boss) checkpointRequested = true;
    for (final other in enemies) {
      if (zoneId == 'village' &&
          other.id < 4 + enemies.where((e) => !e.alive).length) {
        other.active = true;
      }
    }
  }

  void breakCrate(Breakable c) {
    if (c.broken) return;
    c.broken = true;
    pickups.add(
      Pickup(
        '${c.id}_loot',
        c.id.hashCode.isEven ? 'ammo' : 'green',
        c.x,
        .2,
        c.z,
        amount: c.id.hashCode.isEven ? 10 : 1,
      ),
    );
    lastSound = 'break';
  }

  String? _nearestInteraction() {
    for (final n in npcs) {
      if (_near(
        (n['x'] as num).toDouble(),
        0,
        (n['z'] as num).toDouble(),
        1.9,
      )) {
        return 'npc:${n['id']}';
      }
    }
    for (final p in pickups) {
      if (!p.taken && _near(p.x, p.y, p.z, 1.55)) return 'pickup:${p.id}';
    }
    for (final p in images) {
      if (!collected.contains(p['id']) &&
          _near(
            (p['x'] as num).toDouble(),
            (p['y'] as num).toDouble(),
            (p['z'] as num).toDouble(),
            1.65,
          )) {
        return 'poster:${p['id']}';
      }
    }
    for (final c in crates) {
      if (!c.broken && _near(c.x, 0, c.z, 1.6)) return 'crate:${c.id}';
    }
    if (_near(
      (gate['x'] as num).toDouble(),
      0,
      (gate['z'] as num).toDouble(),
      2.4,
      ignoreGate: true,
    )) {
      return 'gate';
    }
    if (map['tower'] != null &&
        (_near(-13.5, 0, -8.8, 1.7) || _near(-13.5, 4.22, -6.5, 1.7))) {
      return 'tower';
    }
    return null;
  }

  bool _near(
    double px,
    double py,
    double pz,
    double radius, {
    bool ignoreGate = false,
  }) =>
      math.pow(x - px, 2) + math.pow(z - pz, 2) < radius * radius &&
      (y - py).abs() < 1.5 &&
      _reachable(px, pz, ignoreGate: ignoreGate);
  bool _reachable(double px, double pz, {bool ignoreGate = false}) {
    final origin = vm.Vector3(x, y + .9, z),
        target = vm.Vector3(px, y + .9, pz),
        delta = target - origin;
    return delta.length < .001 ||
        wallDistance(
              origin,
              delta.normalized(),
              delta.length,
              ignoreGate: ignoreGate,
            ) >=
            delta.length - .12;
  }

  String get interactionLabel {
    final key = interaction;
    if (key == null) return '';
    if (key == 'npc:yametaro') return 'やめ太郎と話す';
    if (key == 'npc:takosan') return 'たこさんの補給所';
    if (key.startsWith('pickup:')) {
      final p = pickups.firstWhere((p) => 'pickup:${p.id}' == key);
      return '${itemNames[p.kind]}を拾う';
    }
    if (key.startsWith('poster:')) return '窓際族の記録をコレクション';
    if (key.startsWith('crate:')) return '木箱・樽を壊す';
    if (key == 'tower') return y > 2 ? 'はしごを降りる' : '見張り塔へ登る';
    return gateOpen
        ? '門の先へ進む'
        : canOpenGate
        ? '${gate['label'] ?? '農場への門'}を開ける'
        : gateMode == 'boss'
        ? '廃屋前のそば屋を撃退する'
        : '紋章の鍵が必要';
  }

  void interact() {
    if (!running) return;
    interaction = _nearestInteraction();
    final key = interaction;
    if (key == null) return;
    if (key.startsWith('npc:')) {
      startDialogue(key.substring(4));
    } else if (key.startsWith('pickup:')) {
      final p = pickups.firstWhere((p) => 'pickup:${p.id}' == key);
      if (addItem(p.kind, p.amount)) {
        p.taken = true;
        if (p.kind == 'key' || p.kind == 'shotgun') checkpointRequested = true;
        lastSound = 'pickup';
        say('${itemNames[p.kind]} ×${p.amount} を入手');
      } else {
        say('ケースが満杯です。Tabで整理してください。');
      }
    } else if (key.startsWith('poster:')) {
      final id = key.substring(7);
      collected.add(id);
      collectionDirty = true;
      lastSound = 'collect';
      say('記録を収集した ${collected.length}/${gallery.length} — Cで鑑賞');
    } else if (key.startsWith('crate:')) {
      breakCrate(crates.firstWhere((c) => 'crate:${c.id}' == key));
    } else if (key == 'tower') {
      if (y < 2) {
        x = -13.5;
        z = -6.5;
        y = 4.22;
      } else {
        x = -13.5;
        z = -9.4;
        y = 0;
      }
      lastSound = 'step';
    } else if (key == 'gate') {
      if (canOpenGate) {
        gateOpen = true;
        checkpointRequested = true;
        say('${gate['label'] ?? '農場への門'}が開いた。');
        lastSound = 'gate';
      } else {
        say(
          gateMode == 'boss'
              ? '廃屋前のそば屋を撃退して、脱出路を確保しよう。'
              : '紋章の鍵が必要だ。北側の納屋を調べよう。',
        );
      }
    }
  }

  void startDialogue(String id) {
    if (!running ||
        !['yametaro', 'takosan'].contains(id) ||
        evadeTime > 0 ||
        kickTime > 0 ||
        hurtTime > 0) {
      return;
    }
    final npc = npcs.where((n) => n['id'] == id).firstOrNull;
    if (npc == null ||
        !_near(
          (npc['x'] as num).toDouble(),
          0,
          (npc['z'] as num).toDouble(),
          1.9,
        )) {
      return;
    }
    if (enemies.any(
      (e) =>
          e.alive &&
          e.active &&
          e.alerted &&
          math.pow(e.x - x, 2) + math.pow(e.z - z, 2) < 49 &&
          _reachable(e.x, e.z),
    )) {
      say('そば屋が近い。距離を取ってから話そう。');
      return;
    }
    talkingTo = id;
    dialogueOwner = id;
    dialogueTopic = (id == 'yametaro' ? metYametaro : metTakosan)
        ? 'greeting'
        : 'intro';
    dialogueIndex = 0;
    if (id == 'yametaro') {
      metYametaro = true;
    } else {
      metTakosan = true;
    }
    phase = PlayPhase.dialogue;
    reloading = 0;
    stopInput();
  }

  void advanceDialogue() {
    if (phase == PlayPhase.dialogue && !dialogueChoices) dialogueIndex++;
  }

  void chooseDialogue(String topic) {
    if (phase != PlayPhase.dialogue || !dialogueChoices) return;
    if (topic == 'leave') {
      endDialogue();
      return;
    }
    if (talkingTo == 'takosan') {
      if (topic.startsWith('trade:')) buySupplies(topic.substring(6));
      return;
    }
    if (!['route', 'combat', 'records', 'supplies'].contains(topic)) return;
    if (topic == 'supplies') {
      if (receivedYametaroAmmo) return;
      if (addItem('ammo', 10)) {
        receivedYametaroAmmo = true;
        lastSound = 'pickup';
      } else {
        topic = 'full';
      }
    }
    dialogueTopic = topic;
    dialogueIndex = 0;
  }

  int stockRemaining(TradeOffer offer) =>
      offer.stock - (tradePurchases[offer.id] ?? 0);

  void buySupplies(String id) {
    if (phase != PlayPhase.dialogue ||
        talkingTo != 'takosan' ||
        !dialogueChoices) {
      return;
    }
    final offer = tradeOffers.where((o) => o.id == id).firstOrNull;
    if (offer == null) return;
    if (stockRemaining(offer) <= 0) {
      tradeMessage = 'それは売り切れです。別の品をどうぞ。';
    } else if (beers < offer.price) {
      tradeMessage = 'ビールが足りません。\nこの品には${offer.price}杯、必要です。';
    } else if (!addItem(offer.kind, offer.amount)) {
      tradeMessage = 'ケースに入りません。整理してから、またどうぞ。\nビールはまだ頂いていません。';
    } else {
      beers -= offer.price;
      tradePurchases[id] = (tradePurchases[id] ?? 0) + 1;
      tradeMessage =
          '${itemNames[offer.kind]} ×${offer.amount}。お受け取りください。\n……。また、お待ちしています。';
      lastSound = 'pickup';
    }
    dialogueTopic = 'trade_result';
    dialogueIndex = 0;
  }

  void endDialogue() {
    if (phase != PlayPhase.dialogue) return;
    talkingTo = null;
    phase = PlayPhase.playing;
    checkpointRequested = true;
    stopInput();
  }

  Map<String, Object?> inspect() => {
    'phase': phase.name,
    'position': {'x': x, 'y': y, 'z': z},
    'yaw': yaw,
    'health': health,
    'combat': {
      'evadeTime': evadeTime,
      'evadeCooldown': evadeCooldown,
      'kickTime': kickTime,
      'invulnerable': invulnerable,
      'reloading': reloading,
      'recoil': recoil,
    },
    'maxHealth': maxHealth,
    'weapon': weapon,
    'loaded': loaded,
    'reserve': reserve,
    'beers': beers,
    'kills': kills,
    'shots': shots,
    'hits': hits,
    'zone': zoneId,
    'exitRequested': exitRequested,
    'medallions': medallions.toList(),
    'gateOpen': gateOpen,
    'hasKey': hasKey,
    'collected': collected.toList(),
    'interaction': interaction,
    'dialogue': {
      'npc': talkingTo,
      'topic': dialogueTopic,
      'line': dialogueIndex,
      'choices': dialogueChoices,
      'metYametaro': metYametaro,
      'receivedAmmo': receivedYametaroAmmo,
      'metTakosan': metTakosan,
      'tradePurchases': Map<String, int>.of(tradePurchases),
    },
    'bag': bag.map((i) => i.toJson()).toList(),
    'enemies': enemies
        .map(
          (e) => {
            'id': e.id,
            'alive': e.alive,
            'active': e.active,
            'dropped': e.dropped,
            'hp': e.hp,
            'alerted': e.alerted,
            'stun': e.stun,
            'attackPending': e.attackPending,
            'bossMove': e.bossMove.name,
            'bossTimer': e.bossTimer,
            if (e.boss) 'bossCue': e.bossCue,
            'x': e.x,
            'z': e.z,
          },
        )
        .toList(),
    'bloodEffects': false,
  };
}
