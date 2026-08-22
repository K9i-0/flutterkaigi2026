# flutter_scene_vrm

The VRM-specific half of the validation architecture:

1. The `K9i-0/flutter_scene` fork owns generic glTF morph targets and
   source-node IDs.
2. This package parses `VRMC_vrm`, maps preset/custom expressions to generic
   morph targets, and exposes `VrmAvatar.setExpression`.

Current validation scope is VRM 1.0 loading, metadata/humanoid discovery, CPU
expression morphs, and engine-independent `VrmFaceTrackingFrame`,
`VrmUpperBodyTrackingFrame`, and `VrmArmTrackingFrame` inputs handled by
`VrmFaceTrackingDriver`. The driver maps normalized head pose across the VRM
`spine` / `chest` / `upperChest` / `neck` / `head` rest rotations, maps
shoulder and elbow angles to the arm hierarchy, and maps eye/mouth values to
VRM expressions. Natural, anime-style counter-roll, and legacy head-only
profiles are available. Detector confidence blends cropped upper-body and arm
observations with safe face-derived or A-pose fallbacks. Torso and arm motion
use independent smoothing rates. Camera or detector packages deliberately stay
in the app layer.

MToon, SpringBone, node constraints, look-at, expression override semantics,
GPU/per-instance morph weights, and audio lip-sync remain next-stage work.
