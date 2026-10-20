import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import 'package:yumemi_recruit_exam/cached_skin.dart';

void main() {
  test(
    'unchanged poses reuse uploads; bone, ancestor and binding changes do not',
    () {
      final parent = Node();
      final joint = Node();
      parent.add(joint);
      final skin = Skin()
        ..joints.add(joint)
        ..inverseBindMatrices.add(Matrix4.identity());
      final cache = SkinPoseRevision();
      expect(cache.update(skin), isTrue);
      expect(cache.update(skin), isFalse);
      joint.position = Vector3(1, 0, 0);
      expect(cache.update(skin), isTrue);
      expect(cache.update(skin), isFalse);
      parent.position = Vector3(0, 2, 0);
      expect(cache.update(skin), isTrue);
      skin.inverseBindMatrices[0].setTranslation(Vector3(0, 0, 3));
      expect(cache.update(skin), isTrue);
      expect(cache.update(skin), isFalse);
      skin.joints[0] = null;
      expect(cache.update(skin), isTrue);
      expect(cache.update(skin), isFalse);
      skin.joints.clear();
      skin.inverseBindMatrices.clear();
      expect(cache.update(skin), isTrue);
      expect(cache.update(skin), isFalse);
    },
  );
}
