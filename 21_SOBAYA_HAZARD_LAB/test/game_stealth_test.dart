import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';
import 'package:sobaya_hazard_lab/game/game_settings.dart';

HazardGameState arena() {
  final map = jsonDecode(
    File('assets/village.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  map['solids'] = <dynamic>[];
  map['houses'] = <dynamic>[];
  map['ramps'] = <dynamic>[];
  map['tower'] = null;
  map['npcs'] = <dynamic>[];
  map['items'] = <dynamic>[];
  map['crates'] = <dynamic>[];
  map['collection'] = <dynamic>[];
  map['windows'] = <dynamic>[];
  map['exits'] = <dynamic>[];
  map['enemies'] = [
    {'id': 0, 'x': 0, 'z': 0, 'active': true},
  ];
  return HazardGameState(map)
    ..x = 0
    ..z = -4
    ..yaw = math.pi;
}

void advance(HazardGameState s, double seconds) {
  for (var i = 0; i < (seconds * 60).ceil(); i++) {
    s.tick(1 / 60);
  }
}

Obstacle wall({
  double x = 0,
  double z = -2,
  double w = 8,
  double d = .25,
  double bottom = 0,
  double top = 3,
}) => Obstacle({'x': x, 'z': z, 'w': w, 'd': d, 'bottom': bottom, 'top': top});

void main() {
  test(
    'searching guard cannot reacquire a silent player behind it to start melee',
    () {
      final s = arena()
        ..z = -.8
        ..sneaking = true;
      final e = s.enemies.single
        ..alerted = true
        ..heading = 0
        ..lastKnownX = 0
        ..lastKnownY = 0
        ..lastKnownZ = 4;
      s.tick(.05);
      expect(e.seesPlayer, false);
      expect(e.attackPending, false);
      expect(e.lastKnownZ, 4);
      expect(
        e.z,
        greaterThan(0),
        reason: 'Keep searching the known position instead of stopping at the unseen player',
      );
    },
  );

  test(
    'visible head above low cover discovers a guard when its torso is hidden',
    () {
      final s = arena();
      final e = s.enemies.single;
      s.obstacles.add(wall(z: -.5, top: 1.4));
      s.enemyVisibleInView = (point) => point.y > 1.5;
      s.tick(.05);
      expect(e.discovered, true);
      expect(e.visibleToPlayer, true);
    },
  );

  test(
    'offscreen clear head cannot share visibility with an occluded torso',
    () {
      final s = arena();
      final e = s.enemies.single;
      s.obstacles.add(wall(z: -.5, top: 1.4));
      s.enemyVisibleInView = (point) => point.y < 1.5;
      s.tick(.05);
      expect(e.discovered, false);
      expect(e.visibleToPlayer, false);
    },
  );

  test('shotgun report wins over the following audible crate break and is consumed once', () {
    final s = arena()..z = -8;
    final enemy = s.enemies.single;
    final crate = Breakable('sound_crate', 'crate', 0, -3);
    s.crates.add(crate);
    s.addItem('shotgun', 1);
    s.equip('shotgun');
    s.aiming = true;
    s.shoot(vm.Vector3(0, .65, -8), vm.Vector3(0, 0, 1));
    expect(crate.broken, true);
    expect(enemy.hp, enemy.maxHp);
    // Move out of sight before processing the two real firing events, so
    // perception can only infer the muzzle's saved location from the sound.
    s.x = 15;
    s.z = -12;
    s.tick(.01);
    expect(enemy.awareness, EnemyAwareness.investigating);
    expect(enemy.lastKnownX, 0);
    expect(enemy.lastKnownZ, -8);
    expect(enemy.heardNoiseSerial, 2);
    s.tick(.01);
    expect(enemy.lastKnownZ, -8);
    expect(enemy.contactAge, closeTo(.01, .00001));
  });

  test('sound priority uses received strength after walls and distance', () {
    final s = arena()
      ..x = 15
      ..z = -12;
    final enemy = s.enemies.single;
    s.obstacles.add(wall(z: -5));
    // The 34m report behind a wall is audible, but the clear 7m break at
    // three metres is stronger at this listener. Event order cannot decide.
    s.emitNoise('break', radius: 7, sourceX: 0, sourceZ: -3);
    s.emitNoise('shotgun', radius: 34, sourceX: 0, sourceZ: -8);
    s.tick(.01);
    expect(enemy.awareness, EnemyAwareness.investigating);
    expect(enemy.lastKnownZ, -3);
    expect(enemy.heardNoiseSerial, 2);
  });

  test(
    'giant sight overlay clears low cover at the same eye height as detection',
    () {
      final s = arena()..z = 10;
      final giant = Enemy(10, 0, 0, boss: true)..active = true;
      s.enemies
        ..clear()
        ..add(giant);
      s.obstacles.add(wall(z: 2, top: 2));
      expect(s.enemyCanSeePlayer(giant), true);
      final cone = s.enemySightPolygon(giant);
      // The middle sample points straight ahead over the low wall.
      expect(cone[8].y, closeTo(s.enemySightRange(giant), .001));
    },
  );

  test(
    'portrait camera rejects enemies outside its narrow horizontal frustum',
    () {
      final s = arena()..viewAspect = .46;
      final e = s.enemies.single..x = 2;
      advance(s, .05);
      expect(e.discovered, false);
      s.viewAspect = 1.6;
      advance(s, .05);
      expect(e.discovered, true);
      s.enemyVisibleInView = (_) => false;
      advance(s, .05);
      expect(e.visibleToPlayer, false);
    },
  );

  test('shotgun headshot kills one enemy at a time on every difficulty', () {
    for (final difficulty in HazardDifficulty.values) {
      final s = arena()..difficulty = difficulty;
      final front = s.enemies.single;
      final behind = Enemy(1, 0, 2)..active = true;
      s.enemies.add(behind);
      s.addItem('shotgun', 1);
      s.equip('shotgun');
      s.shotgunLoaded = 1;
      s.aiming = true;
      s.shoot(vm.Vector3(0, 1.68, -4), vm.Vector3(0, 0, 1));
      expect(front.alive, false);
      expect(behind.hp, behind.maxHp);
      expect(s.shots, 1);
      expect(s.kills, 1);
      expect(s.lastShotPart, ShotPart.head);
      expect(s.playerNoiseRadius, 34);
    }
  });

  test('vision requires front cone and unobstructed vertical line even at close range', () {
    final s = arena()..z = -1.2;
    final e = s.enemies.single;
    advance(s, 1);
    expect(e.alerted, false);
    expect(e.notice, 0);
    e.heading = math.pi;
    s.obstacles.add(wall(z: -.6));
    advance(s, 1);
    expect(e.alerted, false);
    s.obstacles.clear();
    advance(s, .3);
    expect(e.alerted, true);
    expect(e.seesPlayer, true);
    // Looking up/down cannot see through the floor of a different storey.
    e.alerted = false;
    e.notice = 0;
    s.y = 3;
    s.obstacles.add(wall(z: 0, d: 10, bottom: 2.6, top: 3));
    expect(s.enemyCanSeePlayer(e), false);
  });

  test('walk and sprint are audible behind enemies; slow approach reaches E range silently', () {
    for (final mode in ['sneak', 'walk', 'sprint']) {
      final s = arena()
        ..z = -2.3
        ..inputY = 1;
      s.sneaking = mode == 'sneak';
      s.sprint = mode == 'sprint';
      final e = s.enemies.single;
      advance(s, mode == 'sneak' ? 1.3 : .5);
      if (mode == 'sneak') {
        expect(e.awareness, EnemyAwareness.idle);
        expect(s.stealthTarget, e);
      } else {
        expect(e.awareness, isNot(EnemyAwareness.idle));
        expect(e.lastKnownZ, isNotNull);
      }
    }
  });

  test(
    'blocked movement emits no footsteps and sprint noise exceeds walking',
    () {
      final s = arena()
        ..z = -2.4
        ..inputY = 1
        ..sprint = true;
      s.obstacles.add(wall());
      advance(s, .8);
      expect(s.playerNoiseRadius, 0);
      final sprint = s.movementNoiseRadius;
      s.sprint = false;
      final walk = s.movementNoiseRadius;
      s.sneaking = true;
      expect(sprint, greaterThan(walk));
      expect(walk, greaterThan(s.movementNoiseRadius));
    },
  );

  test('muffled footsteps do not travel through cover, gunshot investigation uses its origin', () {
    final s = arena();
    final e = s.enemies.single;
    s.obstacles.add(wall());
    s.emitNoise('walk', radius: 4);
    advance(s, .1);
    expect(e.awareness, EnemyAwareness.idle);
    s.emitNoise('handgun', radius: 22);
    s.x = 12;
    advance(s, .1);
    expect(e.alerted, false);
    expect(e.awareness, EnemyAwareness.investigating);
    expect(e.lastKnownX, 0);
    expect(e.lastKnownZ, -4);
    expect(e.seesPlayer, false);
  });

  test(
    'shotgun sound reaches farther without making hidden player omniscient',
    () {
      final s = arena()
        ..x = 0
        ..z = -22;
      final e = s.enemies.single;
      s.emitNoise('handgun', radius: 22);
      advance(s, .1);
      expect(e.awareness, EnemyAwareness.idle); // 3D distance exceeds 22.
      s.addItem('shotgun', 1);
      s.equip('shotgun');
      s.aiming = true;
      s.shoot(vm.Vector3(0, 1.4, -22), vm.Vector3(1, 0, 0));
      advance(s, .1);
      expect(s.playerNoiseRadius, 34);
      expect(e.awareness, EnemyAwareness.investigating);
      expect(e.alerted, false);
      expect(e.lastKnownZ, -22);
    },
  );

  test('losing contact pursues last sight position then drops hostility at distance', () {
    final s = arena()..z = 6;
    final e = s.enemies.single;
    advance(s, .7);
    expect(e.alerted, true);
    expect(e.lastKnownZ, 6);
    s.x = 20;
    s.z = -15;
    advance(s, 2.5);
    expect(e.alerted, true);
    expect(e.awareness, EnemyAwareness.searching);
    expect(e.lastKnownX, 0);
    expect(e.lastKnownZ, 6);
    advance(s, 1);
    expect(e.alerted, false);
    expect(e.awareness, EnemyAwareness.idle);
    expect(e.lastKnownX, isNull);
  });

  test('player discovery requires looking with LOS and remembered dots do not track hidden movement', () {
    final s = arena()..yaw = 0;
    final e = s.enemies.single;
    advance(s, .05);
    expect(e.discovered, false);
    s.yaw = math.pi;
    s.obstacles.add(wall());
    advance(s, .05);
    expect(e.discovered, false);
    s.obstacles.clear();
    advance(s, .05);
    expect(e.discovered, true);
    expect(e.lastSeenByPlayerX, 0);
    s.yaw = 0;
    e.x = 3;
    advance(s, .05);
    expect(e.visibleToPlayer, false);
    expect(e.lastSeenByPlayerX, 0);
    final restored = restoreHazardCheckpoint(s.checkpoint(), s.map, {});
    expect(restored.enemies.single.discovered, true);
    expect(restored.enemies.single.lastSeenByPlayerX, 0);
  });

  test('rear beer break revalidates E and gives one silent defeat without a beer drop', () {
    final s = arena()..z = -1.3;
    final e = s.enemies.single;
    advance(s, .05);
    expect(s.interaction, 'stealth:0');
    e.alerted = true;
    s.interact();
    expect(e.alive, true);
    e.alerted = false;
    e.notice = 0;
    s.interact();
    expect(e.alive, false);
    expect(s.kills, 1);
    expect(e.suppressBeer, true);
    expect(s.message, contains('ステルス成功'));
    s.interact();
    advance(s, 1);
    expect(s.kills, 1);
    expect(s.pickups.where((p) => p.kind == 'beer'), isEmpty);
  });

  test('frontal, covered, alerted, upper floor and boss enemies cannot be stealth killed', () {
    final s = arena()..z = 1.3;
    final e = s.enemies.single;
    expect(s.stealthTarget, isNull);
    s.z = -1.3;
    s.obstacles.add(wall(z: -.6));
    expect(s.stealthTarget, isNull);
    s.obstacles.clear();
    e.alerted = true;
    expect(s.stealthTarget, isNull);
    e.alerted = false;
    e.y = 3;
    expect(s.stealthTarget, isNull);
    s.enemies
      ..clear()
      ..add(Enemy(10, 0, 0, boss: true)..active = true);
    expect(s.stealthTarget, isNull);
  });

  test('investigation knowledge and age survive restore instead of acquiring player location', () {
    final s = arena();
    s.obstacles.add(wall());
    s.emitNoise('handgun', radius: 22);
    advance(s, .1);
    s.x = 14;
    final saved = s.checkpoint();
    final restored = restoreHazardCheckpoint(saved, s.map, {});
    final e = restored.enemies.single;
    expect(e.awareness, EnemyAwareness.investigating);
    expect(e.lastKnownX, 0);
    advance(restored, .1);
    expect(e.lastKnownX, 0);
    saved['enemies'][0]['lastKnown'][0] = double.nan;
    expect(
      () => restoreHazardCheckpoint(saved, s.map, {}),
      throwsFormatException,
    );
  });
}
