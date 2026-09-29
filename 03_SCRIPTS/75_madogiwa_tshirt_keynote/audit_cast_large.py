"""Decode/ASR screening while the four keynote auditions are generated.

ASR is supplementary, not an auditory review. Run in the Irodori environment.
"""
from pathlib import Path
import json
import subprocess
import time
import numpy as np
import torch
from transformers import WhisperProcessor, WhisperForConditionalGeneration
from generate_cast_large import OUT, ROOT, sha, write_json

torch.set_num_threads(3)
cache = ROOT / '.local/hazard_voice/asr-cache'
processor = WhisperProcessor.from_pretrained('openai/whisper-small', cache_dir=cache, local_files_only=True)
model = WhisperForConditionalGeneration.from_pretrained('openai/whisper-small', cache_dir=cache, local_files_only=True, use_safetensors=True).to('cpu').eval()
report = OUT / 'asr.json'
results = json.loads(report.read_text()) if report.exists() else {}
while True:
    record = OUT / 'generation.json'
    rows = json.loads(record.read_text()) if record.exists() else {}
    for key, row in rows.items():
        if results.get(key, {}).get('sha256') == row['sha256']:
            continue
        path = OUT / row['speaker'] / (row['id'] + '.wav')
        assert sha(path) == row['sha256']
        data = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'f32le', '-ar', '16000', '-ac', '1', '-'])
        samples = np.frombuffer(data, dtype='<f4')
        assert len(samples) and np.isfinite(samples).all(), key
        features = processor(samples, sampling_rate=16000, return_tensors='pt', return_attention_mask=True)
        with torch.inference_mode():
            output = model.generate(**features, language='ja', task='transcribe', max_new_tokens=160)
        recognized = processor.batch_decode(output, skip_special_tokens=True)[0]
        results[key] = {'expected': row['speechText'], 'recognized': recognized, 'sha256': row['sha256'], 'decoded': True, 'peak': float(np.abs(samples).max()), 'rms': float(np.sqrt(np.mean(samples ** 2))), 'auditoryReview': '未確認'}
        write_json(report, results)
        print(key, recognized, flush=True)
    if len(results) == 128:
        break
    time.sleep(5)
print('COMPLETE', len(results), flush=True)
