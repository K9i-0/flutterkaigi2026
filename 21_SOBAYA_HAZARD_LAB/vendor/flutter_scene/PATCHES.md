# Flutter Scene 0.23.0 — Sobaya Hazard patch

Source: pub.dev flutter_scene 0.23.0 (MIT; LICENSE and third-party notices retained). Runtime, build-hook and shader sources vendored so fresh checkouts reproduce this fix without modifying the global pub cache. Samples, screenshots, upstream tests and generated build outputs are omitted. pubspec workspace membership/screenshots are removed for standalone use.

`lib/src/scene_encoder.dart`: the unskinned fast path skipped `MorphedUnskinnedGeometry.bind`, leaving MorphInfo/morph_texture unbound in the color pass. Limit this fast path to geometry without morph targets; morphed geometry uses its full bind method, like the shadow/depth passes. Keeps per-node liquid slopes and shared source geometry. Models, materials and skinning are unchanged by this patch.

Reproduction: render several cloned mugs with different TiltX/TiltZ weights alongside a skinned character with SpeechOpen. Liquid must stay inside each mug during movement, closeups and shadow/opaque/transparent passes. See the game's beer-lighting QA record for native checks.

Upstream encoder SHA256 before patch: 37cad6db456259fc49d816ec7f4a34698c9713022e930eb92f82091461323680

Published archive checksum from the original pubspec.lock: `1cc32b5ed0d05296c1f7958e63168a750c05c2373d6769ad9b9eaa973b2f97fe`. To adopt a future upstream fix, replace the path dependency with a tested release and remove this vendor directory only after the mug/speech GPU regression has been checked.

Formatting only: removed an upstream extra blank line at EOF in `shaders/flutter_scene_velocity_unskinned.vert` for the repository whitespace check; shader code is unchanged.

## Zero-weight animation evaluation (2026-09-08)

`lib/src/animation/animation_clip.dart`: `applyToBindings` returns before channel evaluation when the clip weight or normalization multiplier is exactly zero. Sobaya Hazard registers every character motion, then keeps inactive clips paused at zero weight; upstream still ran their timeline lookup and interpolation. `AnimationPlayer.update` continues advancing every clip and resetting the bind pose. Paused clips with nonzero weights still contribute, including morph channels.

The existing macOS profile process produced 22,394 main-isolate samples over a 118.494-second extent before this change. `AnimationPlayer.update` appeared in 21.47% and `AnimationClip.applyToBindings` in 20.83% of samples, inclusive; these nested shares are not additive or a measured speedup. The profile also contained Metal submission waits. Capture details are retained locally in `evidence/three-aspects-cpu-analysis.md`; a matching native profile is required to measure the result.

Regression: `flutter test --no-pub test/game_animation_zero_weight_test.dart` passes all three tests: zero-weight channels are not evaluated while time/end-state and bind-pose reset work, paused weighted clips normalize/blend correctly, and morph channels retain weighted blending. Targeted Dart analysis passes.

Upstream animation clip SHA256 before patch: `b65ed806dd1b388c1da4f82c2ea6e23dc44d3b172d1394ed825c0aa916af6881`.
Patched animation clip SHA256: `a82d6d0beee68ac9e047e403dd9e8b6f2d1e410392c7732390d678a7e6a6b3f5`.

## Skinned TAA velocity world transforms (2026-09-08)

`lib/src/render/velocity_pass.dart`: the joints textures already hold full world transforms, including the character's root scale. The velocity pass additionally multiplied both current and previous mesh world matrices, unlike the color pass's identity matrices. Use identity model matrices for skinned velocity and match each draw's winding to the color/depth passes. This prevents the 3x boss's velocity coverage from being translated/scaled a second time. `test/game_giant_velocity_test.dart` checks current/previous head positions and displacement with a translated, rotated, 3x rig. Native boss event frames render without runtime errors after hot reload.

This is a confirmed defect in the newly enabled TAA path, not proof that it caused the user's older intermittent face corruption. The reported older symptom has not yet been reproduced.

## Optional SceneView frame pacing (2026-09-12)

`lib/src/widgets/scene_view.dart` accepts `maxFramesPerSecond` on both constructors. The default is null and preserves the existing display-driven behavior. The optional `frame_pacer.dart` gate selects a bounded cadence from vsync timestamps, delivering the full time since the last accepted tick. It gates the animation callback and 3D repaint together. Active parent, asset and semantics repaint requests join that cadence; static or muted views still repaint immediately when changed. Layout and loading may cause additional paints. This limits automatic scene work, not the operating system's display refresh rate or unrelated Flutter UI.

The gate retains phase at non-divisor display rates such as 90 Hz, tolerates small clock jitter, keeps near-harmonic 59.94/119.88 Hz cadences stable, and drops catch-up debt after delayed frames. Changing the limit retains elapsed animation time and does not recreate the ticker. Scene update and rendering stay together so the previous skin/model transforms and TAA camera history refer to the same rendered frame. TAA convergence still takes more wall-clock time at 30 fps because its weights are per rendered frame.

The optional `onFrameRendered` callback runs once after the painter's `Scene.render` or `Scene.renderViews` call returns successfully, excluding unready scenes, empty sizes and empty view lists. It observes render calls, not GPU completion or presented FPS. Observers must not mutate the scene, rebuild widgets or request a repaint from this paint-time callback. Use a `RepaintBoundary` around the view to isolate it from unrelated parent paints; Sobaya Hazard already does this.

Regression: `test/scene_frame_pacer_test.dart` covers 30/60 targets at 119.88/120/90/60/59.94 Hz, full elapsed time, unspecified limits, cadence alternation, jitter, delays, setting changes and clock resets. These deterministic tests do not establish physical-device power or temperature improvements. No iOS refresh-rate configuration or native display-link implementation changes are included.
