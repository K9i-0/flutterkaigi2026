# Flutter Scene + VRM two-layer validation

## Result

The two-layer architecture is feasible. An official VRM 1.0 human model loads
and renders through Flutter alone. Camera-independent face values now drive the
avatar's head, neck, eyes, and mouth through the same reusable VRM layer.

```text
Flutter UI / camera / future streaming features
  -> flutter_scene_vrm
       VRMC_vrm parsing, metadata, humanoid map, expression + tracking driver
    -> flutter_scene fork
         GLB/glTF, sparse accessors, generic morph targets, GPU rendering
```

The tracking vertical slice is:

```text
camera image (iOS BGRA / Android NV21)
  -> on-device ML Kit face detector
  -> camera-independent FaceTrackingSignal
  -> calibration + exponential smoothing + clamping
  -> VrmFaceTrackingDriver
  -> neck/head humanoid rotations + blinkLeft/blinkRight + aa
```

The fork boundary remains justified: stock `flutter_scene 0.22.2` did not
retain primitive morph `targets`, support sparse accessors used by this face,
or apply morph weights.

## Tested asset

- `VRM1_Constraint_Twist_Sample.vrm`
- Source: official
  [`vrm-c/vrm-specification` sample](https://github.com/vrm-c/vrm-specification/tree/master/samples/VRM1_Constraint_Twist_Sample)
- About 10 MiB
- 57 face morph targets, 18 VRM expressions, humanoid bones, MToon,
  SpringBone, roll/aim constraints, and bone-based look-at declarations
- Embedded metadata permits redistribution and modified redistribution under
  the VRM Public License 1.0. It remains a validation asset rather than the
  production avatar.

The model is stored once under `04_GAME_ASSETS/vrm/`; the app uses a relative
symlink.

## Verified now

| Capability | Result |
|---|---|
| VRM 1.0 GLB load | Pass; 171 nodes, 3 meshes, 13 materials, 3 skins |
| Human model draw on macOS/Metal | Pass |
| Sparse glTF accessor decode | Pass |
| Generic morph target packing | Pass; all 57 face targets |
| VRM preset expression mapping | Pass |
| Emotion, `aa` mouth, automatic blink | Pass |
| Humanoid map discovery | Pass |
| Head / neck humanoid drive | Pass; 25% neck + 75% head rotation |
| Blink and mouth tracking drive | Pass |
| Camera-independent tracking pipeline | Pass; unit tested |
| macOS continuous tracking simulation | Pass; same VRM driver as camera path |
| Android camera integration build | Pass; debug APK |
| iOS camera integration build | Pass; simulator debug app |
| Marionette MCP custom extensions | Pass; discovered and called live |
| Deterministic MCP face injection | Pass; pose, one-eye blink, mouth visually verified |
| MToon declaration detection | Pass; glTF/PBR fallback rendering only |
| SpringBone / Constraint detection | Pass; simulation not applied |

The live MCP check injected yaw `28°`, pitch `-10°`, roll `7°`, left eye open
`0.15`, right eye open `0.8`, and mouth open `0.7`. The normalized mirror-space
result (`-28°`, `-10°`, `-7°`, blink `0.85/0.20`, mouth `0.70`) was returned by
`madogiwa.inspectVrm` and visible in both the avatar and tracking panel.

## Camera implementation boundary

- `camera 0.12.0+2` supplies the front-camera image stream.
- `google_mlkit_face_detection 0.15.1` supplies Euler angles, eye-open
  probabilities, and lip contours on iOS/Android.
- Head yaw and roll are mirrored for front-camera UX. Mouth opening is derived
  from the normalized upper/lower lip contour gap.
- A busy-frame gate prevents overlapping detector calls. Detector FPS and
  dropped frames are exposed in the UI and MCP.
- When a face is lost, pose and facial values return smoothly to neutral.
- Lifecycle pausing/resuming applies only to actual camera tracking. MCP and
  simulation modes do not accidentally open the camera.
- The app neither uploads nor persists camera frames.

The Flutter ML Kit package is a community wrapper around native Google ML Kit,
not a Google-maintained Flutter plugin. Its iOS minimum is 15.5 and it currently
requires CocoaPods because it has no SwiftPM manifest. The app therefore opts
out of SwiftPM locally until that dependency catches up.

## Automation verified

The monorepo's Dart MCP and Marionette MCP configuration is shared with this
lab. Debug native builds register:

- `madogiwa.inspectVrm`
- `madogiwa.setFaceTracking`
- `madogiwa.injectFace`
- `madogiwa.calibrateFace`
- `madogiwa.setVrmExpression`
- `madogiwa.resetVrm`

macOS simulation demonstrates continuous motion through the production input
contract. `injectFace` bypasses smoothing for exact repeatable assertions and
screenshots.

## Remaining work before production

1. **Physical-device camera acceptance:** sustained tests on representative
   iPhones and Android devices. Integration builds do not prove real camera
   orientation, permission recovery, thermal behavior, or detector quality.
2. **Richer facial capture:** ML Kit provides head Euler angles and coarse
   eye/smile data, not ARKit-class blendshapes or phoneme visemes. ARKit or
   MediaPipe should plug in behind `FaceTrackingSignal`.
3. **Eye gaze and expression semantics:** VRM LookAt, eye bones, expression
   override rules, material color binds, and UV transform binds.
4. **Avatar physics and shading:** MToon, SpringBone, and node constraints are
   parsed/detected only.
5. **Render scaling:** continuous morph blending needs per-instance GPU weights
   and multi-avatar benchmarks.
6. **Tracking robustness:** persisted calibration, lost-face/reacquisition
   tuning, device rotation, backgrounding, and interruption tests.
7. **VTuber product features:** audio capture/lip-sync, full-body and hand
   tracking, recording/streaming, virtual backgrounds, chat overlays, and
   privacy UX are outside this validation.
8. **Format coverage:** VRM 0.x, VRMA animation, model permission presentation,
   and production-avatar QA.

## Reference implementations

- [`vrm-c/UniVRM`](https://github.com/vrm-c/UniVRM): authoritative Unity-side
  behavior reference.
- [`pixiv/three-vrm`](https://github.com/pixiv/three-vrm): a closer example of
  keeping VRM as an extension layer over a general glTF runtime.
- [`vrm-c/vrm-specification`](https://github.com/vrm-c/vrm-specification):
  normative schemas and official conformance samples.

UniVRM makes feasibility high, but engine-specific Unity code cannot be copied
directly. Port behavior and tests while implementing transforms, rendering,
buffers, and lifecycle against Flutter Scene.

## Fork publication state

The fork is published at
[`K9i-0/flutter_scene`](https://github.com/K9i-0/flutter_scene/tree/vrm-runtime-support)
on `vrm-runtime-support`, based on upstream tag `flutter_scene-0.22.2` / commit
`16d68a1b6bda46a0e7fbe91e3a51f403bec189fa`.

Both the package and app pin commit
`8d340138f80d1fb5d09d163f62ab836be9379e2e`.

## Validation commands

```sh
cd packages/flutter_scene_vrm && flutter analyze && flutter test
cd 19_FLUTTER_SCENE_VRM_LAB && flutter analyze && flutter test
cd 19_FLUTTER_SCENE_VRM_LAB && flutter build macos --debug
cd 19_FLUTTER_SCENE_VRM_LAB && flutter build apk --debug
cd 19_FLUTTER_SCENE_VRM_LAB && flutter build ios --simulator --debug
```
