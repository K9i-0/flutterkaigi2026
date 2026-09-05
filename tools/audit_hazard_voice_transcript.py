"""Local Whisper transcript screening, without supplying expected dialogue as a prompt.
Requires torch, numpy and transformers (available in the canonical Irodori venv).
ASR is fallible; reports are not human listening or voice-identity approval.
"""
from pathlib import Path
import json,subprocess,hashlib
import numpy as np
import torch
from transformers import WhisperProcessor, WhisperForConditionalGeneration
ROOT=Path(__file__).resolve().parent.parent
FOLDER=ROOT/'04_GAME_ASSETS/audio/hazard'
REPORT=ROOT/'21_SOBAYA_HAZARD_LAB/qa/voice-transcript-20260906.json'
cache=ROOT/'.local/hazard_voice/asr-cache'
processor=WhisperProcessor.from_pretrained('openai/whisper-small',cache_dir=cache)
model=WhisperForConditionalGeneration.from_pretrained('openai/whisper-small',cache_dir=cache,use_safetensors=True).to('cpu')
torch.set_num_threads(4)
previous={r['id']:r for r in json.loads(REPORT.read_text())['clips']} if REPORT.exists() else {}
rows=[]
for clip in json.loads((FOLDER/'voice-manifest.json').read_text())['clips']:
    if clip['kind']!='speech':continue
    path=FOLDER/'voice'/Path(clip['asset']).name
    digest=hashlib.sha256(path.read_bytes()).hexdigest()
    old=previous.get(clip['id'])
    if old and old['sha256']==digest:
        rows.append(old);continue
    data=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ac','1','-ar','16000','-'])
    features=processor(np.frombuffer(data,dtype='<f4'),sampling_rate=16000,return_tensors='pt',return_attention_mask=True)
    with torch.inference_mode():
        result=model.generate(**features,language='ja',task='transcribe',max_new_tokens=160)
    text=processor.batch_decode(result,skip_special_tokens=True)[0]
    rows.append({'id':clip['id'],'speaker':clip['speaker'],'expected':clip['speechText'],'recognized':text,'sha256':digest})
    print(clip['id'],text,flush=True)
REPORT.write_text(json.dumps({'model':'openai/whisper-small','device':'cpu','note':'Automated transcript screening; not human listening or identity verification.','clips':rows},ensure_ascii=False,indent=2)+'\n')
print('COMPLETE',len(rows),flush=True)
