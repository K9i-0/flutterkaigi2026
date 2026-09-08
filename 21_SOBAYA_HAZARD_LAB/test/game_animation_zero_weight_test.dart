import 'dart:typed_data';

import 'package:flutter_scene/scene.dart' show Node;
// This regression covers the game's pinned animation-engine patch.
// ignore: implementation_imports
import 'package:flutter_scene/src/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

class _CountingResolver implements PropertyResolver {
  _CountingResolver(this.delegate);
  final PropertyResolver delegate;
  int evaluations = 0;

  @override
  double getEndTime() => delegate.getEndTime();

  @override
  void apply(AnimationTransforms target, double timeInSeconds, double weight) {
    evaluations++;
    delegate.apply(target, timeInSeconds, weight);
  }
}

Animation _animation(
  String name,
  String target,
  PropertyResolver resolver, {
  AnimationProperty property = AnimationProperty.translation,
}) => Animation(
  name: name,
  channels: [
    AnimationChannel(
      bindTarget: BindKey(nodeName: target, property: property),
      resolver: resolver,
    ),
  ],
);

void main() {
  test('zero weight skips evaluation but advances and restores bind pose', () {
    final node = Node(
      name: 'joint',
      localTransform: Matrix4.translationValues(2, 0, 0),
    );
    final player = AnimationPlayer();
    final resolver = _CountingResolver(
      PropertyResolver.makeTranslationTimeline(
        [0, 2],
        [Vector3(4, 0, 0), Vector3(8, 0, 0)],
      ),
    );
    final clip = player.createAnimationClip(
      _animation('walk', node.name, resolver),
      node,
    )..seek(.5);
    player.update(0);
    expect(node.localTransform.getTranslation().x, closeTo(5, .00001));
    expect(resolver.evaluations, 1);

    clip
      ..weight = 0
      ..play();
    player.update(.25);
    expect(clip.playbackTime, .75);
    expect(node.localTransform.getTranslation().x, closeTo(2, .00001));
    expect(resolver.evaluations, 1);
    player.update(5);
    expect(clip.playbackTime, 2);
    expect(clip.playing, isFalse);
    expect(resolver.evaluations, 1);
  });

  test('paused nonzero clips still blend and normalize from the bind pose', () {
    final node = Node(
      name: 'joint',
      localTransform: Matrix4.translationValues(2, 0, 0),
    );
    final player = AnimationPlayer();
    AnimationClip hold(String name, double x) => player.createAnimationClip(
      _animation(
        name,
        node.name,
        PropertyResolver.makeTranslationTimeline(
          [0, 2],
          [Vector3(x, 0, 0), Vector3(x, 0, 0)],
        ),
      ),
      node,
    )..weight = .75;
    final first = hold('idle', 6);
    final second = hold('walk', 14);
    for (var frame = 0; frame < 3; frame++) {
      player.update(.1);
      expect(node.localTransform.getTranslation().x, closeTo(10, .00001));
    }
    expect(first.playbackTime, 0);
    expect(second.playbackTime, 0);
    second.weight = 0;
    player.update(.1);
    expect(node.localTransform.getTranslation().x, closeTo(5, .00001));
    first.weight = 0;
    player.update(.1);
    expect(node.localTransform.getTranslation().x, closeTo(2, .00001));
  });

  test('morph channels skip zero contributions and keep weighted blending', () {
    final node = Node(name: 'face');
    final resolver = _CountingResolver(
      PropertyResolver.makeMorphWeightsTimeline(
        [0, 2],
        Float32List.fromList([.8, .8]),
        targetCount: 1,
      ),
    );
    final clip = AnimationClip(
      _animation(
        'speech',
        node.name,
        resolver,
        property: AnimationProperty.weights,
      ),
      node,
    );
    final transforms =
        AnimationTransforms(
            bindPose: DecomposedTransform.fromMatrix(Matrix4.identity()),
          )
          ..bindMorphWeights = Float32List.fromList([.2])
          ..animatedMorphWeights = Float32List.fromList([.2]);
    final targets = {node: transforms};
    clip.weight = 0;
    clip.applyToBindings(targets, 1);
    expect(resolver.evaluations, 0);
    expect(transforms.animatedMorphWeights![0], closeTo(.2, .00001));
    clip.weight = .5;
    clip.applyToBindings(targets, 0);
    expect(resolver.evaluations, 0);
    clip.applyToBindings(targets, 1);
    expect(resolver.evaluations, 1);
    expect(transforms.animatedMorphWeights![0], closeTo(.5, .00001));
  });
}
