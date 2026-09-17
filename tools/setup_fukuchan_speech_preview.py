"""Expose a local face close-up with canonical game voice and speech envelope."""
from pathlib import Path
import os,json
ROOT=Path(__file__).resolve().parents[1];folder=ROOT/'16_MADOGIWA_STUDIO/public/.local/fukuchan-speech';folder.mkdir(parents=True,exist_ok=True)
assets=ROOT/'21_SOBAYA_HAZARD_LAB/assets'
voice=next(c for c in json.loads((assets/'audio/voice-manifest.json').read_text())['clips'] if c['speaker']=='福ちゃん')
envelopes=json.loads((assets/'audio/speech-envelopes.json').read_text())
envelope=next(c for c in envelopes['clips'] if c['asset'].removeprefix('assets/')==voice['asset'])
for name,src in {'index.html':ROOT/'tools/preview_fukuchan_speech.html','fukuchan.glb':ROOT/'04_GAME_ASSETS/3d/hazard_adopted/v3_preview_20260917/fukuchan.glb','voice.wav':assets/voice['asset']}.items():
 dst=folder/name
 if dst.is_symlink():dst.unlink()
 dst.symlink_to(os.path.relpath(src,folder))
(folder/'voice.json').write_text(json.dumps({'text':voice['text'],'hz':envelopes['hz'],'open':envelope['open']},ensure_ascii=False))
print('http://127.0.0.1:5173/.local/fukuchan-speech/index.html')
