import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';

import 'game_stealth_test.dart' as fixture;

void main() {
  test('real barn wall masks vision and repeated footfalls never reveal an exact coordinate', () {
    final map = jsonDecode(
      File('assets/village.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final s = HazardGameState(map)
      ..x = -8.8
      ..z = 11;
    final e = Enemy(80, -10, 11)
      ..active = true
      ..heading = math.pi / 2
      ..stun = 30;
    s.enemies
      ..clear()
      ..add(e);
    expect(s.enemyCanSeePlayer(e), false);
    s.emitNoise('walk', radius: 4);
    s.tick(.05);
    expect(e.knowledgeSource, 'walk');
    expect(e.uncertainty, greaterThan(2));
    final memory = [e.lastKnownX, e.lastKnownY, e.lastKnownZ];
    expect(
      math.pow(e.lastKnownX! - s.x, 2) + math.pow(e.lastKnownZ! - s.z, 2),
      greaterThan(.2),
    );
    for (var i = 0; i < 15; i++) {
      s.emitNoise('walk', radius: 4);
      s.tick(.05);
      expect([e.lastKnownX, e.lastKnownY, e.lastKnownZ], memory);
    }
    s.x = -6;
    fixture.advance(s, .8);
    expect(e.seesPlayer, false);
    expect([e.lastKnownX, e.lastKnownY, e.lastKnownZ], memory);
  });

  test('silent relocation cannot change remembered cue or finite search candidates', () {
    final s = fixture.arena()..z = -12;
    final e = s.enemies.single
      ..alerted = true
      ..lastKnownX = 0
      ..lastKnownY = 0
      ..lastKnownZ = 4
      ..stun = 30;
    fixture.advance(s, 2);
    final memory = [e.lastKnownX, e.lastKnownZ];
    final candidates = e.searchPoints.map((p) => p.clone()).toList();
    expect(candidates.length, inInclusiveRange(1, 6));
    s.x = 15;
    s.z = -20;
    fixture.advance(s, 1);
    expect([e.lastKnownX, e.lastKnownZ], memory);
    expect(e.searchPoints, candidates);
    expect(e.alerted, true);
  });

  test('search expires at the HUD deadline even when movement and route are blocked', () {
    final s = fixture.arena()..z = -20;
    final e = s.enemies.single
      ..alerted = true
      ..lastKnownX = 5
      ..lastKnownY = 0
      ..lastKnownZ = 5
      ..stun = 30;
    s.tick(.05);
    expect(s.stealthFeedback.phase, 'searching');
    final remaining = s.stealthFeedback.remaining;
    fixture.advance(s, remaining - .1);
    expect(e.alerted, true);
    expect(s.stealthFeedback.remaining, lessThan(.15));
    fixture.advance(s, .2);
    expect(e.alerted, false);
    expect(e.awareness, anyOf(EnemyAwareness.returning, EnemyAwareness.idle));
  });

  test('weak footfalls add at most four seconds and one event is consumed only once', () {
    final s = fixture.arena()..z = -1.8;
    s.obstacles.add(fixture.wall(z: -.9));
    final e = s.enemies.single
      ..alerted = true
      ..lastKnownX = 0
      ..lastKnownY = 0
      ..lastKnownZ = 4
      ..stun = 30;
    s.tick(.05);
    for (var i = 0; i < 30; i++) {
      s.emitNoise('walk', radius: 5);
      s.tick(.05);
    }
    expect(e.weakNoiseExtension, closeTo(4, .001));
    final remaining = e.searchRemaining;
    fixture.advance(s, .5);
    expect(e.searchRemaining, closeTo(remaining - .5, .001));
    fixture.advance(s, e.searchRemaining + .1);
    expect(e.alerted, false);
  });

  test(
    'a new gun report prolongs a real search without disclosing the shooter',
    () {
      final s = fixture.arena()..z = -12;
      final e = s.enemies.single
        ..alerted = true
        ..lastKnownX = 0
        ..lastKnownY = 0
        ..lastKnownZ = 4
        ..stun = 30;
      fixture.advance(s, 4);
      s.emitNoise('shotgun', radius: 34, sourceX: 3, sourceZ: -8);
      s.tick(.05);
      expect(e.searchRemaining, greaterThan(19));
      expect(e.knowledgeSource, 'shotgun');
      expect(e.lastKnownZ, closeTo(-8, 2));
      expect(e.lastKnownZ, isNot(s.z));
      expect(s.stealthFeedback.reason, '新しい銃声');
    },
  );

  test('nearby sharing has one flanker and no relay from an unseen player', () {
    final s = fixture.arena()
      ..x = 0
      ..z = 6;
    final main = s.enemies.single..stun = 30;
    final near = Enemy(1, 3, 0)
      ..active = true
      ..heading = math.pi
      ..stun = 30;
    final farther = Enemy(2, 10, 0)
      ..active = true
      ..heading = math.pi
      ..stun = 30;
    s.enemies.addAll([near, farther]);
    fixture.advance(s, .7);
    expect(main.alerted, true);
    expect(near.knowledgeSource, 'shared_sight');
    expect(near.searchRole, 'flanker');
    expect(farther.lastKnownX, isNull);
    s.x = -20;
    s.z = -20;
    final sharedAt = near.knowledgeTime;
    final remaining = near.searchRemaining;
    fixture.advance(s, 2);
    expect(near.knowledgeTime, sharedAt);
    expect(near.searchRemaining, closeTo(remaining - 2, .02));
    expect(farther.lastKnownX, isNull);
  });

  test(
    'a lure recruits all nearby enemies and releases them after a finite hold',
    () {
      final s = fixture.arena()..z = -20;
      final a = s.enemies.single;
      final b = Enemy(1, -2, 0)..active = true;
      s.enemies.add(b);
      s.emitNoise('beer_lure', radius: 8, sourceX: 2, sourceZ: 0);
      s.tick(.05);
      expect(a.investigationTarget, isNotNull);
      expect(a.lureAttention, 5);
      expect(b.investigationTarget, isNotNull);
      expect(b.alerted, false);
      fixture.advance(s, 4);
      expect(a.lureHold, greaterThan(0));
      expect(a.awareness, EnemyAwareness.investigating);
      fixture.advance(s, 5);
      expect(a.awareness, anyOf(EnemyAwareness.returning, EnemyAwareness.idle));
    },
  );

  test('beer interrupts visible pursuit, but gunfire cancels distraction', () {
    final s = fixture.arena()..z = 6;
    final e = s.enemies.single..stun = 30;
    fixture.advance(s, .7);
    expect(e.alerted, true);
    s.emitNoise('beer_lure', radius: 14, sourceX: 2, sourceZ: 0);
    s.tick(.05);
    expect(e.investigationTarget, isNotNull);
    expect(e.lureAttention, 5);
    expect(e.seesPlayer, false);
    expect(e.alerted, true);
    s.emitNoise('handgun', radius: 22);
    s.tick(.05);
    expect(e.investigationTarget, isNull);
    expect(e.seesPlayer, true);
  });

  test(
    'a crowd of visible pursuers diverts together, distant enemies do not',
    () {
      final s = fixture.arena()..z = 6;
      s.enemies.add(Enemy(1, 2, 0)..active = true);
      s.enemies.add(Enemy(2, 25, 0)..active = true);
      for (final e in s.enemies) {
        e.stun = 30;
      }
      fixture.advance(s, .7);
      expect(s.enemies.take(2).every((e) => e.alerted), true);
      s.emitNoise('beer_lure', radius: 14, sourceX: 3, sourceZ: 0);
      s.tick(.05);
      expect(
        s.enemies.take(2).every((e) => e.lureAttention == 5 && !e.seesPlayer),
        true,
      );
      expect(s.enemies.last.lureAttention, 0);
    },
  );

  test(
    'beer interrupts a melee impact already winding up at point blank range',
    () {
      final s = fixture.arena()..z = .8;
      final e = s.enemies.single
        ..alerted = true
        ..attackPending = true
        ..windup = .01;
      final health = s.health;
      s.emitNoise('beer_lure', radius: 18, sourceX: 8, sourceZ: 0);
      s.tick(.05);
      expect(e.lureAttention, 5);
      expect(e.attackPending, false);
      expect(e.seesPlayer, false);
      expect(s.health, health);
      fixture.advance(s, 1);
      expect(s.health, health);
      expect(e.investigationTarget, isNotNull);
    },
  );

  test('beer reaches across one wall at twelve metres while footsteps remain muffled', () {
    final s = fixture.arena()..z = -20;
    s.obstacles.add(fixture.wall(z: 6));
    s.emitNoise(
      'beer_lure',
      radius: hazardBeerLureRadius,
      sourceX: 0,
      sourceZ: 12,
    );
    s.tick(.05);
    expect(s.enemies.single.investigationTarget, isNotNull);
  });

  test('hidden player escapes even when beer cannot be reached', () {
    final s = fixture.arena()..z = 6;
    final e = s.enemies.single..stun = 30;
    fixture.advance(s, .7);
    s.emitNoise('beer_lure', radius: 14, sourceX: 5, sourceZ: 0);
    s.tick(.05);
    s.z = -20;
    fixture.advance(s, 10.2);
    expect(e.alerted, false);
    expect(e.investigationTarget, isNull);
  });

  test('visible player is reacquired after distraction, close approach does not break it', () {
    final s = fixture.arena()..z = 6;
    final e = s.enemies.single..stun = 30;
    fixture.advance(s, .7);
    s.emitNoise('beer_lure', radius: 14, sourceX: 5, sourceZ: 0);
    s.tick(.05);
    fixture.advance(s, 10.2);
    expect(e.seesPlayer, true);
    expect(e.alerted, true);
    s.emitNoise('beer_lure', radius: 14, sourceX: 5, sourceZ: 0);
    s.tick(.05);
    s.z = 1;
    s.tick(.05);
    expect(e.investigationTarget, isNotNull);
    expect(e.seesPlayer, false);
  });

  test('returning navigates around a wall to the original post instead of camping at cover', () {
    final s = fixture.arena()
      ..x = -20
      ..z = -20;
    final e = s.enemies.single
      ..x = 6
      ..z = 6
      ..awareness = EnemyAwareness.returning
      ..returnRemaining = 8;
    s.obstacles.add(fixture.wall(x: 3, z: 3, w: .3, d: 7));
    fixture.advance(s, 5);
    final halfway = math.sqrt(e.x * e.x + e.z * e.z);
    expect(halfway, lessThan(math.sqrt(72)));
    fixture.advance(s, 16);
    expect(e.awareness, EnemyAwareness.idle);
    expect(math.sqrt(e.x * e.x + e.z * e.z), lessThan(.85));
    expect(e.homeX, 0);
    expect(e.homeZ, 0);
  });

  test('checkpoint preserves search deadlines, candidates, lure and home destination', () {
    final s = fixture.arena()..z = -20;
    final e = s.enemies.single
      ..alerted = true
      ..lastKnownX = 2
      ..lastKnownY = 0
      ..lastKnownZ = 5
      ..stun = 30;
    fixture.advance(s, 3);
    s.emitNoise('beer_lure', radius: 8, sourceX: 2, sourceZ: 0);
    s.tick(.05);
    final restored = restoreHazardCheckpoint(s.checkpoint(), s.map, {});
    final saved = restored.enemies.single;
    expect(saved.searchRemaining, e.searchRemaining);
    expect(saved.searchPoints, e.searchPoints);
    expect(saved.investigationTarget, e.investigationTarget);
    expect(saved.lureAttention, e.lureAttention);
    expect(saved.homeX, 0);
    expect(saved.homeZ, 0);
    expect(saved.knowledgeTime, e.knowledgeTime);
    restored.x = -20;
    fixture.advance(restored, .5);
    expect(saved.searchRemaining, closeTo(e.searchRemaining - .5, .02));
  });

  test('a blocked home uses a reachable nearby post, without changing the authored home', () {
    final s = fixture.arena()
      ..x = -20
      ..z = -20;
    final e = s.enemies.single
      ..x = 5
      ..z = 5
      ..awareness = EnemyAwareness.returning
      ..returnRemaining = 8;
    s.crates.add(Breakable('blocked_post', 'crate', 0, 0));
    fixture.advance(s, 18);
    expect(e.awareness, EnemyAwareness.idle);
    expect(math.sqrt(e.x * e.x + e.z * e.z), lessThan(2));
    expect(s.blocked(e.x, e.z, e.y, radius: .37), false);
    expect([e.homeX, e.homeZ], [0, 0]);
  });

  test('a sealed route returns to the closest reachable point instead of waiting forever', () {
    final s = fixture.arena()
      ..x = -20
      ..z = -20;
    s.obstacles.add(fixture.wall(x: 2, z: 0, w: .3, d: 100));
    final e = s.enemies.single
      ..x = 8
      ..z = 8
      ..awareness = EnemyAwareness.returning
      ..returnRemaining = 8;
    fixture.advance(s, 25);
    expect(e.returnTarget, isNotNull);
    expect(e.awareness, EnemyAwareness.idle);
    expect(e.x, lessThan(4));
    expect((e.z - e.returnTarget!.z).abs(), lessThan(.85));
    expect([e.homeX, e.homeZ], [0, 0]);
    final restored = restoreHazardCheckpoint(s.checkpoint(), s.map, {});
    expect(restored.enemies.single.homeX, 0);
  });

  test(
    'a started boss encounter retains its threat through a brief loss of sight',
    () {
      final s = fixture.arena()
        ..x = 10
        ..z = -20;
      final boss = Enemy(90, 0, 0, boss: true)
        ..active = true
        ..alerted = true;
      s.enemies
        ..clear()
        ..add(boss);
      expect(boss.seesPlayer, false);
      expect(s.stealthFeedback.phase, 'chasing');
      expect(s.stealthFeedback.bearing, isNull);
      boss.alive = false;
      expect(s.stealthFeedback.phase, 'calm');
    },
  );

  test('an empty search plan waits before retrying and recovers after crates break', () {
    final s = fixture.arena()
      ..x = -20
      ..z = -20;
    final e = s.enemies.single
      ..alerted = true
      ..stun = 30
      ..lastKnownX = 0
      ..lastKnownY = 0
      ..lastKnownZ = 5
      ..searchDuration = 15
      ..searchRemaining = 15;
    for (var px = -5; px <= 5; px++) {
      for (var pz = 0; pz <= 10; pz++) {
        s.crates.add(
          Breakable('plan_${px}_$pz', 'crate', px.toDouble(), pz.toDouble()),
        );
      }
    }
    s.tick(.05);
    expect(e.searchPoints, isEmpty);
    expect(e.searchPlanRetry, 1);
    fixture.advance(s, .25);
    expect(
      e.searchPlanRetry,
      closeTo(.75, .001),
      reason: 'A failed plan must not be rebuilt every frame',
    );
    for (final c in s.crates) {
      c.broken = true;
    }
    fixture.advance(s, 1.05);
    expect(e.searchPoints, isNotEmpty);
    expect(e.searchPlanRetry, 0);
  });

  test('undiscovered nearby guards never provide direction or a music threat by proximity', () {
    final s = fixture.arena()
      ..z = -.9
      ..yaw = 0;
    s.tick(.05);
    expect(s.stealthFeedback.phase, 'calm');
    expect(s.stealthFeedback.bearing, isNull);
  });
}
