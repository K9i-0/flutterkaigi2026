"""ASR and decode screening of comparison WAVs; not an auditory review."""
from pathlib import Path
import hashlib
import json
import subprocess
import numpy as np
import torch
from transformers import WhisperProcessor, WhisperForConditionalGeneration

EP = Path(__file__).resolve().parent
ROOT = EP.parents[1]
OUT = ROOT / '.local/irodori-large-ep75'
torch.set_num_threads(4)
cache = ROOT / '.local/hazard_voice/asr-cache'
processor = WhisperProcessor.from_pretrained('openai/whisper-small', cache_dir=cache, local_files_only=True)
model = WhisperForConditionalGeneration.from_pretrained('openai/whisper-small', cache_dir=cache,
    local_files_only=True, use_safetensors=True).to('cpu').eval()
report = OUT / 'asr.json'
results = json.loads(report.read_text()) if report.exists() else []
previous = {(r['speaker'], r['id'], r['kind']): r for r in results}
for row in json.loads((OUT / 'generation.json').read_text()):
    for kind in ['small', 'large']:
        path = OUT / row[kind + 'File']
        sha = hashlib.sha256(path.read_bytes()).hexdigest()
        key = row['speaker'], row['id'], kind
        if previous.get(key, {}).get('sha256') == sha:
            continue
        data = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'f32le', '-ar', '16000', '-ac', '1', '-'])
        samples = np.frombuffer(data, dtype='<f4')
        if not len(samples) or not np.isfinite(samples).all():
            raise ValueError(f'Invalid waveform: {path}')
        features = processor(samples, sampling_rate=16000, return_tensors='pt', return_attention_mask=True)
        with torch.inference_mode():
            output = model.generate(**features, language='ja', task='transcribe', max_new_tokens=160)
        recognized = processor.batch_decode(output, skip_special_tokens=True)[0]
        previous[key] = {'speaker': row['speaker'], 'id': row['id'], 'kind': kind,
            'expected': row['text'], 'speechText': row['speechText'], 'recognized': recognized,
            'sha256': sha, 'decoded': True, 'peak': float(np.abs(samples).max()),
            'rms': float(np.sqrt(np.mean(samples ** 2))), 'auditoryReview': '未確認'}
        temp = report.with_suffix('.tmp')
        temp.write_text(json.dumps(list(previous.values()), ensure_ascii=False, indent=2) + '\n')
        temp.replace(report)
        print(row['speaker'], row['id'], kind, recognized, flush=True)
print('COMPLETE', len(previous), flush=True)
