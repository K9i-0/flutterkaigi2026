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
