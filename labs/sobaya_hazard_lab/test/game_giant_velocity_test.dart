import 'dart:typed_data';

// ignore: implementation_imports
import 'package:flutter_scene/src/render/velocity_pass.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('giant head velocity uses the same world position as color skinning', () {
    final info = createSkinnedVelocityModelInfo();
    final currentModel = Matrix4.fromFloat32List(
      Float32List.sublistView(info, 0, 16),
    );
    final previousModel = Matrix4.fromFloat32List(
      Float32List.sublistView(info, 16, 32),
    );
    final head = Vector3(.1, 1.6, .2);
    final previousJoint = Matrix4.compose(
      Vector3(12, 0, 4),
      Quaternion.axisAngle(Vector3(0, 1, 0), .3),
      Vector3.all(3),
    );
    final currentJoint = Matrix4.compose(
      Vector3(11, 0, 4),
      Quaternion.axisAngle(Vector3(0, 1, 0), .5),
      Vector3.all(3),
    );
    final colorNow = currentJoint.transformed3(head);
    final colorBefore = previousJoint.transformed3(head);
    final velocityNow = currentModel.transformed3(colorNow);
    final velocityBefore = previousModel.transformed3(colorBefore);
    expect(velocityNow.distanceTo(colorNow), lessThan(1e-6));
    expect(velocityBefore.distanceTo(colorBefore), lessThan(1e-6));
    expect(
      (velocityNow - velocityBefore).distanceTo(colorNow - colorBefore),
      lessThan(1e-6),
    );
    // The old path applied the giant root again: even its head height tripled.
    expect(
      currentJoint.transformed3(colorNow).distanceTo(colorNow),
      greaterThan(5),
    );
  });
}
