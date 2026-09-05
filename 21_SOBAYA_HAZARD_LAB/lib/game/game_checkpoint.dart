import 'game_state.dart';

/// Progress is independent of the account-wide collection. Loading a checkpoint
/// never removes images already collected on a later attempt.
extension HazardCheckpoint on HazardGameState {
  Map<String, dynamic> checkpoint() => {
    'version': 1,
    'map': zoneId,
    'mapVersion': map['version'],
    'savedAt': DateTime.now().toIso8601String(),
    'player': {
      'x': x,
      'y': y,
      'z': z,
      'yaw': yaw,
      'pitch': pitch,
      'heading': heading,
      'health': health,
      'maxHealth': maxHealth,
    },
    'weapon': weapon,
    'pistolLoaded': pistolLoaded,
    'shotgunLoaded': shotgunLoaded,
    'beers': beers,
    'kills': kills,
    'shots': shots,
    'hits': hits,
    'time': time,
    'medallions': medallions.toList(),
    'seenEvents': seenEvents.toList(),
    'hasKey': hasKey,
    'gateOpen': gateOpen,
    'metYametaro': metYametaro,
    'receivedYametaroAmmo': receivedYametaroAmmo,
    'metTakosan': metTakosan,
    'tradePurchases': Map<String, int>.of(tradePurchases),
    'bag': bag.map((i) => i.toJson()).toList(),
    'crates': crates.where((c) => c.broken).map((c) => c.id).toList(),
    'pickups': pickups
        .map(
          (p) => {
            'id': p.id,
            'kind': p.kind,
            'x': p.x,
            'y': p.y,
            'z': p.z,
            'amount': p.amount,
            'taken': p.taken,
          },
        )
        .toList(),
    'enemies': enemies
        .map(
          (e) => {
            'id': e.id,
            'x': e.x,
            'z': e.z,
            'heading': e.heading,
            'hp': e.hp,
            'alive': e.alive,
            'active': e.active,
            'dropped': e.dropped,
            'vanish': e.vanish,
            'alerted': e.alerted,
            'notice': e.notice,
            'stun': e.stun,
            'cooldown': e.cooldown,
            'attackPending': e.attackPending,
            'windup': e.windup,
            'bossMove': e.bossMove.name,
            'bossAttack': e.bossAttack.name,
            'bossRecoveryDuration': e.bossRecoveryDuration,
            'bossTimer': e.bossTimer,
            'bossSequence': e.bossSequence,
            'chargeHit': e.chargeHit,
          },
        )
        .toList(),
  };
}

HazardGameState restoreHazardCheckpoint(
  Map<String, dynamic> data,
  Map<String, dynamic> map,
  Set<String> collection, {
  List<Map<String, dynamic>>? catalog,
}) {
  void require(bool valid) {
    if (!valid) throw const FormatException('Invalid checkpoint');
  }

  double number(dynamic value, double lo, double hi) {
    require(value is num && value.isFinite && value >= lo && value <= hi);
    return (value as num).toDouble();
  }

  int integer(dynamic value, int lo, int hi) {
    require(value is int && value >= lo && value <= hi);
    return value as int;
  }

  require(
    data['version'] == 1 &&
        data['map'] == (map['id'] ?? 'village') &&
        data['mapVersion'] == map['version'],
  );
  final s = HazardGameState(map, savedCollection: collection, catalog: catalog);
  final p = data['player'] as Map<String, dynamic>;
  s.x = number(p['x'], -22.3, 22.3);
  s.y = number(p['y'], 0, 6);
  s.z = number(p['z'], -24.4, 30);
  s.yaw = number(p['yaw'], -1e9, 1e9);
  s.pitch = number(p['pitch'], minCameraPitch, maxCameraPitch);
  s.heading = number(p['heading'], -1e9, 1e9);
  s.maxHealth = number(p['maxHealth'], 100, 200);
  s.health = number(p['health'], .001, s.maxHealth);
  s.weapon = data['weapon'] as String;
  require(['handgun', 'shotgun'].contains(s.weapon));
  s.pistolLoaded = integer(data['pistolLoaded'], 0, 10);
  s.shotgunLoaded = integer(data['shotgunLoaded'], 0, 5);
  s.beers = integer(data['beers'], 0, 100000);
  s.kills = integer(data['kills'], 0, 100000);
  s.shots = integer(data['shots'], 0, 1000000);
  s.hits = integer(data['hits'], 0, s.shots);
  s.time = number(data['time'], 0, 1e9);
  s.hasKey = data['hasKey'] as bool;
  s.gateOpen = data['gateOpen'] as bool;
  require(!s.gateOpen || s.gateMode != 'key' || s.hasKey);
  s.seenEvents.addAll((data['seenEvents'] as List? ?? const []).cast<String>());
  s.medallions.addAll((data['medallions'] as List? ?? const []).cast<String>());
  s.metYametaro = data['metYametaro'] as bool;
  s.receivedYametaroAmmo = data['receivedYametaroAmmo'] as bool;
  s.metTakosan = data['metTakosan'] as bool? ?? false;
  for (final entry in ((data['tradePurchases'] as Map?) ?? {}).entries) {
    require(['ammo', 'herb', 'shells'].contains(entry.key));
    s.tradePurchases[entry.key] = integer(
      entry.value,
      0,
      entry.key == 'ammo' ? 3 : 2,
    );
  }
  s.bag.clear();
  final occupied = <int>{}, ids = <int>{};
  for (final j in data['bag'] as List) {
    final kind = j['kind'] as String;
    require(
      [
        'handgun',
        'shotgun',
        'ammo',
        'shells',
        'green',
        'red',
        'yellow',
        'mixed',
      ].contains(kind),
    );
    final w = kind == 'shotgun'
        ? 7
        : kind == 'handgun'
        ? 3
        : ['ammo', 'shells'].contains(kind)
        ? 2
        : 1;
    final h = ['ammo', 'shells'].contains(kind) ? 1 : 2;
    final i = BagItem(
      integer(j['id'], 0, 100000),
      kind,
      integer(
        j['count'],
        1,
        kind == 'ammo'
            ? 50
            : kind == 'shells'
            ? 15
            : 1,
      ),
      integer(j['col'], 0, 10 - w),
      integer(j['row'], 0, 6 - h),
      w,
      h,
    );
    require(ids.add(i.id));
    for (var y = i.row; y < i.row + h; y++) {
      for (var x = i.col; x < i.col + w; x++) {
        require(occupied.add(y * 10 + x));
      }
    }
    s.bag.add(i);
    if (s.nextBagId <= i.id) s.nextBagId = i.id + 1;
  }
  require(s.bag.any((i) => i.kind == 'handgun'));
  require(s.weapon != 'shotgun' || s.hasShotgun);
  final broken = (data['crates'] as List).cast<String>().toSet();
  require(broken.every((id) => s.crates.any((c) => c.id == id)));
  for (final c in s.crates) {
    c.broken = broken.contains(c.id);
  }
  s.pickups.clear();
  final pickupIds = <String>{};
  final pickups = data['pickups'] as List;
  require(pickups.length < 200);
  for (final j in pickups) {
    require(pickupIds.add(j['id'] as String));
    require(itemNames.containsKey(j['kind']));
    final p = Pickup(
      j['id'],
      j['kind'],
      number(j['x'], -30, 30),
      number(j['y'], 0, 6),
      number(j['z'], -30, 35),
      amount: integer(j['amount'], 1, 50),
    )..taken = j['taken'] as bool;
    s.pickups.add(p);
  }
  final enemies = data['enemies'] as List;
  require(enemies.length == s.enemies.length);
  for (var i = 0; i < enemies.length; i++) {
    final j = enemies[i], e = s.enemies[i];
    require(j['id'] == e.id);
    e
      ..x = number(j['x'], -30, 30)
      ..z = number(j['z'], -30, 35)
      ..heading = number(j['heading'], -1e9, 1e9)
      ..hp = number(j['hp'], -100, e.boss ? 350 : 100)
      ..alive = j['alive'] as bool
      ..active = j['active'] as bool
      ..dropped = j['dropped'] as bool
      ..vanish = number(j['vanish'], 0, 1e9)
      ..alerted = j['alerted'] as bool
      ..notice = number(j['notice'], 0, 1e9)
      ..stun = number(j['stun'], 0, 30)
      ..cooldown = number(j['cooldown'], 0, 30)
      ..attackPending = j['attackPending'] as bool
      ..windup = number(j['windup'], -.051, 30);
    if (j.containsKey('bossMove')) {
      e.bossMove = BossMove.values.byName(j['bossMove'] as String);
      e.bossAttack = BossMove.values.byName(
        (j['bossAttack'] ?? 'ready') as String,
      );
      e.bossRecoveryDuration = number(j['bossRecoveryDuration'] ?? 0, 0, 30);
      e.bossTimer = number(j['bossTimer'], 0, 30);
      e.bossSequence = (j['bossSequence'] as num).toInt();
      require(e.bossSequence >= 0);
      e.chargeHit = j['chargeHit'] as bool;
    } else if (e.boss) {
      // Older checkpoints used the generic melee state.
      e.attackPending = false;
      e.windup = 0;
    }
    require(e.alive == (e.hp > 0) && (!e.dropped || !e.alive));
  }
  require(s.enemies.where((e) => !e.alive).length <= s.kills);
  require(!s.blocked(s.x, s.z, s.y));
  s.phase = PlayPhase.playing;
  s.invulnerable = .5;
  s.say('チェックポイントから探索を再開した。');
  return s;
}
