import 'package:vector_math/vector_math.dart' as vm;

import 'game_story.dart';
import 'game_settings.dart';
import 'game_state.dart';
import 'game_ladder.dart';
import 'game_window.dart';
import 'game_grapple.dart';

/// Progress is independent of the account-wide collection. Loading a checkpoint
/// never removes images already collected on a later attempt.
extension HazardCheckpoint on HazardGameState {
  Map<String, dynamic> checkpoint() => {
    'version': 1,
    'encounterVersion': 2,
    'bossBalanceVersion': 2,
    'stealthVersion': 2,
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
      'climb': climb?.toJson(),
      'vault': vault?.toJson(),
      'grapple': grapple?.toJson(),
      'breakFreeTime': breakFreeTime,
      'health': health,
      'maxHealth': maxHealth,
    },
    'weapon': weapon,
    'pistolLoaded': pistolLoaded,
    'shotgunLoaded': shotgunLoaded,
    'beers': beers,
    'beersThrown': beersThrown,
    'beerThrowTime': beerThrowTime,
    // Preserve the action interval while an adopted throw is still in flight.
    'beerThrowCooldown': weapon == 'beer' || beerFlights.isNotEmpty
        ? fireCooldown
        : 0,
    'beerFlights': [
      for (final b in beerFlights)
        {
          'origin': b.origin.storage.toList(),
          'velocity': b.velocity.storage.toList(),
          'age': b.age,
        },
    ],
    'kills': kills,
    'shots': shots,
    'hits': hits,
    'time': time,
    'medallions': medallions.toList(),
    'seenEvents': seenEvents.toList(),
    'foundMemos': foundMemos.toList(),
    'hasKey': hasKey,
    'gateOpen': gateOpen,
    'metYametaro': metYametaro,
    'receivedYametaroAmmo': receivedYametaroAmmo,
    'metTakosan': metTakosan,
    'tradePurchases': Map<String, int>.of(tradePurchases),
    'companionHealth': Map<String, double>.of(companionHealth),
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
            'y': e.y,
            'z': e.z,
            'heading': e.heading,
            'climb': e.climb?.toJson(),
            'vault': e.vault?.toJson(),
            'fallingFromLadder': e.fallingFromLadder,
            'hp': e.hp,
            'alive': e.alive,
            'active': e.active,
            'dropped': e.dropped,
            'suppressBeer': e.suppressBeer,
            'vanish': e.vanish,
            'alerted': e.alerted,
            'hasBeenAlerted': e.hasBeenAlerted,
            'ambientDance': e.ambientDance,
            'awareness': e.awareness.name,
            'discovered': e.discovered,
            'lastKnown': e.lastKnownX == null
                ? null
                : [e.lastKnownX, e.lastKnownY, e.lastKnownZ],
            'lastSeenByPlayer': e.lastSeenByPlayerX == null
                ? null
                : [
                    e.lastSeenByPlayerX,
                    e.lastSeenByPlayerY,
                    e.lastSeenByPlayerZ,
                  ],
            'lastSeenByPlayerHeading': e.lastSeenByPlayerHeading,
            'contactAge': e.contactAge,
            'searchTime': e.searchTime,
            'stealthMemory': {
              'source': e.knowledgeSource,
              'time': e.knowledgeTime,
              'visualTime': e.lastVisualTime,
              'sharedTime': e.lastSharedTime,
              'uncertainty': e.uncertainty,
              'remaining': e.searchRemaining,
              'duration': e.searchDuration,
              'pursuit': e.pursuitRemaining,
              'extension': e.weakNoiseExtension,
              'returnRemaining': e.returnRemaining,
              'role': e.searchRole,
              'reason': e.feedbackReason,
              'observedHeading': e.observedHeading,
              'hadVisualContact': e.hadVisualContact,
              'homeHeading': e.homeHeading,
              'returnTarget': e.returnTarget == null
                  ? null
                  : [e.returnTarget!.x, e.returnTarget!.y, e.returnTarget!.z],
              'searchIndex': e.searchIndex,
              'pointTime': e.pointTime,
              'lookTime': e.lookTime,
              'patrolIndex': e.patrolIndex,
              'patrolWait': e.patrolWait,
              'lureAttention': e.lureAttention,
              'lureHold': e.lureHold,
              'target': e.investigationTarget == null
                  ? null
                  : [
                      e.investigationTarget!.x,
                      e.investigationTarget!.y,
                      e.investigationTarget!.z,
                    ],
              'points': [
                for (final p in e.searchPoints) [p.x, p.y, p.z],
              ],
            },
            'notice': e.notice,
            'stun': e.stun,
            'cooldown': e.cooldown,
            'attackPending': e.attackPending,
            'grabPending': e.grabPending,
            'companionTarget': e.companionTarget,
            'grabCooldown': e.grabCooldown,
            'releaseTime': e.releaseTime,
            'windup': e.windup,
            'meleeRecovery': e.meleeRecovery,
            'approachHeading': e.approachHeading,
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
  HazardDifficulty difficulty = HazardDifficulty.standard,
  bool? refugeReady,
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
  final s = HazardGameState(
    map,
    savedCollection: collection,
    catalog: catalog,
    difficulty: difficulty,
  );
  final p = data['player'] as Map<String, dynamic>;
  s.x = number(p['x'], -22.3, 22.3);
  s.y = number(p['y'], 0, 6);
  s.z = number(p['z'], -24.4, 30);
  s.yaw = number(p['yaw'], -1e9, 1e9);
  s.pitch = number(p['pitch'], minCameraPitch, maxCameraPitch);
  s.heading = number(p['heading'], -1e9, 1e9);
  s.maxHealth = number(p['maxHealth'], 100, 200);
  s.health = number(p['health'], .001, s.maxHealth);
  s.climb = LadderTraversal.restore(p['climb'], s.ladder, s.x, s.y, s.z);
  s.vault = WindowTraversal.restore(p['vault'], s.windows, s.x, s.y, s.z);
  s.grapple = HazardGrapple.restore(p['grapple']);
  s.breakFreeTime = number(p['breakFreeTime'] ?? 0, 0, .7);
  require(s.climb == null || s.vault == null);
  require(s.grapple == null || (!s.traversing && s.breakFreeTime == 0));
  s.weapon = data['weapon'] as String;
  require(['handgun', 'shotgun', 'rocket', 'beer'].contains(s.weapon));
  s.pistolLoaded = integer(data['pistolLoaded'], 0, 10);
  s.shotgunLoaded = integer(data['shotgunLoaded'], 0, 5);
  s.beers = integer(data['beers'], 0, 100000);
  s.beersThrown = integer(data['beersThrown'] ?? 0, 0, 1000000);
  s.beerThrowTime = number(data['beerThrowTime'] ?? 0, 0, .45);
  s.fireCooldown = number(data['beerThrowCooldown'] ?? 0, 0, 1.25);
  s.restoreBeerFlights((data['beerFlights'] as List?) ?? const []);
  s.kills = integer(data['kills'], 0, 100000);
  s.shots = integer(data['shots'], 0, 1000000);
  s.hits = integer(data['hits'], 0, s.shots);
  s.time = number(data['time'], 0, 1e9);
  s.hasKey = data['hasKey'] as bool;
  s.gateOpen = data['gateOpen'] as bool;
  require(!s.gateOpen || s.gateMode != 'key' || s.hasKey);
  s.seenEvents.addAll((data['seenEvents'] as List? ?? const []).cast<String>());
  if (refugeReady != null) {
    if (refugeReady) {
      s.seenEvents.add('refuge_ready');
    } else {
      s.seenEvents.remove('refuge_ready');
    }
  }
  final notes = (data['foundMemos'] as List? ?? const []).cast<String>();
  require(notes.every((id) => villageMemos.any((m) => m.id == id)));
  s.foundMemos.addAll(notes);
  s.medallions.addAll((data['medallions'] as List? ?? const []).cast<String>());
  s.metYametaro = data['metYametaro'] as bool;
  s.receivedYametaroAmmo = data['receivedYametaroAmmo'] as bool;
  s.metTakosan = data['metTakosan'] as bool? ?? false;
  final companions = data['companionHealth'] as Map?;
  if (companions != null) {
    require(companions.length == s.companionHealth.length);
    for (final id in s.companionHealth.keys) {
      s.companionHealth[id] = number(
        companions[id],
        .001,
        HazardGameState.companionMaxHealth,
      );
    }
  }
  for (final entry in ((data['tradePurchases'] as Map?) ?? {}).entries) {
    require(['ammo', 'herb', 'shells', 'rocket'].contains(entry.key));
    s.tradePurchases[entry.key] = integer(
      entry.value,
      0,
      entry.key == 'rocket'
          ? 1
          : entry.key == 'herb'
          ? 2
          : 100000,
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
        'rocket',
        'ammo',
        'shells',
        'green',
        'red',
        'yellow',
        'mixed',
      ].contains(kind),
    );
    final w = ['shotgun', 'rocket'].contains(kind)
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
  require(s.weapon != 'rocket' || s.hasRocket);
  final broken = (data['crates'] as List).cast<String>().toSet();
  require(broken.every((id) => s.crates.any((c) => c.id == id)));
  for (final c in s.crates) {
    c.broken = broken.contains(c.id);
  }
  final authoredPickups = {for (final p in s.pickups) p.id: p};
  s.pickups.clear();
  final pickupIds = <String>{};
  final pickups = data['pickups'] as List;
  require(pickups.length < 200);
  for (final j in pickups) {
    require(pickupIds.add(j['id'] as String));
    require(itemNames.containsKey(j['kind']));
    final savedHeight = number(j['y'], 0, 6);
    final authored = authoredPickups[j['id']];
    final p = Pickup(
      j['id'],
      j['kind'],
      number(j['x'], -30, 30),
      // Adopt corrected display heights for map supplies while retaining the
      // exact location of dynamic enemy/crate drops and all taken flags.
      authored != null && authored.kind == j['kind'] ? authored.y : savedHeight,
      number(j['z'], -30, 35),
      amount: integer(j['amount'], 1, 50),
    )..taken = j['taken'] as bool;
    s.pickups.add(p);
  }
  // New authored supplies become available to existing saves once; taken IDs
  // remain in the checkpoint so revisiting/reloading cannot duplicate them.
  for (final entry in authoredPickups.entries) {
    if (!pickupIds.contains(entry.key)) s.pickups.add(entry.value);
  }
  final enemies = data['enemies'] as List;
  require(enemies.length == s.enemies.length);
  for (var i = 0; i < enemies.length; i++) {
    final j = enemies[i], e = s.enemies[i];
    require(j['id'] == e.id);
    e
      ..x = number(j['x'], -30, 30)
      ..y = number(j['y'] ?? 0, 0, 6)
      ..z = number(j['z'], -30, 35)
      ..heading = number(j['heading'], -1e9, 1e9)
      ..hp = number(j['hp'], -100, e.maxHp)
      ..alive = j['alive'] as bool
      ..active = j['active'] as bool
      ..dropped = j['dropped'] as bool
      ..suppressBeer = j['suppressBeer'] as bool? ?? false
      ..vanish = number(j['vanish'], 0, 1e9)
      ..alerted = j['alerted'] as bool
      ..notice = number(j['notice'], 0, 1e9)
      ..stun = number(j['stun'], 0, 30)
      ..cooldown = number(j['cooldown'], 0, 30)
      ..attackPending = j['attackPending'] as bool
      ..grabPending = j['grabPending'] as bool? ?? false
      ..grabCooldown = number(j['grabCooldown'] ?? 0, 0, 30)
      ..releaseTime = number(j['releaseTime'] ?? 0, 0, .7)
      ..windup = number(j['windup'], -.051, 30);
    if (e.boss && data['bossBalanceVersion'] == null && e.alive) {
      e.hp = (e.hp / 350 * e.maxHp).clamp(0, e.maxHp);
    }
    if (j.containsKey('ambientDance')) {
      require(
        const [
          null,
          'DanceStep',
          'DanceDisco',
          'DanceVictory',
        ].contains(j['ambientDance']),
      );
      e.ambientDance = e.boss ? null : j['ambientDance'] as String?;
    }
    e.hasBeenAlerted = e.alerted || (j['hasBeenAlerted'] as bool? ?? false);
    if (j.containsKey('awareness')) {
      require(EnemyAwareness.values.any((a) => a.name == j['awareness']));
      e.awareness = EnemyAwareness.values.byName(j['awareness']);
      e.discovered = j['discovered'] as bool? ?? false;
      final known = j['lastKnown'];
      if (known != null) {
        require(known is List && known.length == 3);
        e.lastKnownX = number(known[0], -30, 30);
        e.lastKnownY = number(known[1], 0, 6);
        e.lastKnownZ = number(known[2], -30, 35);
      }
      final seen = j['lastSeenByPlayer'];
      if (seen != null) {
        require(seen is List && seen.length == 3);
        e.lastSeenByPlayerX = number(seen[0], -30, 30);
        e.lastSeenByPlayerY = number(seen[1], 0, 6);
        e.lastSeenByPlayerZ = number(seen[2], -30, 35);
        e.lastSeenByPlayerHeading = number(
          j['lastSeenByPlayerHeading'],
          -1e9,
          1e9,
        );
      }
      require(!e.discovered || seen != null);
      e.contactAge = number(j['contactAge'] ?? 0, 0, 1e9);
      e.searchTime = number(j['searchTime'] ?? 0, 0, 1e9);
      final memory = j['stealthMemory'];
      if (memory != null) {
        require(memory is Map);
        require(
          memory['source'] is String &&
              (memory['source'] as String).length < 40,
        );
        require(
          const ['pursuer', 'flanker', 'watcher'].contains(memory['role']),
        );
        require(
          memory['reason'] is String &&
              (memory['reason'] as String).length < 100,
        );
        e.knowledgeSource = memory['source'];
        e.knowledgeTime = number(memory['time'], -1, s.time);
        e.lastVisualTime = number(memory['visualTime'], -1, s.time);
        e.lastSharedTime = number(memory['sharedTime'], -1, s.time);
        e.uncertainty = number(memory['uncertainty'], 0, 10);
        e.searchRemaining = number(memory['remaining'], 0, 30);
        e.searchDuration = number(memory['duration'], 0, 30);
        e.pursuitRemaining = number(memory['pursuit'], 0, 2);
        e.weakNoiseExtension = number(memory['extension'], 0, 4.001);
        e.returnRemaining = number(memory['returnRemaining'], 0, 10);
        e.searchRole = memory['role'];
        e.feedbackReason = memory['reason'];
        e.observedHeading = number(memory['observedHeading'], -1e9, 1e9);
        e.hadVisualContact = memory['hadVisualContact'] as bool;
        e.homeHeading = memory['homeHeading'] == null
            ? null
            : number(memory['homeHeading'], -1e9, 1e9);
        e.searchIndex = integer(memory['searchIndex'], 0, 6);
        e.pointTime = number(memory['pointTime'], 0, 4);
        e.lookTime = number(memory['lookTime'], 0, 4);
        e.patrolIndex = integer(memory['patrolIndex'], 0, 100);
        e.patrolWait = number(memory['patrolWait'], 0, 10);
        e.lureAttention = number(memory['lureAttention'], 0, 5);
        e.lureHold = number(memory['lureHold'], 0, 5);
        vm.Vector3 point(dynamic p) {
          require(p is List && p.length == 3);
          return vm.Vector3(
            number(p[0], -30, 30),
            number(p[1], 0, 6),
            number(p[2], -30, 35),
          );
        }

        if (memory['returnTarget'] != null) {
          e.returnTarget = point(memory['returnTarget']);
        }
        if (memory['target'] != null) {
          e.investigationTarget = point(memory['target']);
        }
        require(
          memory['points'] is List && (memory['points'] as List).length <= 6,
        );
        e.searchPoints.addAll((memory['points'] as List).map(point));
        require(
          e.searchPoints.isEmpty || e.searchIndex < e.searchPoints.length,
        );
      } else if (e.lastKnownX != null && !e.boss) {
        // Old saves preserve their recorded cue without re-reading the player.
        e.searchDuration = 15.8;
        e.searchRemaining = (15.8 - e.contactAge).clamp(.1, 15.8);
        e.pursuitRemaining = (1.8 - e.contactAge).clamp(0, 1.8);
        e.knowledgeSource = 'legacy';
      }
    }
    e.climb = LadderTraversal.restore(j['climb'], s.ladder, e.x, e.y, e.z);
    e.vault = WindowTraversal.restore(
      j['vault'],
      s.windows,
      e.x,
      e.y,
      e.z,
      enemy: true,
    );
    require(
      e.vault == null || (e.climb == null && e.alive && e.active && !e.boss),
    );
    e.fallingFromLadder = j['fallingFromLadder'] as bool? ?? false;
    require(e.climb == null || (e.alive && e.active && !e.boss));
    require(!e.fallingFromLadder || (!e.alive && e.climb == null));
    e.meleeRecovery = number(
      j['meleeRecovery'] ?? 0,
      0,
      Enemy.meleeFollowThrough,
    );
    if (j['approachHeading'] != null) {
      e.approachHeading = number(j['approachHeading'], -1e9, 1e9);
    }
    if (data['encounterVersion'] == null &&
        s.zoneId == 'village' &&
        e.id >= 4 &&
        e.alive) {
      e.active = true;
    }
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
    e.companionTarget = j['companionTarget'] as String?;
    if (e.companionTarget != null) {
      require(
        (map['npcs'] as List).any((n) => n['id'] == e.companionTarget) &&
            e.alive &&
            e.active &&
            e.alerted &&
            !e.grabPending &&
            e.climb == null &&
            e.vault == null &&
            s.grapple?.enemyId != e.id,
      );
    }
    require(e.alive == (e.hp > 0) && (!e.dropped || !e.alive));
  }
  require(s.enemies.where((e) => !e.alive).length <= s.kills);
  if (s.grapple != null) {
    final g = s.grapple!;
    final enemy = s.enemies.where((e) => e.id == g.enemyId).firstOrNull;
    final dx = g.startX - g.playerX, dz = g.startZ - g.playerZ;
    require(
      enemy != null &&
          enemy.alive &&
          enemy.active &&
          !enemy.boss &&
          enemy.climb == null &&
          enemy.vault == null &&
          !enemy.attackPending &&
          (enemy.x - g.enemyX).abs() < .02 &&
          (enemy.z - g.enemyZ).abs() < .02 &&
          (enemy.y - g.playerY).abs() < .02 &&
          (s.x - g.playerX).abs() < .02 &&
          (s.z - g.playerZ).abs() < .02 &&
          (s.y - g.playerY).abs() < .02 &&
          dx * dx + dz * dz >= .5 * .5 &&
          dx * dx + dz * dz <= 1.15 * 1.15,
    );
  }
  require(
    s.enemies.where((e) => e.climb != null).length +
            (s.climb == null ? 0 : 1) <=
        1,
  );
  for (final w in s.windows) {
    require(
      s.enemies.where((e) => e.vault?.window.id == w.id).length +
              (s.vault?.window.id == w.id ? 1 : 0) <=
          1,
    );
  }
  s.normalizeRefugeOccupants();
  // A newly restored supply NPC may stand where an older evacuated save put
  // the player. Move only that overlap to a nearby valid approach position.
  if (refugeReady == false &&
      !s.hasRefuge &&
      !s.traversing &&
      s.y < 1.3 &&
      s.npcs.any((n) {
        final dx = s.x - (n['x'] as num), dz = s.z - (n['z'] as num);
        return dx * dx + dz * dz < .61 * .61;
      })) {
    final oldX = s.x, oldZ = s.z;
    for (final offset in [(0.0, -1.3), (-1.3, 0.0), (1.3, 0.0), (0.0, 1.3)]) {
      if (!s.blocked(oldX + offset.$1, oldZ + offset.$2, s.y)) {
        s.x = oldX + offset.$1;
        s.z = oldZ + offset.$2;
        s.grapple = null;
        s.breakFreeTime = 0;
        break;
      }
    }
  }

  require(s.traversing || !s.blocked(s.x, s.z, s.y));
  s.phase = PlayPhase.playing;
  s.invulnerable = .5;
  s.say('チェックポイントから探索を再開した。');
  return s;
}
