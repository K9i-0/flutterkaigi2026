import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_map.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';

HazardGameState world(String id) =>
    HazardGameState(jsonDecode(File('assets/$id.json').readAsStringSync()));

Future<Uint8List> raster(HazardGameState state, {int side = 300}) async {
  final recorder = ui.PictureRecorder();
  VillageMapPainter(
    state,
    detailed: true,
  ).paint(ui.Canvas(recorder), ui.Size.square(side.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(side, side);
  final data = await image.toByteData();
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

List<ui.Offset> changedPixels(Uint8List a, Uint8List b, int side) {
  final changed = <ui.Offset>[];
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2]) {
      changed.add(
        ui.Offset((i ~/ 4 % side).toDouble(), (i ~/ 4 ~/ side).toDouble()),
      );
    }
  }
  return changed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'north, metre scale and every chapter exit fit small and large maps',
    () {
      for (final side in [80.0, 96.0, 140.0, 300.0, 440.0]) {
        final projection = HazardMapProjection(
          ui.Size.square(side),
          detailed: side >= 300,
        );
        final center = projection.at(0, 0);
        expect(projection.at(0, 10).dy, lessThan(center.dy));
        expect(projection.at(10, 0).dx, greaterThan(center.dx));
        expect(
          (projection.at(10, 0) - center).distance,
          closeTo((projection.at(0, 10) - center).distance, 1e-8),
        );
        for (final id in ['village', 'farm', 'mountain']) {
          for (final exit in world(id).map['exits'] as List) {
            final point = projection.at(
              (exit['x'] as num).toDouble(),
              (exit['z'] as num).toDouble(),
            );
            expect(
              (ui.Offset.zero & ui.Size.square(side))
                  .deflate(4)
                  .contains(point),
              isTrue,
              reason: '$id / $side / $exit',
            );
          }
        }
      }
    },
  );

  test(
    'undiscovered contacts stay hidden and lost contacts stay at last sighting',
    () async {
      final state = world('village')..enemies.clear();
      final baseline = await raster(state);
      final enemy = Enemy(100, 17, -17)..active = true;
      state.enemies.add(enemy);
      expect(changedPixels(baseline, await raster(state), 300), isEmpty);
      enemy
        ..discovered = true
        ..lastSeenByPlayerX = -18
        ..lastSeenByPlayerZ = -18;
      final remembered = await raster(state);
      final changes = changedPixels(baseline, remembered, 300);
      final projection = HazardMapProjection(
        const ui.Size.square(300),
        detailed: true,
      );
      final knownPosition = projection.at(-18, -18);
      expect(changes, isNotEmpty);
      expect(changes.every((p) => (p - knownPosition).distance <= 6), isTrue);
      enemy
        ..x = 16
        ..z = 16;
      expect(changedPixels(remembered, await raster(state), 300), isEmpty);
      enemy.alive = false;
      expect(changedPixels(baseline, await raster(state), 300), isEmpty);
    },
  );

  test('gate opening updates a cached background and player heading points north/east', () async {
    final state = world('village')..enemies.clear();
    final closed = await raster(state);
    state.gateOpen = true;
    expect(changedPixels(closed, await raster(state), 300), isNotEmpty);
    state
      ..x = 0
      ..z = -15
      ..heading = 0;
    final north = await raster(state);
    state.heading = math.pi / 2;
    final east = await raster(state);
    final projection = HazardMapProjection(
      const ui.Size.square(300),
      detailed: true,
    );
    final center = projection.at(0, -15);
    int brightness(Uint8List pixels, ui.Offset p) {
      var peak = 0;
      // The projection can land between device pixels. A 3px sample checks
      // the arrow direction without depending on anti-alias coverage.
      for (var y = p.dy.round() - 1; y <= p.dy.round() + 1; y++) {
        for (var x = p.dx.round() - 1; x <= p.dx.round() + 1; x++) {
          final index = (y * 300 + x) * 4;
          peak = math.max(
            peak,
            pixels[index] + pixels[index + 1] + pixels[index + 2],
          );
        }
      }
      return peak;
    }

    expect(
      brightness(north, center + const ui.Offset(0, -5)),
      greaterThan(650),
    );
    expect(brightness(east, center + const ui.Offset(5, 0)), greaterThan(650));
    expect(
      brightness(north, center + const ui.Offset(0, -5)) -
          brightness(east, center + const ui.Offset(0, -5)),
      greaterThan(300),
    );
  });

  test(
    'cartography visual evidence covers all chapters and minimap sizes',
    () async {
      for (final detailSide in [300.0, 440.0]) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawColor(const ui.Color(0xff101713), ui.BlendMode.src);
        for (var column = 0; column < 3; column++) {
          final id = ['village', 'farm', 'mountain'][column];
          final state = world(id);
          final enemy = state.enemies.first;
          enemy
            ..discovered = true
            ..visibleToPlayer = true;
          final lost = state.enemies.last;
          lost
            ..discovered = true
            ..visibleToPlayer = false
            ..lastSeenByPlayerX = lost.x
            ..lastSeenByPlayerZ = lost.z;
          canvas.save();
          canvas.translate(12 + column * (detailSide + 24), 12);
          VillageMapPainter(
            state,
            detailed: true,
          ).paint(canvas, ui.Size.square(detailSide));
          canvas.restore();
          var x = 12 + column * (detailSide + 24);
          for (final side in [140.0, 96.0, 80.0]) {
            canvas.save();
            canvas.translate(x, detailSide + 24);
            VillageMapPainter(state).paint(canvas, ui.Size.square(side));
            canvas.restore();
            x += side + 2;
          }
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(
          (3 * (detailSide + 24) + 12).ceil(),
          (detailSide + 176).ceil(),
        );
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('evidence').createSync(recursive: true);
        File(
          detailSide == 300
              ? 'evidence/cartography-20260912.png'
              : 'evidence/cartography-wide-20260912.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      }
    },
  );
}
