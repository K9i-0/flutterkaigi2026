import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// A facade-mounted LED ad. The canonical photograph is drawn unchanged;
/// only the ticker UVs move, with no per-frame image decoding or GPU uploads.
class OkayamanVision {
  final nodes = <Node>[];
  final ticker = UnlitMaterial()..doubleSided = true;
  double seconds = 0;
  bool visible = false;

  Map<String, Object> inspect() => {
    'visible': visible,
    'source': '02_CHARACTERS/Okayaman.jpg',
    'seconds': seconds,
    'tickerOffset': ticker.baseColorTextureTransform.offset.x,
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

  static void _text(
    ui.Canvas canvas,
    String text,
    double x,
    double y,
    double size,
    ui.Color color, {
    double width = 1000,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w800,
          fontFamily: 'Hiragino Sans',
          height: 1.12,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    painter.paint(canvas, ui.Offset(x, y));
    painter.dispose();
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
    canvas.drawColor(const ui.Color(0xfff3efdf), ui.BlendMode.src);
    // Fit the full original photo into the right half, preserving face and ratio.
    const photoHeight = 512.0;
    final photoWidth = photoHeight * photo.width / photo.height;
    canvas.drawImageRect(
      photo,
      ui.Rect.fromLTWH(0, 0, photo.width.toDouble(), photo.height.toDouble()),
      ui.Rect.fromLTWH(1024 - photoWidth, 0, photoWidth, photoHeight),
      ui.Paint(),
    );
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 440, 512),
      ui.Paint()..color = const ui.Color(0xff072c38),
    );
    const gold = ui.Color(0xffffce69), white = ui.Color(0xfffff6e6);
    _text(canvas, 'MADOGIWA VISION', 30, 26, 27, gold);
    _text(canvas, '大変\n驚いて\nおります。', 28, 98, 73, white, width: 400);
    _text(canvas, '窓際王  おかやまん', 30, 410, 34, gold);
    _text(canvas, 'その一杯に、驚きを。', 30, 465, 23, white);
    final ad = await _texture(recorder, 1024, 512);
    photo.dispose();
    codec.dispose();

    final tapeRecorder = ui.PictureRecorder();
    final tapeCanvas = ui.Canvas(tapeRecorder);
    tapeCanvas.drawColor(const ui.Color(0xfff7c55d), ui.BlendMode.src);
    _text(
      tapeCanvas,
      'おかやまん  /  大変驚いております。  /  MADOGIWA VISION  /',
      12,
      17,
      32,
      const ui.Color(0xff092c35),
      width: 1280,
    );
    ticker.baseColorTexture = await _texture(tapeRecorder, 1280, 80);
    final face = UnlitMaterial(colorTexture: ad)..doubleSided = true;
    final frame = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(.025, .035, .045, 1)
      ..metallicFactor = .5;
    final facade = PhysicallyBasedMaterial()
      ..baseColorTexture = await Texture2D.fromAsset(
        'assets/images/vision_facade.png',
      );
    final roof = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(.14, .18, .21, 1);
    // The screen is physically attached to one building, never camera-facing.
    _box(scene, vm.Vector3(4.4, -4.6, -14), vm.Vector3(8.8, 18.8, 4.4), facade);
    _box(scene, vm.Vector3(4.4, 4.9, -14), vm.Vector3(9, .2, 4.6), roof);
    _box(scene, vm.Vector3(4.4, 1.7, -11.65), vm.Vector3(8.5, 4.9, .35), frame);
    _panel(scene, 8.1, 4.05, vm.Vector3(4.4, 2, -11.46), face);
    _panel(scene, 8.1, .51, vm.Vector3(4.4, -.33, -11.46), ticker);
  }

  void update(double dt, {required bool enabled}) {
    visible = enabled;
    for (final node in nodes) {
      node.visible = enabled;
    }
    if (!enabled) return;
    seconds += dt;
    ticker.baseColorTextureTransform.offset.x = (seconds * .035) % 1;
  }
}
