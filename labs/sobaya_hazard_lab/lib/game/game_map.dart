import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'game_state.dart';

const _paper = Color(0xffddd4b9),
    _brass = Color(0xffd9bc79),
    _ground = Color(0xff252d29),
    _wall = Color(0xffa4a58c);

/// North is +Z. A shared metre scale avoids stretching buildings or sight cones
/// in square minimaps; the northern gate's arrival point also stays in frame.
class HazardMapProjection {
  HazardMapProjection(Size size, {bool detailed = false}) {
    final inset = detailed ? 21.0 : 5.0;
    scale = math.max(
      0,
      math.min((size.width - inset * 2) / 48, (size.height - inset * 2) / 56),
    );
    origin = Offset(size.width / 2, size.height / 2 + scale);
  }
  late final double scale;
  late final Offset origin;
  Offset at(double x, double z) => origin + Offset(x, -z) * scale;
  Rect rect(double x, double z, double width, double depth) => Rect.fromCenter(
    center: at(x, z),
    width: width * scale,
    height: depth * scale,
  );
}

/// Static cartography is recorded once per map/viewport. Only known contacts,
/// objectives and the player are painted each frame, without image textures.
class VillageMapPainter extends CustomPainter {
  VillageMapPainter(this.state, {this.detailed = false});
  final HazardGameState state;
  final bool detailed;

  // Bounded across chapter changes and rotation; dispose GPU-side recordings
  // when evicting instead of retaining every historical viewport size.
  static final _backgrounds = <_MapBackground>[];
  static final _sight = Expando<_MapSightCache>();

  ui.Picture _background(Size size, HazardMapProjection map) {
    final index = _backgrounds.indexWhere(
      (entry) =>
          identical(entry.world, state.map) &&
          entry.size == size &&
          entry.detailed == detailed,
    );
    if (index >= 0) {
      final hit = _backgrounds.removeAt(index);
      _backgrounds.add(hit);
      return hit.picture;
    }
    final recorder = ui.PictureRecorder();
    _paintBackground(Canvas(recorder), size, map);
    final picture = recorder.endRecording();
    _backgrounds.add(_MapBackground(state.map, size, detailed, picture));
    if (_backgrounds.length > 6) _backgrounds.removeAt(0).picture.dispose();
    return picture;
  }

  void _paintBackground(Canvas c, Size size, HazardMapProjection map) {
    final bounds = Offset.zero & size;
    // Full-map type reaches 10px at 300px and 12px at the 440px desktop size.
    // Minimap typography and markers retain their independent compact sizes.
    final detailType = (10 + (size.shortestSide - 300) / 70).clamp(8.0, 12.0);
    c.drawRect(bounds, Paint()..color = const Color(0xff151d1b));
    final field = map.rect(0, 1, 48, 56);
    c.drawRect(field, Paint()..color = _ground);
    final grid = Paint()
      ..color = const Color(0xff354039)
      ..strokeWidth = .5;
    for (var x = -20.0; x <= 20; x += 10) {
      c.drawLine(map.at(x, -27), map.at(x, 29), grid);
    }
    for (var z = -20.0; z <= 20; z += 10) {
      c.drawLine(map.at(-24, z), map.at(24, z), grid);
    }

    // Floors remain distinct from the collision walls. Door openings are not
    // obscured by a solid outline around each building footprint.
    for (final h in state.map['houses'] as List) {
      final rect = map.rect(_n(h['x']), _n(h['z']), _n(h['w']), _n(h['d']));
      c.drawRect(
        rect.shift(Offset(map.scale * .45, map.scale * .65)),
        Paint()..color = const Color(0xff121b19),
      );
      c.drawRect(rect, Paint()..color = const Color(0xff515b4e));
      if (detailed) {
        c.save();
        c.clipRect(rect.deflate(.8));
        final board = Paint()
          ..color = const Color(0xff606a59)
          ..strokeWidth = .5;
        for (var y = rect.top + 4; y < rect.bottom; y += 4) {
          c.drawLine(Offset(rect.left, y), Offset(rect.right, y), board);
        }
        c.restore();
      }
    }
    for (final o in state.obstacles) {
      if (o.bottom > 1.5 || o.id == 'gate') continue;
      final rect = map.rect(o.x, o.z, o.w, o.d);
      final cliff = o.w > 4 && o.d > 4 && o.top > 4;
      c.drawRect(
        rect,
        Paint()
          ..color = cliff
              ? const Color(0xff414a43)
              : o.top < 2
              ? const Color(0xff74816b)
              : _wall,
      );
      if (cliff) {
        c.save();
        c.clipRect(rect);
        final hatch = Paint()
          ..color = const Color(0xff586157)
          ..strokeWidth = .7;
        for (
          var x = rect.left - rect.height;
          x < rect.right;
          x += detailed ? 7 : 5
        ) {
          c.drawLine(
            Offset(x, rect.bottom),
            Offset(x + rect.height, rect.top),
            hatch,
          );
        }
        c.restore();
        c.drawRect(
          rect,
          Paint()
            ..color = const Color(0xff7c8270)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .8,
        );
      }
    }
    if (detailed) {
      for (final ramp in state.map['ramps'] as List? ?? const []) {
        final x = _n(ramp['x']), z0 = _n(ramp['z0']), z1 = _n(ramp['z1']);
        final paint = Paint()
          ..color = _paper.withValues(alpha: .45)
          ..strokeWidth = .7;
        for (var z = z0; z < z1; z += .55) {
          c.drawLine(
            map.at(x - _n(ramp['w']) / 2, z),
            map.at(x + _n(ramp['w']) / 2, z),
            paint,
          );
        }
      }
      final memoBounds = [
        for (final memo in state.localMemos)
          Rect.fromCenter(center: map.at(memo.x, memo.z), width: 8, height: 10),
      ];
      for (final h in state.map['houses'] as List) {
        final (name, compact) = switch (h['id']) {
          'Shotgun' => ('二階家', '民家'),
          'Barn' => ('納屋', '納屋'),
          'West' => ('西の家', '西家'),
          'East' => ('東の家', '東家'),
          'Entrance' => ('入口\n小屋', '入口'),
          'SaveHut' => ('小屋', '小屋'),
          'Tools' => ('道具庫', '道具'),
          'NorthShed' => ('北の小屋', '小屋'),
          'Ruins' => ('集合場所', '集合場所'),
          _ => ('', ''),
        };
        final center = map.at(_n(h['x']), _n(h['z']));
        final interior = map
            .rect(_n(h['x']), _n(h['z']), _n(h['w']), _n(h['d']))
            .deflate(math.max(1.0, map.scale * .22));
        final labelBounds = _label(
          c,
          name,
          center,
          detailType,
          _paper,
          centered: true,
          within: interior,
          fallback: compact,
          avoid: memoBounds,
        );
        if (h['two'] == true && !labelBounds.isEmpty) {
          final floorSize = detailType * .75;
          _label(
            c,
            '2F',
            labelBounds.bottomCenter + Offset(0, 2 + floorSize / 2),
            floorSize,
            _brass,
            centered: true,
            within: interior,
            avoid: [...memoBounds, labelBounds.inflate(1)],
          );
        }
      }
    }

    // A restrained survey frame makes the map readable at 80px as well as in
    // the full map. Detailed-only typography never crowds the touch minimap.
    c.drawRect(
      bounds.deflate(.5),
      Paint()
        ..color = const Color(0xff6f7a67)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (detailed) {
      c.drawRect(
        bounds.deflate(4),
        Paint()
          ..color = const Color(0xff3b4940)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .5,
      );
      final title = switch (state.zoneId) {
        'farm' => '02 / 農場',
        'mountain' => '03 / 山道',
        _ => '01 / ゆめみ村',
      };
      _label(c, title, const Offset(11, 9), detailType * .9, _brass);
      final start = Offset(12, size.height - 13);
      final end = start + Offset(10 * map.scale, 0);
      final pen = Paint()
        ..color = _paper
        ..strokeWidth = 1;
      c.drawLine(start, end, pen);
      for (final point in [start, end]) {
        c.drawLine(
          point + const Offset(0, -3),
          point + const Offset(0, 2),
          pen,
        );
      }
      _label(c, '10 m', end + const Offset(5, -4), detailType * .8, _paper);
    }
    final north = Offset(size.width - (detailed ? 16 : 8), detailed ? 13 : 10);
    _label(
      c,
      'N',
      north,
      detailed ? detailType * .9 : 6,
      _paper,
      centered: true,
    );
    final arrow = Path()
      ..moveTo(north.dx, north.dy + 6)
      ..lineTo(north.dx - 2, north.dy + 11)
      ..lineTo(north.dx + 2, north.dy + 11)
      ..close();
    c.drawPath(arrow, Paint()..color = _brass);
  }

  @override
  void paint(Canvas c, Size size) {
    if (size.isEmpty) return;
    final map = HazardMapProjection(size, detailed: detailed);
    final sight = _sight[state] ??= _MapSightCache();
    sight.refresh(state);
    c.save();
    c.clipRect(Offset.zero & size);
    c.drawPicture(_background(size, map));

    // Dynamic gate and the final house's lock use the same collision contract
    // as gameplay, including the replacement of the obsolete mountain gate.
    for (final o in state.collisionObstacles) {
      if (o.bottom > 1.5 || sight.isStaticObstacle(o) && o.id != 'gate') {
        continue;
      }
      if (o.id == 'gate' && state.gateOpen) continue;
      c.drawRect(map.rect(o.x, o.z, o.w, o.d), Paint()..color = _brass);
    }
    final gatePoint = map.at(_n(state.gate['x']), _n(state.gate['z']));
    _ring(c, gatePoint, detailed ? 5 : 3, _brass);
    if (detailed) {
      for (final exit in state.map['exits'] as List? ?? const []) {
        _ring(c, map.at(_n(exit['x']), _n(exit['z'])), 4, _brass);
      }
      for (final npc in state.npcs) {
        final point = map.at(_n(npc['x']), _n(npc['z']));
        final diamond = Path()
          ..moveTo(point.dx, point.dy - 4)
          ..lineTo(point.dx + 3.5, point.dy)
          ..lineTo(point.dx, point.dy + 4)
          ..lineTo(point.dx - 3.5, point.dy)
          ..close();
        c.drawPath(diamond, Paint()..color = const Color(0xff9cd0cc));
        c.drawPath(
          diamond,
          Paint()
            ..color = const Color(0xff172824)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
    for (final memo in state.localMemos) {
      if (state.foundMemos.contains(memo.id)) continue;
      final rect = Rect.fromCenter(
        center: map.at(memo.x, memo.z),
        width: detailed ? 5 : 2.5,
        height: detailed ? 7 : 3.5,
      );
      c.drawRect(rect.inflate(.7), Paint()..color = const Color(0xff18231e));
      c.drawRect(rect, Paint()..color = _brass);
      if (detailed) {
        c.drawLine(
          rect.topLeft + const Offset(1, 3),
          rect.topRight + const Offset(-1, 3),
          Paint()
            ..color = _ground
            ..strokeWidth = .8,
        );
      }
    }

    for (final enemy in state.enemies) {
      if (!enemy.alive || !enemy.discovered) continue;
      final visible = enemy.visibleToPlayer;
      final ex = visible ? enemy.x : enemy.lastSeenByPlayerX;
      final ez = visible ? enemy.z : enemy.lastSeenByPlayerZ;
      if (ex == null || ez == null) continue;
      final color = switch (enemy.awareness) {
        EnemyAwareness.chasing => const Color(0xffff7665),
        EnemyAwareness.searching => const Color(0xffffbd70),
        EnemyAwareness.returning => const Color(0xffadbd9b),
        _ => const Color(0xffe5c66a),
      };
      final point = map.at(ex, ez);
      if (visible) {
        final vertices = sight.cone(state, enemy);
        if (vertices.isNotEmpty) {
          final first = map.at(vertices.first.dx, vertices.first.dy);
          final path = Path()..moveTo(first.dx, first.dy);
          for (final vertex in vertices.skip(1)) {
            final p = map.at(vertex.dx, vertex.dy);
            path.lineTo(p.dx, p.dy);
          }
          path.close();
          c.drawPath(path, Paint()..color = color.withValues(alpha: .15));
          c.drawPath(
            path,
            Paint()
              ..color = color.withValues(alpha: .3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .6,
          );
        }
      }
      final radius = detailed ? 3.5 : 2.3;
      c.drawCircle(point, radius + 1, Paint()..color = _ground);
      c.drawCircle(
        point,
        radius,
        Paint()
          ..color = color.withValues(alpha: visible ? 1 : .6)
          ..style = visible ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      if (!visible && detailed) {
        c.drawLine(
          point + const Offset(-1, 0),
          point + const Offset(1, 0),
          Paint()
            ..color = color.withValues(alpha: .6)
            ..strokeWidth = .8,
        );
      }
    }
    for (final splash in state.beerSplashes.where((s) => s.age < .8)) {
      c.drawCircle(
        map.at(splash.position.x, splash.position.z),
        8 * map.scale,
        Paint()
          ..color = const Color(0xffffbd70)
              .withValues(alpha: .4 * (1 - splash.age / .8))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    if (state.playerNoiseTime > 0) {
      c.drawCircle(
        map.at(state.x, state.z),
        state.playerNoiseRadius * map.scale,
        Paint()
          ..color = const Color(0x77f0d497)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    final landing = state.beerPreview?.landing;
    if (state.running &&
        state.aiming &&
        state.weapon == 'beer' &&
        state.beers > 0 &&
        landing != null) {
      final target = map.at(landing.x, landing.z);
      final radius = hazardBeerLureRadius * map.scale;
      c.drawCircle(target, radius, Paint()..color = const Color(0x22ffdd22));
      c.drawCircle(
        target,
        radius,
        Paint()
          ..color = const Color(0xddffdd22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      c.drawCircle(target, 3.5, Paint()..color = const Color(0xffff4433));
    }
    final player = map.at(state.x, state.z);
    final radius = detailed ? 5.0 : 3.5;
    c.drawCircle(player, radius + 2, Paint()..color = const Color(0xff131e1c));
    c.save();
    c.translate(player.dx, player.dy);
    c.rotate(state.heading);
    final chevron = Path()
      ..moveTo(0, -radius - 2)
      ..lineTo(radius, radius)
      ..lineTo(0, radius * .45)
      ..lineTo(-radius, radius)
      ..close();
    c.drawPath(chevron, Paint()..color = const Color(0xfffff7db));
    c.restore();
    c.restore();
  }

  @override
  bool shouldRepaint(covariant VillageMapPainter oldDelegate) => true;
}

double _n(dynamic value) => (value as num).toDouble();

void _ring(Canvas c, Offset point, double radius, Color color) {
  c.drawCircle(point, radius + 1, Paint()..color = const Color(0xff18231e));
  c.drawCircle(
    point,
    radius,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4,
  );
  c.drawCircle(point, 1, Paint()..color = color);
}

Rect _label(
  Canvas c,
  String text,
  Offset point,
  double size,
  Color color, {
  bool centered = false,
  Rect? within,
  String? fallback,
  List<Rect> avoid = const [],
}) {
  if (text.isEmpty || within != null && within.isEmpty) return Rect.zero;
  TextPainter layOut(String value, {double? fontSize}) => TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        color: color,
        fontSize: fontSize ?? size,
        fontWeight: FontWeight.w600,
        height: 1,
        shadows: const [Shadow(color: Color(0xff17221d), offset: Offset(0, 1))],
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: centered ? TextAlign.center : TextAlign.left,
    maxLines: within == null ? null : 2,
  )..layout(maxWidth: within?.width ?? double.infinity);
  // Names belong inside the real building footprint. Wrapping and compact
  // names preserve readable type without hiding a wall or an adjacent route.
  // Note locations are fixed, so reserving their icon area also remains cached
  // and avoids labels jumping when the player collects a note.
  Rect? placement(TextPainter painter) {
    if (painter.didExceedMaxLines ||
        within != null &&
            (painter.width > within.width || painter.height > within.height)) {
      return null;
    }
    final start = centered
        ? point - Offset(painter.width / 2, painter.height / 2)
        : point;
    final offsets = [
      Offset.zero,
      if (within != null && avoid.isNotEmpty) ...[
        Offset(0, size + 2),
        Offset(0, -size - 2),
        Offset(size + 2, 0),
        Offset(-size - 2, 0),
      ],
    ];
    for (final delta in offsets) {
      var offset = start + delta;
      if (within != null) {
        offset = Offset(
          offset.dx.clamp(within.left, within.right - painter.width),
          offset.dy.clamp(within.top, within.bottom - painter.height),
        );
      }
      final bounds = offset & painter.size;
      if (avoid.every((reserved) => !reserved.overlaps(bounds))) return bounds;
    }
    return null;
  }

  var painter = layOut(text);
  var textBounds = placement(painter);
  if (textBounds == null && fallback != null) {
    painter.dispose();
    painter = layOut(fallback);
    textBounds = placement(painter);
  }
  if (textBounds == null && fallback != null && size > 10) {
    painter.dispose();
    painter = layOut(fallback, fontSize: 10);
    textBounds = placement(painter);
  }
  if (textBounds == null) {
    painter.dispose();
    return Rect.zero;
  }
  c.save();
  if (within != null) c.clipRect(within);
  painter.paint(c, textBounds.topLeft);
  c.restore();
  painter.dispose();
  return textBounds;
}

class _MapBackground {
  const _MapBackground(this.world, this.size, this.detailed, this.picture);
  final Object world;
  final Size size;
  final bool detailed;
  final ui.Picture picture;
}

class _MapSightCache {
  // UI cones update at 10Hz while enemy/player markers retain every frame.
  // Perception, discovery and the actual AI still run at their original rate.
  final _cones = <Enemy, List<Offset>>{};
  double _time = -1;
  int? _cover;
  List<Obstacle>? _obstacles;
  Set<Obstacle> _staticObstacles = {};
  bool isStaticObstacle(Obstacle obstacle) =>
      _staticObstacles.contains(obstacle);
  void refresh(HazardGameState state) {
    if (!identical(_obstacles, state.obstacles)) {
      _obstacles = state.obstacles;
      _staticObstacles = state.obstacles.toSet();
      _cones.clear();
    }
    final cover = Object.hash(
      state.gateOpen,
      state.refugeUnlocked,
      Object.hashAll(state.crates.map((c) => c.broken)),
      state.sneaking,
    );
    if (state.time < _time || state.time - _time >= .1 || _cover != cover) {
      _time = state.time;
      _cover = cover;
      _cones.clear();
    }
    _cones.removeWhere(
      (e, _) => !e.alive || !e.discovered || !e.visibleToPlayer,
    );
  }

  List<Offset> cone(HazardGameState state, Enemy enemy) => _cones.putIfAbsent(
    enemy,
    () => state
        .enemySightPolygon(enemy)
        .map((v) => Offset(v.x, v.y))
        .toList(growable: false),
  );
}
