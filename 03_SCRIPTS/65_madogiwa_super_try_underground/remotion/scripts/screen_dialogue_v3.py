"""Offline ASR screening only; does not certify listening or lip synchronization."""
import json,subprocess
from pathlib import Path
import numpy as np
import torch
from transformers import WhisperProcessor, WhisperForConditionalGeneration
r=Path(__file__).resolve().parents[2]
repo=r.parents[1]
cache=repo/'.local/hazard_voice/asr-cache'
p=WhisperProcessor.from_pretrained('openai/whisper-small',cache_dir=cache,local_files_only=True)
m=WhisperForConditionalGeneration.from_pretrained('openai/whisper-small',cache_dir=cache,local_files_only=True,use_safetensors=True).to('cpu')
torch.set_num_threads(4)
rows=[]
for start,end,lang in [(0,7,'ja'),(7,12,'ja'),(15,19,'ja'),(19,23.5,'ja'),(23.5,27.5,'ja'),(27.5,30,'ja'),(30,35.5,'ja'),(35.5,39,'ja'),(39,42,'ja'),(42,45,'ja')]:
 b=subprocess.check_output(['ffmpeg','-v','error','-ss',str(start),'-t',str(end-start),'-i',str(r/'joined_wan_v3_480p.mp4'),'-f','f32le','-ac','1','-ar','16000','-'])
 x=p(np.frombuffer(b,dtype='<f4'),sampling_rate=16000,return_tensors='pt',return_attention_mask=True)
 with torch.inference_mode(): y=m.generate(**x,language=lang,task='transcribe',max_new_tokens=120,return_timestamps=True)
 row={'start':start,'end':end,'language':lang,'recognized':p.tokenizer.decode(y.reshape(-1).tolist(),skip_special_tokens=True,decode_with_timestamps=True)};rows.append(row);print(row,flush=True)
(r/'remotion/out/dialogue_screening_v3.json').write_text(json.dumps({'note':'Automatic ASR without expected text prompt, not direct listening.','segments':rows},ensure_ascii=False,indent=2)+'\n')
