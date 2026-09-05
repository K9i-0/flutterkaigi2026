// Deterministic campaign audit. No teleports, free items, disabled enemies,
// altered health or cooldown resets. This verifies rules/progression, not human
// aiming skill, first-play duration, camera framing or frame performance.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

import 'package:sobaya_hazard_lab/game/game_campaign.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';

class CampaignAudit {
  CampaignAudit(this.campaign);
  HazardCampaign campaign;
  HazardGameState get s => campaign.state;
  final events = <Map<String, dynamic>>[];
  final weaponsUsed = <String>{};
  bool completionist = false;
  int frames = 0;
  void record(String event) {
    final row = {
      'event': event,
      'region': s.zoneId,
      'seconds': s.time,
      'x': s.x,
      'y': s.y,
      'z': s.z,
      'health': s.health,
      'kills': s.kills,
      'shots': s.shots,
      'hits': s.hits,
      'loaded': s.loaded,
      'reserve': s.reserve,
      'beers': s.beers,
      'collection': s.collected.length,
    };
    events.add(row);
    stdout.writeln(jsonEncode(row));
  }

  void frame() {
    s.tick(1 / 60);
    frames++;
    if (s.phase == PlayPhase.dead) throw StateError('Died ${s.inspect()}');
    if (frames > 60 * 1800) {
      throw StateError('Audit exceeded 30 simulated minutes');
    }
  }

  void input(double dx, double dz) {
    s.yaw = 0;
    s.inputX = -dx;
    s.inputY = -dz;
    s.aiming = false;
    s.sprint = true;
  }

  bool visible(double x, double y, double z) {
    final origin = vm.Vector3(s.x, s.y + 1.25, s.z);
    final d = vm.Vector3(x, y, z) - origin;
    return s.wallDistance(origin, d.normalized(), d.length) >= d.length - .1;
  }

  void sidestep(double dx, double dz) {
    final len = math.sqrt(dx * dx + dz * dz);
    dx /= len;
    dz /= len;
    // Check both lateral directions; neither is a teleport.
    for (final v in [(dx, dz), (-dx, -dz), (-dz, dx), (dz, -dx)]) {
      if ([
        .4,
        .8,
        1.2,
        1.6,
        2.0,
      ].every((d) => !s.blocked(s.x + v.$1 * d, s.z + v.$2 * d, s.y))) {
        input(v.$1, v.$2);
        return;
      }
    }
    input(dx, dz);
  }

  bool combat() {
    final enemies =
        s.enemies
            .where(
              (e) =>
                  e.alive &&
                  e.active &&
                  !(e.boss && s.x < 1 && !e.alerted) &&
                  math.pow(e.x - s.x, 2) + math.pow(e.z - s.z, 2) < 12 * 12 &&
                  visible(e.x, 1.1, e.z),
            )
            .toList()
          ..sort(
            (a, b) => (math.pow(a.x - s.x, 2) + math.pow(a.z - s.z, 2))
                .compareTo(math.pow(b.x - s.x, 2) + math.pow(b.z - s.z, 2)),
          );
    if (enemies.isEmpty) return false;
    final e = enemies.first;
    s.stopInput();
    if (s.health < 60) {
      final herb = s.bag
          .where((i) => ['green', 'mixed'].contains(i.kind))
          .firstOrNull;
      if (herb != null) s.useBag(herb.id);
    }
    if (e.bossMove == BossMove.chargeWindup) {
      sidestep(math.cos(e.heading), -math.sin(e.heading));
    } else if (e.bossMove == BossMove.swipeWindup ||
        e.bossMove == BossMove.slamWindup) {
      sidestep(s.x - e.x, s.z - e.z);
    } else if (e.bossMove == BossMove.charging) {
      // Let the locked charge pass; do not chase its moving center.
    } else if (e.boss && e.bossMove != BossMove.recovery) {
      // Observe the tell, then punish the recovery instead of racing its HP.
    } else {
      if (s.hasShotgun &&
          !e.boss &&
          (e.x - s.x).abs() + (e.z - s.z).abs() < (completionist ? 10 : 6) &&
          (s.shotgunLoaded > 0 || s.bag.any((i) => i.kind == 'shells'))) {
        s.equip('shotgun');
      } else {
        s.equip('handgun');
      }
      if (s.loaded == 0 && s.reserve == 0) {
        s.equip(s.weapon == 'handgun' && s.hasShotgun ? 'shotgun' : 'handgun');
      }
      if (s.loaded == 0) {
        s.reload();
        if (s.reserve == 0) {
          throw StateError('Out of ammunition ${s.inspect()}');
        }
      }
      s.aiming = true;
      final before = s.shots;
      final origin = vm.Vector3(s.x, s.y + 1.25, s.z);
      s.shoot(origin, vm.Vector3(e.x, 1.1, e.z) - origin);
      if (s.shots > before) weaponsUsed.add(s.weapon);
    }
    frame();
    return true;
  }

  List<vm.Vector3> path(
    double tx,
    double tz,
    double ty,
    double radius,
    bool reach,
  ) {
    String key(vm.Vector3 p) =>
        '${(p.x * 2).round()},${(p.z * 2).round()},${(p.y * 10).round()}';
    final start = vm.Vector3((s.x * 2).round() / 2, s.y, (s.z * 2).round() / 2);
    final queue = <vm.Vector3>[start],
        parents = <String, String?>{key(start): null};
    final nodes = <String, vm.Vector3>{key(start): start};
    for (var i = 0; i < queue.length; i++) {
      final p = queue[i];
      if (math.pow(p.x - tx, 2) + math.pow(p.z - tz, 2) < radius * radius &&
          (p.y - ty).abs() < 1.25 &&
          (!reach || reachable(p.x, p.y, p.z, tx, tz))) {
        final result = <vm.Vector3>[];
        String? k = key(p);
        while (k != null) {
          result.add(nodes[k]!);
          k = parents[k];
        }
        return result.reversed.toList();
      }
      for (final d in [(0.5, 0.0), (-.5, 0.0), (0.0, .5), (0.0, -.5)]) {
        final nx = p.x + d.$1, nz = p.z + d.$2;
        final ny = s.floorHeight(nx, nz, p.y);
        if ((ny - p.y).abs() > .3 ||
            s.blocked(nx, nz, p.y) ||
            s.blocked(p.x + d.$1 / 2, p.z + d.$2 / 2, p.y)) {
          continue;
        }
        final n = vm.Vector3(nx, ny, nz), k = key(n);
        if (parents.containsKey(k)) continue;
        parents[k] = key(p);
        nodes[k] = n;
        queue.add(n);
      }
    }
    throw StateError('No path ${s.zoneId} ${s.x},${s.y},${s.z} → $tx,$ty,$tz');
  }

  bool reachable(double x, double y, double z, double tx, double tz) {
    final d = vm.Vector3(tx - x, 0, tz - z);
    return d.length < .001 ||
        s.wallDistance(vm.Vector3(x, y + .9, z), d.normalized(), d.length) >=
            d.length - .12;
  }

  void walk(
    double x,
    double z, {
    double y = 0,
    double radius = .7,
    bool reach = false,
  }) {
    final begin = frames;
    List<vm.Vector3>? route;
    var index = 0;
    while (math.pow(s.x - x, 2) + math.pow(s.z - z, 2) > radius * radius ||
        (s.y - y).abs() > 1.25 ||
        (reach && !reachable(s.x, s.y, s.z, x, z))) {
      if (s.phase == PlayPhase.transition || s.phase == PlayPhase.clear) return;
      if (combat()) {
        route = null;
        continue;
      }
      if (route == null || index >= route.length) {
        route = path(x, z, y, math.max(.1, radius - .15), reach);
        index = 0;
      }
      final next = route[index], delta = vm.Vector2(next.x - s.x, next.z - s.z);
      if (delta.length < .11) {
        index++;
        continue;
      }
      delta.normalize();
      input(delta.x, delta.y);
      frame();
      if (frames - begin > 60 * 180) {
        throw StateError('Stuck walking to $x,$z ${s.inspect()}');
      }
    }
    s.stopInput();
  }

  void pickup(String id) {
    final p = s.pickups.firstWhere((p) => p.id == id);
    walk(p.x, p.z, y: p.y, radius: 1.0, reach: true);
    for (var i = 0; i < 8 && !p.taken; i++) {
      s.interact();
      frame();
    }
    if (!p.taken) throw StateError('Cannot collect $id ${s.inspect()}');
    record('pickup:$id');
  }

  void collectImages() {
    for (final image in s.images) {
      walk(
        (image['x'] as num).toDouble(),
        (image['z'] as num).toDouble(),
        y: (image['y'] as num).toDouble(),
        radius: 1.1,
        reach: true,
      );
      for (var i = 0; i < 12 && !s.collected.contains(image['id']); i++) {
        s.interact();
        frame();
      }
      if (!s.collected.contains(image['id'])) {
        throw StateError('Cannot collect image ${image['id']} ${s.inspect()}');
      }
      record('image:${image['id']}');
    }
  }

  void collectBeer() {
    // Wait for the normal dissolve/drop timer; collect only actual defeated loot.
    for (var i = 0; i < 45; i++) {
      frame();
    }
    final beer = s.pickups.where((p) => p.kind == 'beer' && !p.taken).toList();
    for (final p in beer) {
      pickup(p.id);
    }
  }

  void merchant() {
    final npc = s.npcs.firstWhere((n) => n['id'] == 'takosan');
    walk(
      (npc['x'] as num).toDouble(),
      (npc['z'] as num).toDouble(),
      radius: 1.3,
      reach: true,
    );
    s.interact();
    if (s.phase != PlayPhase.dialogue) {
      throw StateError('Could not talk to Takosan');
    }
    while (!s.dialogueChoices) {
      s.advanceDialogue();
    }
    final before = s.beers;
    s.chooseDialogue('trade:ammo');
    if (s.beers != before - 2) throw StateError('Could not buy ammunition');
    s.endDialogue();
    record('trade:ammo');
  }

  void medals() {
    for (final target in s.targets) {
      final tx = (target['x'] as num).toDouble(),
          ty = (target['y'] as num).toDouble(),
          tz = (target['z'] as num).toDouble();
      final candidates = <vm.Vector2>[];
      for (var x = -21.0; x <= 21; x += 1) {
        for (var z = -23.0; z <= 28; z += 1) {
          final d = vm.Vector3(tx - x, ty - 1.25, tz - z),
              horizontal = math.sqrt(math.pow(tx - x, 2) + math.pow(tz - z, 2));
          final pitch = math.atan2(ty - 1.25, horizontal);
          if (d.length < 3 ||
              d.length > 16 ||
              pitch > .65 ||
              pitch < -.25 ||
              s.blocked(x, z, 0) ||
              s.wallDistance(vm.Vector3(x, 1.25, z), d.normalized(), d.length) <
                  d.length - .05) {
            continue;
          }
          // Stay clear of grazing rays: walking stops within a small tolerance.
          if (![(.2, 0.0), (-.2, 0.0), (0.0, .2), (0.0, -.2)].every((offset) {
            final origin = vm.Vector3(x + offset.$1, 1.25, z + offset.$2);
            final ray = vm.Vector3(tx, ty, tz) - origin;
            return s.wallDistance(origin, ray.normalized(), ray.length) >=
                ray.length - .05;
          })) {
            continue;
          }
          candidates.add(vm.Vector2(x, z));
        }
      }
      candidates.sort(
        (a, b) => (a - vm.Vector2(s.x, s.z)).length2.compareTo(
          (b - vm.Vector2(s.x, s.z)).length2,
        ),
      );
      vm.Vector2? point;
      for (final c in candidates) {
        try {
          path(c.x, c.y, 0, .25, false);
          point = c;
          break;
        } on StateError {
          continue;
        }
      }
      if (point == null) {
        throw StateError('No reachable medal viewpoint ${target['id']}');
      }
      walk(point.x, point.y, radius: .15);
      s.equip('handgun');
      for (var i = 0; i < 300 && !s.medallions.contains(target['id']); i++) {
        if (combat()) continue;
        if (s.loaded == 0) s.reload();
        s.aiming = true;
        final origin = vm.Vector3(s.x, s.y + 1.25, s.z);
        s.shoot(origin, vm.Vector3(tx, ty, tz) - origin);
        frame();
      }
      if (!s.medallions.contains(target['id'])) {
        throw StateError('Could not shoot medal ${target['id']}');
      }
      record('medal:${target['id']}');
    }
  }

  void gate() {
    walk(
      (s.gate['x'] as num).toDouble(),
      (s.gate['z'] as num).toDouble(),
      radius: 1.7,
    );
    s.interact();
    frame();
    if (!s.gateOpen) throw StateError('Gate did not open ${s.inspect()}');
    record('gate');
  }

  void exit() {
    final e = (s.map['exits'] as List).last;
    walk((e['x'] as num).toDouble(), (e['z'] as num).toDouble(), radius: .7);
    if (s.phase == PlayPhase.transition) {
      campaign.traverse();
      record('arrive');
    } else if (s.phase != PlayPhase.clear) {
      throw StateError('Exit failed');
    }
  }

  void run() {
    record('start');
    walk(-2.8, -22.5);
    s.interact();
    while (!s.dialogueChoices) {
      s.advanceDialogue();
    }
    s.chooseDialogue('supplies');
    s.endDialogue();
    record('guide');
    pickup('ammo_entry');
    pickup('shotgun');
    pickup('shells_up');
    pickup('ammo_square');
    pickup('key');
    if (completionist) {
      collectImages();
      collectBeer();
      merchant();
    }
    gate();
    exit();
    pickup('farm_herb');
    pickup('farm_barn_ammo');
    pickup('farm_barn_shells');
    if (completionist) {
      collectImages();
      medals();
      collectBeer();
      merchant();
    }
    gate();
    exit();
    pickup('mountain_ammo');
    pickup('mountain_green');
    walk(10, 4);
    while (s.bossAlive) {
      if (!combat()) {
        input(1, 0);
        frame();
      }
    }
    record('boss-defeated');
    if (completionist) {
      collectImages();
      collectBeer();
    }
    gate();
    exit();
    record('clear');
    if (completionist) {
      final expectedKills = campaign.maps.values.fold<int>(
        0,
        (n, m) => n + (m['enemies'] as List).length,
      );
      if (s.collected.length != campaign.catalog.length ||
          s.kills != expectedKills ||
          s.medallions.length != 7 ||
          s.tradePurchases['ammo'] != 2 ||
          !weaponsUsed.containsAll(['handgun', 'shotgun'])) {
        throw StateError('Completionist obligations not fulfilled');
      }
      for (final region in campaign.regions.values) {
        for (final enemy in region.enemies) {
          final drops = region.pickups
              .where((p) => p.id == 'beer_${enemy.id}')
              .toList();
          if (drops.length != 1 || !drops.single.taken) {
            throw StateError('Beer invariant ${region.zoneId}/${enemy.id}');
          }
        }
      }
      if (s.beers != expectedKills + 3 - 4) {
        throw StateError('Beer ledger does not balance');
      }
    }
  }
}

void main(List<String> args) {
  final maps = {
    for (final id in ['village', 'farm', 'mountain'])
      id: Map<String, dynamic>.from(
        jsonDecode(File('assets/$id.json').readAsStringSync()),
      ),
  };
  final audit = CampaignAudit(HazardCampaign(maps));
  audit.completionist = args.contains('--complete');
  var success = false;
  String? error;
  try {
    audit.run();
    success = audit.s.phase == PlayPhase.clear;
  } catch (e, st) {
    error = '$e\n$st';
    stderr.writeln(error);
  }
  final report = {
    'success': success,
    'error': error,
    'scope': 'Rules and collision simulation, not rendered UI or human full playthrough',
    'completionist': audit.completionist,
    'weaponsUsed': audit.weaponsUsed.toList(),
    'events': audit.events,
    'final': audit.s.inspect(),
  };
  File(args.firstOrNull ?? 'evidence/campaign-audit.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  if (!success) exitCode = 1;
}
