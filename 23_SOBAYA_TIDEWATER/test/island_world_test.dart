import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_tidewater/island_world.dart';
import 'package:vector_math/vector_math.dart';

IslandWorld fixture({
  List<Object?> boxes = const [],
  List<Object?> cylinders = const [],
}) {
  final bytes = ByteData(16);
  for (var i = 0; i < 4; i++) {
    bytes.setFloat32(i * 4, i.toDouble(), Endian.little);
  }
  return IslandWorld({
    'heightfield': {'resolution': 2, 'origin': 0, 'texel': 1},
    'boxes': boxes,
    'cylinders': cylinders,
  }, bytes);
}

Map<String, Object> box({bool walkable = false, double angle = 0}) => {
  'center': {'x': 0, 'y': 1, 'z': 0},
  'half': {'x': 1, 'y': 1, 'z': 1},
  'top': 2,
  'bottom': 0,
  'solid': true,
  'walkable': walkable,
  'cos': math.cos(angle),
  'sin': math.sin(angle),
};
void main() {
  test('heightfield follows upstream half-texel bilinear convention', () {
    final w = fixture();
    expect(w.heightAt(.5, .5), 0);
    expect(w.heightAt(1, 1), 1.5);
    expect(w.heightAt(-1, 0), -90);
  });
  test('wall resolves centre penetration and a rotated face without NaN', () {
    for (final angle in [0.0, math.pi / 4]) {
      final w = fixture(boxes: [box(angle: angle)]), p = Vector3(0, 0, 0);
      w.resolve(p);
      expect(p.length, closeTo(1.28, 1e-5));
      expect(p.x.isFinite && p.z.isFinite, true);
    }
  });
  test('walkable deck is selected only within step budget', () {
    final w = fixture(boxes: [box(walkable: true)]);
    expect(w.groundAt(0, 0, 2.1), 2);
    expect(w.groundAt(0, 0, 1), -90);
  });
  test('cylinder centre is pushed out deterministically', () {
    final w = fixture(
          cylinders: [
            {'x': 0, 'z': 0, 'radius': 1, 'yMin': 0, 'yMax': 3},
          ],
        ),
        p = Vector3.zero();
    w.resolve(p);
    expect(p.x, closeTo(1.28, 1e-5));
    expect(p.z, 0);
  });
  test('adopted export has valid GLB, pinned source and a walkable spawn', () {
    final m = jsonDecode(
      File('assets/world.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final bytes = File('assets/heights.bin').readAsBytesSync();
    final w = IslandWorld(m, ByteData.sublistView(bytes));
    expect(m['revision'], '4811ba48d795197de5621985f404e765c0b7c0ef');
    expect((m['buildings'] as List).length, 21);
    expect(w.groundAt(53.6, -77, 100), inInclusiveRange(1, 5));
    final glb = File('assets/island.glb').readAsBytesSync(),
        h = ByteData.sublistView(glb);
    expect(h.getUint32(0, Endian.little), 0x46546c67);
    expect(h.getUint32(8, Endian.little), glb.length);
    final doc = jsonDecode(
      utf8.decode(glb.sublist(20, 20 + h.getUint32(12, Endian.little))),
    ) as Map<String, dynamic>;
    expect((doc['meshes'] as List).length, m['meshes']);
    for (final a in doc['accessors'] as List) {
      expect(a['count'] as int, greaterThan(0));
    }
  });
}
