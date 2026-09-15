# Sobaya v2 — approved oval mask revision

2026-09-15: User approved the repaired oval mask rim/chin and facial proportions matched to original v2. `sobaya_v2.blend` preserves the approved editable model; `sobaya_v2.glb` is its geometry export. Original 2026-09-13 assets remain unchanged.

Game adoption uses `hazard_adopted/v2_20260915_mask/sobaya.glb`. All 103 existing adopted animation tracks are retained, with the Head joint explicitly preferred over the identically named mesh. PropSocket.R and all original rest bones are retained.

Rebuild from repository root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/export_sobaya_mask_revision.py
python3 tools/adopt_sobaya_mask_revision.py
node tools/validate_hazard_v2_models.mjs
```

The two export/adoption steps must run in order. Exporting alone does not install animation tracks. Source export may contain no animations; the immutable previous adopted GLB is the animation source.

Validation: glTF errors 0; 103 clips; 200090 triangles; height 1.799866 m; normalized weights; five phases of every clip sampled for finite skin positions and mug socket tracking. Flutter motion tests: 5 passed; Flutter analyze: no issues. macOS `lib/game_main.dart` fully rebuilt and launched, repaired mask visually checked in the shopAlley static review fixture. Continuous gameplay/performance was not benchmarked in this adoption pass.
