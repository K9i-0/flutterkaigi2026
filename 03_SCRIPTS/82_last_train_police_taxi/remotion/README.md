# Episode 82 siren edit

Run `npm ci`, `npm run typecheck`, then `npm run render` here. Output: `../final_remotion_siren.mp4`.

`src/edit-manifest.json` is the frame/volume timing authority. Audio is rendered with Remotion; FFmpeg copies the source video stream without re-encoding.

`public/input.mp4` is an untracked hardlink to the original episode video. `public/police_siren_wan71.wav` is the selected source-derived effect and is tracked. Provenance is in `siren-source.json`. To recreate it, run `scripts/build_siren.py` with Python + numpy and FFmpeg; the original episode 71 video must be present. No paid generation or synthetic sound is used.

`qa.json` records measured checks, not a listening approval. Render intermediates stay in `out/` and are untracked.

Exterior punchline revision: `npm run render:ending` outputs `../final_remotion_exterior_punchline.mp4`. Timing authority: `src/ending-edit.json`. `public/siren-approved.mp4` is an untracked hardlink to the approved siren version. Final audio is muxed directly from this source to avoid browser AAC decode offset.
