# WAI Wan 3.0 generation log

- Generated: 2026-08-26
- Model: `wan3.0-video`
- Qwen Cloud task ID: `93ffb31e-6856-4022-b5cc-5e880fb3a904`
- Generation mode: one continuous 30-second task
- Audio source: Wan 3.0 synchronized audio (`audio=true`)
- Resolution: `480P` (832x480 result)
- Aspect ratio: `16:9`
- Frame rate: 30 fps
- Seed: `523030`
- Prompt extension: disabled
- Watermark: disabled
- Input: eight all-in-one reference images
- Price checked immediately before submission: USD 0.035/second
- Estimated generation charge: USD 1.05
- Result: succeeded

## Outputs

- Wan master with native synchronized audio: `generated/wai_window_side_ai_30s_wan_master.mp4`
- Final with post-added Japanese subtitles: `generated/wai_window_side_ai_30s_final.mp4`

The final edit does not replace or locally synthesize narration, sound effects, ambience, or music. It only burns in Japanese subtitles, trims to exactly 30.000 seconds, and applies loudness normalization to the Wan-generated audio.

## V2: prompt-led code and terminal scenes

- Generated: 2026-08-27
- Model: `wan3.0-video`
- Qwen Cloud task ID: `a4ecd753-0d98-41c1-adcb-c73e457bd904`
- Generation mode: one continuous 30-second task
- Audio source: Wan 3.0 synchronized audio (`audio=true`)
- Resolution: `480P` (832x480 result)
- Aspect ratio: `16:9`
- Frame rate: 30 fps
- Seed: `523031`
- Prompt extension: disabled
- Watermark: disabled
- Inputs: WAI logo reference and the complete `窓際族` scene reference only
- VS Code, iTerm2, error escalation, and project-deletion visuals: generated from prompt without scene reference images
- Price checked immediately before submission: USD 0.035/second
- Estimated generation charge: USD 1.05
- Result: succeeded

### V2 outputs

- Wan master with native synchronized audio: `generated/wai_window_side_ai_30s_v2_wan_master.mp4`
- Final with post-added Japanese subtitles: `generated/wai_window_side_ai_30s_v2_final.mp4`

The V2 final preserves Wan-generated narration, sound effects, ambience, and music. Post-production only burns in Japanese subtitles, trims to exactly 30.000 seconds, normalizes loudness, and encodes the audio at 48 kHz AAC stereo. Visual QA confirmed the intended order: WAI logo, VS Code errors, iTerm2 error panes, debt deletion with `0 ERRORS / 0 FILES / 0 DEBT`, the two-person `窓際族` scene with one beer mug, and the closing WAI logo.
