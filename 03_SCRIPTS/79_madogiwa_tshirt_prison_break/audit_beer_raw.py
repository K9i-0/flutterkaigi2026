"""Local ASR screening; not auditory or lip-sync approval."""
from pathlib import Path
import json, subprocess
import numpy as np
import torch
from transformers import WhisperProcessor, WhisperForConditionalGeneration
EP=Path(__file__).resolve().parent; ROOT=EP.parents[1]
p=ROOT/'.local/prison_beer_raw.wav'
processor=WhisperProcessor.from_pretrained('openai/whisper-small',cache_dir=ROOT/'.local/hazard_voice/asr-cache',local_files_only=True)
model=WhisperForConditionalGeneration.from_pretrained('openai/whisper-small',cache_dir=ROOT/'.local/hazard_voice/asr-cache',local_files_only=True,use_safetensors=True).to('cpu')
torch.set_num_threads(4)
results=[]
for start,duration in [(0,2)]:
 raw=subprocess.check_output(['ffmpeg','-v','error','-ss',str(start),'-i',str(p),'-t',str(duration),'-f','f32le','-ar','16000','-ac','1','-'])
 feat=processor(np.frombuffer(raw,dtype='<f4'),sampling_rate=16000,return_tensors='pt',return_attention_mask=True)
 with torch.inference_mode():out=model.generate(**feat,language='ja',task='transcribe',max_new_tokens=220,return_timestamps=True)
 text=processor.tokenizer.decode(out[0].tolist(),skip_special_tokens=True,decode_with_timestamps=True)
 results.append({'start':start,'duration':duration,'recognized':text}); print(results[-1],flush=True)
(EP/'remotion/out/asr-v2-beer-raw.json').write_text(json.dumps({'note':'Automated screening only; short music segments may hallucinate words.','clips':results},ensure_ascii=False,indent=2)+'\n')
