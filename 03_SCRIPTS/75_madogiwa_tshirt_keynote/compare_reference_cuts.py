"""Controlled Large reference-cut experiment; candidates remain under .local.
Run using .local/Irodori-TTS-large/.venv/bin/python with prepare/generate/audit/package.
Only reference audio varies within each matched speaker/text/seed comparison.
"""
from pathlib import Path
import argparse,dataclasses,hashlib,json,subprocess,sys,time,wave
EP=Path(__file__).resolve().parent
ROOT=EP.parents[1]
OUT=ROOT/'.local/irodori-large-ep75/reference-cuts'
TTS=ROOT/'.local/Irodori-TTS-large'
MODEL='Aratako/Irodori-TTS-v4-Large'
REVISION='2e0c55428ce97268a507f1feeb2478f8d9148e8b'
CAPTION='自信に満ちた製品発表。落ち着いて堂々と、明瞭に話す。'
CAST={
 'fukuchan':{'name':'福ちゃん','seed':100,'source':'02_CHARACTERS/Fukuchan_voice.wav','cutEnd':5.16,'alternate':'02_CHARACTERS/voice_references/Fukuchan_ref_company.wav','alternateEnd':4.84,'cutNote':'自己紹介の終わりを残し、挨拶・決め台詞・次のCCO説明の言いかけを除く。','alternateNote':'株式会社ゆめみは2000年に創業をした会社です。'},
 'yametaro':{'name':'やめ太郎','seed':7,'source':'02_CHARACTERS/Yametaro_voice.wav','cutEnd':6.25,'alternate':'02_CHARACTERS/voice_references/Yametaro_ref_intro_short.wav','alternateEnd':6.02,'cutNote':'後端の次の句の断片を除く。ただし元の内容は「渡り歩いて」と続く会話なので、この切り出しだけでは完結文にならない。','alternateNote':'私は株式会社ゆめみのフロントエンドエンジニアの無職やめ太郎と申します。末尾の次の「30歳」を除く。'},
}
LINES=[('arms','腕です。'),('perfect','完璧です。'),('intro','今日という日を、私はずっと待っていました。'),('arms_seed42','腕です。')]
LABELS={'A_original':'A 現在の参照','B_cut':'B 現在の参照の末尾をカット','C_alternate':'C 別の完結した一文'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):
 t=p.with_suffix('.tmp');t.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n');t.replace(p)
def duration(p):
 with wave.open(str(p)) as w:return w.getnframes()/w.getframerate()
def prepare():
 OUT.mkdir(parents=True,exist_ok=True);refs={}
 for speaker,c in CAST.items():
  for condition in LABELS:
   source=ROOT/(c['alternate'] if condition=='C_alternate' else c['source'])
   end=c['alternateEnd'] if condition=='C_alternate' else c['cutEnd'] if condition=='B_cut' else None
   target=OUT/f'{speaker}_{condition}_reference.wav'
   # Preserve PCM samples exactly; do not denoise, normalize or change speed.
   with wave.open(str(source)) as inp:
    params=inp.getparams();count=round(end*inp.getframerate()) if end else inp.getnframes();samples=inp.readframes(count)
   with wave.open(str(target),'wb') as dest:dest.setparams(params);dest.writeframes(samples)
   refs[speaker+'/'+condition]={'file':str(target.relative_to(ROOT)),'sha256':sha(target),'source':str(source.relative_to(ROOT)),'sourceSha256':sha(source),'start':0,'end':end,'seconds':duration(target),'label':LABELS[condition],'note':c['alternateNote'] if condition=='C_alternate' else c['cutNote'] if condition=='B_cut' else '正典PCM全長、内容変更なし'}
 write(OUT/'references.json',refs);print(json.dumps(refs,ensure_ascii=False,indent=2))
def generate():
 sys.path.insert(0,str(TTS))
 from huggingface_hub import snapshot_download
 from irodori_tts.inference_runtime import InferenceRuntime,RuntimeKey,SamplingRequest,save_wav
 snapshot=Path(snapshot_download(MODEL,revision=REVISION,local_files_only=True));commit=subprocess.check_output(['git','-C',str(TTS),'rev-parse','HEAD'],text=True).strip()
 refs=json.loads((OUT/'references.json').read_text());path=OUT/'generation.json';records=json.loads(path.read_text()) if path.exists() else {};runtime=None
 for speaker,c in CAST.items():
  for condition in LABELS:
   ref=refs[speaker+'/'+condition];refpath=ROOT/ref['file'];assert sha(refpath)==ref['sha256']
   for ident,text in LINES:
    seed=42 if ident=='arms_seed42' else c['seed']
    request=SamplingRequest(text=text,caption=CAPTION,ref_wav=str(refpath),seed=seed,duration_scale=1.0,cfg_scale_text=3.0,trim_tail=True)
    identity={'request':dataclasses.asdict(request),'referenceSha256':ref['sha256'],'model':MODEL,'revision':REVISION,'runtimeCommit':commit,'precision':'fp32','postprocess':'same wrapper silence trim'}
    fingerprint=hashlib.sha256(json.dumps(identity,sort_keys=True).encode()).hexdigest();key=f'{speaker}/{condition}/{ident}';folder=OUT/speaker/condition;folder.mkdir(parents=True,exist_ok=True);final=folder/f'{ident}.wav'
    if records.get(key,{}).get('fingerprint')==fingerprint and final.exists() and sha(final)==records[key]['sha256']:continue
    if runtime is None:
     print('LOAD',flush=True);runtime=InferenceRuntime.from_key(RuntimeKey(checkpoint=str(snapshot/'model.safetensors'),model_device='mps',codec_device='mps',model_precision='fp32',codec_precision='fp32'))
    print('GENERATE',key,flush=True);started=time.monotonic();result=runtime.synthesize(request,log_fn=lambda _:None);raw=folder/f'{ident}_raw.wav';save_wav(raw,result.audio,result.sample_rate)
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(raw),'-af','silenceremove=start_periods=1:start_threshold=-40dB:start_silence=0.1,areverse,silenceremove=start_periods=1:start_threshold=-40dB:start_silence=0.2,areverse',str(final)],check=True)
    records[key]={'speaker':speaker,'condition':condition,'id':ident,'text':text,'seed':seed,'identity':identity,'fingerprint':fingerprint,'file':str(final.relative_to(OUT)),'sha256':sha(final),'duration':duration(final),'generationSeconds':time.monotonic()-started,'auditoryReview':'未確認','adopted':False};write(path,records);print('DONE',len(records),'/24',key,records[key]['duration'],flush=True)
 print('COMPLETE',flush=True)
def audit():
 import numpy as np,torch
 from transformers import WhisperProcessor,WhisperForConditionalGeneration
 torch.set_num_threads(3);cache=ROOT/'.local/hazard_voice/asr-cache'
 processor=WhisperProcessor.from_pretrained('openai/whisper-small',cache_dir=cache,local_files_only=True)
 model=WhisperForConditionalGeneration.from_pretrained('openai/whisper-small',cache_dir=cache,local_files_only=True,use_safetensors=True).eval()
 path=OUT/'asr.json';results=json.loads(path.read_text()) if path.exists() else {}
 while True:
  file=OUT/'generation.json';records=json.loads(file.read_text()) if file.exists() else {}
  for key,row in records.items():
   if results.get(key,{}).get('sha256')==row['sha256']:continue
   data=subprocess.check_output(['ffmpeg','-v','error','-i',str(OUT/row['file']),'-ac','1','-ar','16000','-f','f32le','-']);x=np.frombuffer(data,dtype='<f4');assert len(x) and np.isfinite(x).all()
   features=processor(x,sampling_rate=16000,return_tensors='pt',return_attention_mask=True)
   with torch.inference_mode():tokens=model.generate(**features,language='ja',task='transcribe',max_new_tokens=160)
   text=processor.batch_decode(tokens,skip_special_tokens=True)[0];results[key]={'expected':row['text'],'recognized':text,'sha256':row['sha256'],'fullDecode':True,'auditoryReview':'未確認'};write(path,results);print(key,text,flush=True)
  if len(results)==24:break
  time.sleep(5)
 print('COMPLETE',flush=True)
def package():
 records=json.loads((OUT/'generation.json').read_text());assert len(records)==24
 for speaker,c in CAST.items():
  timeline=[];joined=OUT/f'{speaker}_comparison_unleveled.wav';cursor=0
  with wave.open(str(joined),'wb') as dest:
   dest.setparams((1,2,48000,0,'NONE','not compressed'))
   for ident,text in LINES:
    for condition in LABELS:
     row=records[f'{speaker}/{condition}/{ident}'];data=subprocess.check_output(['ffmpeg','-v','error','-i',str(OUT/row['file']),'-ar','48000','-ac','1','-f','s16le','-']);n=len(data)//2
     timeline.append({'start':cursor/48000,'end':(cursor+n)/48000,'condition':condition,'text':text,'seed':row['seed']});dest.writeframes(data);pause=96000 if condition=='C_alternate' else 48000;dest.writeframes(b'\0\0'*pause);cursor+=n+pause
  final=OUT/f'{speaker}_ABC_comparison.wav';subprocess.run(['ffmpeg','-v','error','-y','-i',str(joined),'-af','loudnorm=I=-16:TP=-1.5:LRA=11','-ar','48000','-ac','1','-c:a','pcm_s16le',str(final)],check=True)
  write(OUT/f'{speaker}_comparison.json',{'speaker':speaker,'name':c['name'],'file':str(final.relative_to(ROOT)),'duration':duration(final),'sha256':sha(final),'timeline':timeline,'auditoryReview':'未確認・ユーザー比較試聴用'});print(final,flush=True)
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['prepare','generate','audit','package']);args=parser.parse_args();globals()[args.mode]()
