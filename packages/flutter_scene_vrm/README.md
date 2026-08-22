# flutter_scene_vrm

The VRM-specific half of the validation architecture:

1. The `K9i-0/flutter_scene` fork owns generic glTF morph targets and
   source-node IDs.
2. This package parses `VRMC_vrm`, maps preset/custom expressions to generic
   morph targets, and exposes `VrmAvatar.setExpression`.

Current validation scope is VRM 1.0 loading, metadata/humanoid discovery, and
CPU expression morphs. MToon, SpringBone, node constraints, look-at, camera
tracking, and audio lip-sync remain explicit next-stage work.
