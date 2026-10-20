import 'dart:typed_data';

import 'package:flutter_scene/gpu.dart' as gpu;
import 'package:flutter_scene/scene.dart';

/// Reuses the uploaded pose only when every GPU matrix is exactly unchanged.
/// Animation sampling and mesh detail remain unchanged.
final class CachedSkin extends Skin {
  CachedSkin(Skin source) {
    joints.addAll(source.joints);
    inverseBindMatrices.addAll(source.inverseBindMatrices);
  }

  final pose = SkinPoseRevision();
  gpu.Texture? _texture;

  @override
  gpu.Texture getJointsTexture() {
    final changed = pose.update(this);
    if (changed || _texture == null) _texture = super.getJointsTexture();
    return _texture!;
  }
}

/// Compares the float32 values actually uploaded, including ancestor transforms
/// and inverse bindings. No threshold, frame skipping or pose approximation.
class SkinPoseRevision {
  Float32List? _previous;
  Float32List _current = Float32List(0);

  bool update(Skin skin) {
    final count = skin.joints.length * 16;
    if (_current.length != count) _current = Float32List(count);
    for (var i = 0; i < skin.joints.length; i++) {
      final joint = skin.joints[i];
      if (joint == null) {
        for (var j = 0; j < 16; j++) {
          _current[i * 16 + j] = j % 5 == 0 ? 1 : 0;
        }
      } else {
        final matrix = joint.globalTransform * skin.inverseBindMatrices[i];
        _current.setRange(i * 16, i * 16 + 16, matrix.storage);
      }
    }
    final previous = _previous;
    var changed = previous == null || previous.length != count;
    if (!changed) {
      for (var i = 0; i < count; i++) {
        if (previous[i] != _current[i]) {
          changed = true;
          break;
        }
      }
    }
    if (changed) {
      _previous = _current;
      _current = previous?.length == count ? previous! : Float32List(count);
    }
    return changed;
  }
}

void cacheSkinUploads(Node root) {
  final replacements = <Skin, CachedSkin>{};
  void visit(Node node) {
    final skin = node.skin;
    if (skin != null && skin is! CachedSkin) {
      node.skin = replacements.putIfAbsent(skin, () => CachedSkin(skin));
    }
    for (final child in node.children) {
      visit(child);
    }
  }

  visit(root);
}
