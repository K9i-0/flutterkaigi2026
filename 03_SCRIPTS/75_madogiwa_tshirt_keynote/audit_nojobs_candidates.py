"""Automated ASR screening; not a replacement for auditory quality judgement."""
from pathlib import Path
import json, subprocess, hashlib, argparse
import numpy as np
import torch
from transformers import WhisperProcessor,WhisperForConditionalGeneration
EP=Path(__file__).resolve().parent;ROOT=EP.parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--variant',default='sobaya',choices=['sobaya','nojobs']);args=parser.parse_args();suffix='-nojobs' if args.variant=='nojobs' else ''
processor=WhisperProcessor.from_pretrained('openai/whisper-small',cache_dir=ROOT/'.local/hazard_voice/asr-cache',local_files_only=True)
model=WhisperForConditionalGeneration.from_pretrained('openai/whisper-small',cache_dir=ROOT/'.local/hazard_voice/asr-cache',local_files_only=True,use_safetensors=True).to('cpu')
torch.set_num_threads(4)
report=EP/'remotion/out/speech-audit-nojobs-repairs.json'
previous={r['id']:r for r in json.loads(report.read_text())} if report.exists() else {}
result=[]
for row in json.loads((EP/'remotion/out/repair-nojobs-candidates.json').read_text()):
 p=EP/row['candidate']
 if not p.exists():continue
 sha=hashlib.sha256(p.read_bytes()).hexdigest()
 if row['id'] in previous and previous[row['id']]['sha256']==sha:result.append(previous[row['id']]);continue
 data=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-ar','16000','-ac','1','-'])
 feat=processor(np.frombuffer(data,dtype='<f4'),sampling_rate=16000,return_tensors='pt',return_attention_mask=True)
 with torch.inference_mode():out=model.generate(**feat,language='ja',task='transcribe',max_new_tokens=160)
 recognized=processor.batch_decode(out,skip_special_tokens=True)[0]
 result.append({'id':row['id'],'expected':row['speechText'],'recognized':recognized,'sha256':sha})
 report.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
 print(row['id'],recognized,flush=True)
report.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('COMPLETE',len(result),flush=True)
