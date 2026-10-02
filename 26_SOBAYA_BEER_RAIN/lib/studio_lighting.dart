import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// A linear HDR lighting rig, not an LDR background picture. Narrow stripboxes
/// form readable white reflections on both walls of the thick glass.
Future<EnvironmentMap> beerStudioEnvironment() async {
  const w = 512, h = 256;
  final pixels = Float32List(w * h * 4);
  double smooth(double a, double b, double v) {
    final t = ((v - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  double card(vm.Vector3 d, vm.Vector3 center, double width, double height) {
    final n = center.normalized(),
        right = vm.Vector3(0, 1, 0).cross(n).normalized(),
        up = n.cross(right);
    final forward = d.dot(n);
    if (forward <= 0) return 0;
    final x = (d.dot(right) / forward).abs(), y = (d.dot(up) / forward).abs();
    return (1 - smooth(width * .92, width, x)) *
        (1 - smooth(height * .96, height, y));
  }

  for (var y = 0; y < h; y++) {
    final theta = math.pi * (y + .5) / h;
    for (var x = 0; x < w; x++) {
      final phi = math.pi * 2 * (x + .5) / w;
      final d = vm.Vector3(
        math.sin(theta) * math.cos(phi),
        math.cos(theta),
        math.sin(theta) * math.sin(phi),
      );
      final key = card(d, vm.Vector3(-1, .3, 1), .075, .9) * 4;
      final edge = card(d, vm.Vector3(1, .15, .45), .035, 1.1) * 5;
      final back = card(d, vm.Vector3(.4, .5, -1), .35, .55) * 2.5;
      final ceiling = math.pow(math.max(0, d.y), 8) * .32;
      final i = (y * w + x) * 4;
      pixels[i] = .065 + ceiling + key + edge * .82 + back;
      pixels[i + 1] = .065 + ceiling + key * .97 + edge * .91 + back * .70;
      pixels[i + 2] = .07 + ceiling + key * .91 + edge + back * .38;
      pixels[i + 3] = 1;
    }
  }
  return EnvironmentMap.fromEquirectHdr(
    linearPixels: pixels,
    width: w,
    height: h,
  );
}
