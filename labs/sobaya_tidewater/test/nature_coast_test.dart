import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:sobaya_tidewater/island_world.dart';
import 'package:sobaya_tidewater/nature_layout.dart';
import 'package:sobaya_tidewater/shore_field.dart';

void main() {
  test(
    'Shore distance follows triangle contour with correct land/sea signs',
    () {
      const size = 128;
      final h = ByteData(size * size * 4);
      for (var z = 0; z < size; z++) {
        for (var x = 0; x < size; x++) {
          h.setFloat32((z * size + x) * 4, (x - 64 + .5) * .1, Endian.little);
        }
      }
      final w = IslandWorld({
        'heightfield': {'resolution': size, 'origin': -64, 'texel': 1},
        'boxes': [],
        'cylinders': [],
      }, h);
      final shore = ShoreField(w, extent: 32);
      expect(shore.segments, greaterThan(0));
      for (final x in [-20.0, -5.0, 0.0, 3.0, 17.0]) {
        expect(shore.distance(x, 2.5), closeTo(x, .001));
      }
      expect(shore.distance(50, 0), 40);
    },
  );
  test('Seeded plants avoid buildings/decks; all tree trunks collide', () {
    final w = IslandWorld(
      jsonDecode(File('assets/world.json').readAsStringSync()),
      ByteData.sublistView(File('assets/heights.bin').readAsBytesSync()),
    );
    final a = NatureLayout(w), b = NatureLayout(w);
    expect(a.trees.length, inInclusiveRange(300, 520));
    expect(a.grass.length, greaterThan(1000));
    expect(
      a.trees.map((p) => (p.x, p.y, p.z, p.seed)),
      b.trees.map((p) => (p.x, p.y, p.z, p.seed)),
    );
    for (final p in a.trees) {
      expect(a.clear(p.x, p.z, 4), true);
      expect(p.y, greaterThan(2.8));
    }
    final original = w.cylinders.length;
    a.addColliders();
    expect(w.cylinders.length, original + a.trees.length);
    for (final t in a.trees.take(20)) {
      final feet = Vector3(t.x, t.y + .1, t.z);
      w.resolve(feet);
      expect(
        Vector2(feet.x - t.x, feet.z - t.z).length,
        greaterThanOrEqualTo(t.size * .04 + .27),
      );
    }
  });
}
