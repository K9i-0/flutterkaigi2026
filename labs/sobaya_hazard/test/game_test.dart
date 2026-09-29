import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madogiwa_engine/madogiwa_engine.dart';
import 'package:sobaya_hazard/game.dart';

void main() {
  HazardGame game() =>
      HazardGame(jsonDecode(File('assets/yard.json').readAsStringSync()));
  test('solid cover blocks sight and bullets, not just movement', () {
    final g = game();
    g.player = const Point2(4, 9);
    g.yaw = math.pi;
    g.guards[0].position = const Point2(4, 1);
    expect(g.world.visible(g.player, g.guards[0].position), false);
    g.fire();
    expect(g.guards[0].health, 100);
    expect(g.ammo, 5);
    final stopped = g.world.move(g.player, const Point2(0, -10));
    expect(stopped.z, greaterThan(6.7));
  });
  test('shot hits nearest living target and cooldown prevents double fire', () {
    final g = game();
    g.player = const Point2(10, 10);
    g.yaw = math.pi;
    g.guards[0].position = const Point2(10, 6);
    g.guards[1].position = const Point2(10, 2);
    g.fire();
    g.fire();
    expect(g.ammo, 5);
    expect(g.guards[0].health, 50);
    expect(g.guards[1].health, 100);
    expect(g.guards[1].awareness.mode, AwarenessMode.investigate);
  });
  test('reload is timed and extraction requires control cabinet', () {
    final g = game();
    g.ammo = 0;
    g.reload();
    g.tick(.1);
    expect(g.ammo, 0);
    for (var i = 0; i < 80; i++) {
      g.tick(1 / 60);
    }
    expect(g.ammo, 6);
    expect(g.reserve, 12);
    g.player = g.exit;
    g.tick(1 / 60);
    expect(g.won, false);
    g.player = g.terminal;
    g.interact();
    g.player = g.exit;
    g.tick(1 / 60);
    expect(g.won, true);
  });
  test('last-seen memory does not follow hidden player', () {
    final a = Awareness();
    const seen = Point2(2, 3), hidden = Point2(9, 9);
    a.update(.7, seesTarget: true, target: seen);
    expect(a.mode, AwarenessMode.chase);
    a.update(2, seesTarget: false, target: hidden);
    expect(a.mode, AwarenessMode.investigate);
    expect(a.lastKnown, seen);
    a.update(5, seesTarget: false, target: hidden);
    expect(a.mode, AwarenessMode.patrol);
    expect(a.lastKnown, isNull);
  });
  test('diagonal contact slides along wall without tunnelling', () {
    final world = CollisionWorld([const SolidBox(0, 0, 1, 20)]);
    final p = world.move(const Point2(-2, -2), const Point2(6, 5));
    expect(p.x, lessThan(-.7));
    expect(p.z, closeTo(3, 1e-8));
  });
}
