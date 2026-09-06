# Flutter Scene 0.23.0 — Sobaya Hazard patch

Source: pub.dev flutter_scene 0.23.0 (MIT; LICENSE and third-party notices retained). Runtime, build-hook and shader sources vendored so fresh checkouts reproduce this fix without modifying the global pub cache. Samples, screenshots, upstream tests and generated build outputs are omitted. pubspec workspace membership/screenshots are removed for standalone use.

`lib/src/scene_encoder.dart`: the unskinned fast path skipped `MorphedUnskinnedGeometry.bind`, leaving MorphInfo/morph_texture unbound in the color pass. Limit this fast path to geometry without morph targets; morphed geometry uses its full bind method, like the shadow/depth passes. Keeps per-node liquid slopes and shared source geometry. Models, materials and skinning are unchanged by this patch.

Reproduction: render several cloned mugs with different TiltX/TiltZ weights alongside a skinned character with SpeechOpen. Liquid must stay inside each mug during movement, closeups and shadow/opaque/transparent passes. See the game's beer-lighting QA record for native checks.

Upstream encoder SHA256 before patch: 37cad6db456259fc49d816ec7f4a34698c9713022e930eb92f82091461323680

Published archive checksum from the original pubspec.lock: `1cc32b5ed0d05296c1f7958e63168a750c05c2373d6769ad9b9eaa973b2f97fe`. To adopt a future upstream fix, replace the path dependency with a tested release and remove this vendor directory only after the mug/speech GPU regression has been checked.

Formatting only: removed an upstream extra blank line at EOF in `shaders/flutter_scene_velocity_unskinned.vert` for the repository whitespace check; shader code is unchanged.
