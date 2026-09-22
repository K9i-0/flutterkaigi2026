from pathlib import Path
import json,subprocess
import numpy as np,torch
from transformers import WhisperProcessor,WhisperForConditionalGeneration
E=Path(__file__).resolve().parent;ROOT=E.parents[1]
p=WhisperProcessor.from_pretrained('openai/whisper-small',cache_dir=ROOT/'.local/hazard_voice/asr-cache',local_files_only=True)
m=WhisperForConditionalGeneration.from_pretrained('openai/whisper-small',cache_dir=ROOT/'.local/hazard_voice/asr-cache',local_files_only=True,use_safetensors=True).to('cpu');torch.set_num_threads(4)
out=[]
for r in json.loads((E/'battle-dialogue.json').read_text()):
 path=E/f"battle_line{r['id']}_{r['speaker']}.wav"
 data=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ac','1','-ar','16000','-'])
 features=p(np.frombuffer(data,dtype='<f4'),sampling_rate=16000,return_tensors='pt',return_attention_mask=True)
 with torch.inference_mode():tokens=m.generate(**features,language='ja',task='transcribe',max_new_tokens=128)
 text=p.batch_decode(tokens,skip_special_tokens=True)[0]
 out.append({'id':r['id'],'expected':r['text'],'recognized':text});print(r['id'],text,flush=True)
(E/'battle-audio-audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
