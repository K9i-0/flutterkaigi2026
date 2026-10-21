import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// A small screen mounted on the existing bridge-support building.
class OkayamanVision {
  final nodes = <Node>[];
  bool visible = false;

  Map<String, Object> inspect() => {
    'visible': visible,
    'source': 'characters/Okayaman.jpg',
  };

  void _box(
    Scene scene,
    vm.Vector3 position,
    vm.Vector3 size,
    Material material,
  ) {
    final node = Node(mesh: Mesh(CuboidGeometry(size), material))
      ..position = position;
    scene.add(node);
    nodes.add(node);
  }

  void _panel(
    Scene scene,
    double width,
    double height,
    vm.Vector3 position,
    Material material,
  ) {
    final geometry = MeshGeometry.fromArrays(
      positions: Float32List.fromList([
        -width / 2,
        -height / 2,
        0,
        width / 2,
        -height / 2,
        0,
        width / 2,
        height / 2,
        0,
        -width / 2,
        height / 2,
        0,
      ]),
      normals: Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]),
      texCoords: Float32List.fromList([1, 1, 0, 1, 0, 0, 1, 0]),
      indices: [0, 1, 2, 0, 2, 3],
    );
    final node = Node(mesh: Mesh(geometry, material))..position = position;
    scene.add(node);
    nodes.add(node);
  }

  static Future<Texture2D> _texture(
    ui.PictureRecorder recorder,
    int w,
    int h,
  ) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final texture = await Texture2D.fromImage(image);
    image.dispose();
    picture.dispose();
    return texture;
  }

  Future<void> load(Scene scene) async {
    final bytes = await rootBundle.load('assets/images/okayaman.jpg');
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final photo = (await codec.getNextFrame()).image;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
    // Keep the canonical face unchanged and centered, with a simple subtitle.
    const height = 768.0;
    final width = height * photo.width / photo.height;
    canvas.drawImageRect(
      photo,
      ui.Rect.fromLTWH(0, 0, photo.width.toDouble(), photo.height.toDouble()),
      ui.Rect.fromLTWH((1024 - width) / 2, 0, width, height),
      ui.Paint(),
    );
    final subtitle = TextPainter(
      text: const TextSpan(
        text: '大変驚いております。',
        style: TextStyle(
          color: ui.Color(0xffffffff),
          fontSize: 76,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(color: ui.Color(0xff000000), blurRadius: 5),
            Shadow(color: ui.Color(0xff000000), offset: ui.Offset(2, 2)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 1000);
    subtitle.paint(canvas, ui.Offset((1024 - subtitle.width) / 2, 662));
    subtitle.dispose();
    final ad = await _texture(recorder, 1024, 768);
    photo.dispose();
    codec.dispose();

    final face = UnlitMaterial(colorTexture: ad)..doubleSided = true;
    final frame = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(.025, .035, .045, 1)
      ..metallicFactor = .5;
    // Existing support: x=6, y=-7, z=0, size=2.7 x 14 x 4.
    // Flush against the street-facing wall, clear of rooftop equipment.
    _box(scene, vm.Vector3(6, -1.5, 2.04), vm.Vector3(2.5, 1.9, .08), frame);
    _panel(scene, 2.4, 1.8, vm.Vector3(6, -1.5, 2.09), face);
  }

  void update(double dt, {required bool enabled}) {
    visible = enabled;
    for (final node in nodes) {
      node.visible = enabled;
    }
  }
}
