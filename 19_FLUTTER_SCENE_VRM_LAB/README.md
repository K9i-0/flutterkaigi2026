# Flutter Scene VRM two-layer lab

This app validates the proposed architecture with an official VRM 1.0 sample:

```text
Flutter UI
  -> flutter_scene_vrm (VRMC_vrm metadata + expression binding)
    -> K9i-0/flutter_scene fork (generic glTF morph targets + rendering)
```

Implemented in the validation:

- runtime `.vrm`/GLB loading
- VRM metadata and humanoid-bone discovery
- preset expression mapping
- reusable CPU morph buffer updates
- emotion controls, mouth `aa`, and automatic blink
- MToon/SpringBone/Constraint capability detection

Not yet implemented: MToon rendering, SpringBone simulation, node constraints,
look-at, webcam face tracking, microphone lip-sync, and GPU morph blending.

The app's model is a relative symlink to the canonical validation asset under
`04_GAME_ASSETS/vrm/`.

The Flutter Scene dependency is pinned to the tested commit on the public
[`vrm-runtime-support`](https://github.com/K9i-0/flutter_scene/tree/vrm-runtime-support)
fork branch.
