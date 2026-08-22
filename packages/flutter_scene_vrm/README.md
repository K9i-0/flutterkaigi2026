# flutter_scene_vrm

The VRM-specific half of the validation architecture:

1. The `K9i-0/flutter_scene` fork owns generic glTF morph targets and
   source-node IDs.
2. This package parses `VRMC_vrm`, maps preset/custom expressions to generic
   morph targets, and exposes `VrmAvatar.setExpression`.

Current validation scope is VRM 1.0 loading, metadata/humanoid discovery, CPU
expression morphs, and an engine-independent `VrmFaceTrackingFrame` /
`VrmFaceTrackingDriver`. The driver maps normalized head pose to the VRM neck
and head rest rotations and maps eye/mouth values to VRM expressions. Camera or
detector packages deliberately stay in the app layer.

MToon, SpringBone, node constraints, look-at, expression override semantics,
GPU/per-instance morph weights, and audio lip-sync remain next-stage work.
