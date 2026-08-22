# Flutter Scene + VRM two-layer validation

## Result

The two-layer architecture is feasible. An official VRM 1.0 human model now
loads and renders through Flutter alone, and VRM expressions drive generic
glTF morph targets implemented in the local Flutter Scene fork.

```text
Flutter UI / future tracking and streaming features
  -> flutter_scene_vrm
       VRMC_vrm parsing, metadata, humanoid map, expression binding
    -> flutter_scene fork
         GLB/glTF, sparse accessors, generic morph targets, GPU rendering
```

The fork boundary is justified: stock `flutter_scene 0.22.2` parses/rendered
glTF but did not retain primitive morph `targets`, did not support sparse
accessors used by the avatar's face, and ignored animation `weights`.

## Tested asset

- `VRM1_Constraint_Twist_Sample.vrm`
- Source: official
  [`vrm-c/vrm-specification` samples](https://github.com/vrm-c/vrm-specification/tree/master/samples/VRM1_Constraint_Twist_Sample)
- Size: about 10 MiB
- Contents: human avatar, 57 face morph targets, 18 VRM expressions,
  humanoid bones, MToon declarations, SpringBone, roll/aim constraints, and
  bone-based look-at
- Embedded license metadata permits redistribution and modified
  redistribution and does not require credit. It identifies the VRM Public
  License 1.0. This remains a validation asset, not the planned production
  avatar.

The model is stored once under `04_GAME_ASSETS/vrm/`; the app refers to it by
relative symlink.

## Verified now

| Capability | Result |
|---|---|
| VRM 1.0 GLB load | Pass; 171 nodes, 3 meshes, 13 materials, 3 skins |
| Human model draw on macOS/Metal | Pass |
| Sparse glTF accessor decode | Pass |
| Generic morph target packing | Pass; all 57 face targets |
| VRM preset expression mapping | Pass |
| Emotion buttons | Pass |
| `aa` mouth slider | Pass |
| Automatic blink | Pass |
| Humanoid map discovery | Pass |
| MToon declaration detection | Pass; rendered with glTF/PBR fallback |
| SpringBone / Constraint detection | Pass; simulation not applied |

The macOS app was built and launched using Impeller/Metal. Runtime import
reported the expected counts and rendered the official avatar. The initial
expression and automatic blink both exercise the mutable morph buffer rather
than only testing parsing.

## Deliberate PoC limits

- Morph blending is CPU-side. The public controller API can remain while a
  production fork moves blending into the vertex shader for multiple avatars
  and continuous face tracking.
- Expression `overrideBlink` / `overrideMouth`, material color binds, and
  texture transform binds are not implemented yet.
- MToon is detected but not shaded as MToon.
- SpringBone, node constraints, look-at, humanoid retargeting, and VRMA are not
  executed yet.
- The official test model has no animation clips, so it displays in its
  authored T-pose. Tracking or a rest/idle pose layer is separate work.
- VRM 0.x compatibility is not included in this first vertical slice.
- Morph state currently belongs to shared Geometry; independently expressive
  clones need per-instance GPU weights in the production path.

## Reference implementations

- [`vrm-c/UniVRM`](https://github.com/vrm-c/UniVRM): authoritative Unity-side
  behavior reference for import, MToon, SpringBone, Constraint, LookAt, VRMA,
  and compatibility.
- [`pixiv/three-vrm`](https://github.com/pixiv/three-vrm): a closer reference
  for keeping VRM as an extension layer over a general glTF runtime.
- [`vrm-c/vrm-specification`](https://github.com/vrm-c/vrm-specification):
  normative schemas/specification and official conformance samples.

UniVRM makes implementation feasibility high, but engine-specific Unity code
cannot be transplanted directly. Port behavior and test cases; implement
rendering, buffers, transforms, and lifecycle against Flutter Scene.

## Fork publication state

The fork is published at
[`K9i-0/flutter_scene`](https://github.com/K9i-0/flutter_scene/tree/vrm-runtime-support)
on branch `vrm-runtime-support`. It is based exactly on upstream tag
`flutter_scene-0.22.2` / commit
`16d68a1b6bda46a0e7fbe91e3a51f403bec189fa`.

Both the VRM package and validation app pin fork commit
`8d340138f80d1fb5d09d163f62ab836be9379e2e`, avoiding accidental behavior
changes when the branch advances.

## Validation commands

```sh
git clone --branch vrm-runtime-support https://github.com/K9i-0/flutter_scene.git
cd flutter_scene && flutter test packages/flutter_scene/test/morph_target_import_test.dart
cd packages/flutter_scene_vrm && flutter test
cd 19_FLUTTER_SCENE_VRM_LAB && flutter test && flutter analyze
cd 19_FLUTTER_SCENE_VRM_LAB && flutter build macos --debug
```
