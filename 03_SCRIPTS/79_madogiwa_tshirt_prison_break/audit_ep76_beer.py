"""Local ASR screening; not auditory or lip-sync approval."""
from pathlib import Path
import json, subprocess
import numpy as np
import torch
from transformers import WhisperProcessor, WhisperForConditionalGeneration
EP=Path(__file__).resolve().parent; ROOT=EP.parents[1]
p=ROOT/'03_SCRIPTS/76_sobaya_yakisoba_quake/final_remotion_revision04.mp4'
processor=WhisperProcessor.from_pretrained('openai/whisper-small',cache_dir=ROOT/'.local/hazard_voice/asr-cache',local_files_only=True)
model=WhisperForConditionalGeneration.from_pretrained('openai/whisper-small',cache_dir=ROOT/'.local/hazard_voice/asr-cache',local_files_only=True,use_safetensors=True,attn_implementation='eager').to('cpu')
torch.set_num_threads(4)
results=[]
for start,duration in [(8.5,5)]:
 raw=subprocess.check_output(['ffmpeg','-v','error','-ss',str(start),'-i',str(p),'-t',str(duration),'-f','f32le','-ar','16000','-ac','1','-'])
 feat=processor(np.frombuffer(raw,dtype='<f4'),sampling_rate=16000,return_tensors='pt',return_attention_mask=True)
 with torch.inference_mode():out=model.generate(**feat,language='ja',task='transcribe',max_new_tokens=220,return_timestamps=True,return_token_timestamps=True,return_dict_in_generate=True)
 tokens=out['sequences'][0].tolist()
 stamps=out['token_timestamps'][0].tolist()
 text=processor.tokenizer.decode(tokens,skip_special_tokens=True,decode_with_timestamps=True)
 (EP/'remotion/out/ep76-beer-token-times.json').write_text(json.dumps([{'token':processor.tokenizer.decode([token],skip_special_tokens=False),'time':time} for token,time in zip(tokens,stamps)],indent=2))
 results.append({'start':start,'duration':duration,'recognized':text}); print(results[-1],flush=True)
(EP/'remotion/out/ep76-beer-screening.json').write_text(json.dumps({'note':'Automated screening only; short music segments may hallucinate words.','clips':results},ensure_ascii=False,indent=2)+'\n')
