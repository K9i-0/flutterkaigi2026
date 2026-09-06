"""Generate game voices with the canonical Irodori wrapper; safe to resume.
Run tool/export_hazard_voice.dart first. Raw candidates stay under .local.
"""
from pathlib import Path
import hashlib,json,os,subprocess,time,wave
import urllib.request,urllib.parse
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'04_GAME_ASSETS/audio/hazard'
RAW=ROOT/'.local/hazard_voice/raw';RAW.mkdir(parents=True,exist_ok=True)
CAST={
 '福ちゃん':('Fukuchan_voice.wav',100,'3b597fdb0c6c7e103a1998345f56565652b86b6344127b3d5d52e0a1fd5b9f35'),
 'やめ太郎':('Yametaro_voice.wav',7,'ede825a58cf1920f1bdfb353eea17d0feb24f20592d7f36d7c5c22c5ab60530b'),
 'そば屋':('Sobaya_voice.wav',42,'976916e670fea5fcf0f741d45e150eaf055c3b0e11d240e3be656dd724166b58'),
 'ナレーション':('YumeTeleAnchor_voice.wav',2026,'e3cd210adad43fb3338684555e7e066f83cfad2400265c8a73fa55b9f96b753f'),
}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def caption(row):
 if row['speaker']=='ナレーション':return '落ち着いたアナウンサーの情景ナレーション。標準語で、明瞭に、ゆっくりと文章の区切りに間を取り、最後まで読み上げる。抑制された抑揚で真面目に話す。'
 if any(u.startswith('dialogue:reaction:') for u in row['uses']):return '突然殴られて痛がり、仲間に助けを求める。短く切迫して。声の同一性は保つ。'
 if 'ワイ、二週間ぶりにくつろいだんやけど。' in row['text']:return '関西弁で仲間へ話す。椅子が段ボールだと気づき、そのあと二週間ぶりにくつろいだとぼやく。二つの文を最後まで明瞭に話す。'
 if row['text']=='え、また集まるの？':return '驚いて、短く聞き返す。'
 if row['speaker']=='そば屋':return '相手を誘うように、堂々と。最後の乾杯を呼びかける。'
 if any(u.startswith('event:ending') for u in row['uses']):return 'ほっとして、親しい仲間に軽い冗談を交えながら自然に話す。'
 if row['speaker']=='福ちゃん':return '友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。'
 return '焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。'
rows=json.loads((OUT/'voice-lines.json').read_text())
revision=subprocess.check_output(['git','-C',str(ROOT/'.local/Irodori-TTS'),'rev-parse','HEAD'],text=True).strip()
manifest={'version':1,'model':'Aratako/Irodori-TTS-v4.1-Small','engine_revision':revision,'clips':[]}
for index,row in enumerate(rows):
 ident=hashlib.sha256((row['speaker']+'\n'+row['text']).encode()).hexdigest()[:16]
 if row['speaker']=='たこさん':
  def post(path,query,body=None):
   url='http://127.0.0.1:50021/'+path+'?'+urllib.parse.urlencode(query)
   req=urllib.request.Request(url,data=body or b'',headers={'Content-Type':'application/json'},method='POST')
   return urllib.request.urlopen(req,timeout=120).read()
  raw=RAW/f'{ident}_voidoll89.wav'
  if not raw.exists():
   query=json.loads(post('audio_query',{'speaker':89,'text':row['text'].replace('\n',' ')}))
   query['speedScale']=1.08 if any('reaction:' in u for u in row['uses']) else 1.0
   raw.write_bytes(post('synthesis',{'speaker':89},json.dumps(query).encode()))
  dest=OUT/'voice'/f'{ident}.wav'
  subprocess.run(['ffmpeg','-y','-v','error','-i',str(raw),'-af','loudnorm=I=-18:TP=-2:LRA=7','-ar','24000','-ac','1','-c:a','pcm_s16le',str(dest)],check=True)
  with wave.open(str(dest)) as f:seconds=f.getnframes()/f.getframerate()
  manifest['clips'].append({**row,'id':ident,'asset':f'audio/voice/{ident}.wav','seconds':seconds,'kind':'speech','model':'VOICEVOX:Voidoll','style':89,'speedScale':1.08 if any('reaction:' in u for u in row['uses']) else 1.0,'speechText':row['text'].replace('\n',' '),'engine_version':json.loads(urllib.request.urlopen('http://127.0.0.1:50021/version').read()),'sha256':sha(dest),'raw_sha256':sha(raw),'provenance':'Same casting as episode 21; VOICEVOX:Voidoll credit shown in game journal'})
  (RAW/'working-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
  print(f'READY {ident} {seconds:.3f}s VOICEVOX:Voidoll',flush=True)
  continue
 ref_name,seed,expected=CAST[row['speaker']];ref=ROOT/'02_CHARACTERS'/ref_name
 if sha(ref)!=expected:raise RuntimeError(f'Canonical reference mismatch: {ref.name}')
 speech=row['text'].replace('\n',' ').replace('せやな。……ところで、', 'せやな。ところで、')
 if row['speaker']=='ナレーション':
  speech=speech.replace('CHAPTER 02 —', '第二章。').replace('LAST ORDER —', 'ラストオーダー。').replace('撤収対象外 ', '撤収対象外。').replace('そば屋エンジン中枢 ', 'そば屋エンジン中枢。')
 if row['text']=='え、また集まるの？':speech='えっ、また集まるの？'
 for label,spoken in [('Xで','エックスで'),('Fで','エフで'),('Eで','イーで'),('Cで','シーで')]:speech=speech.replace(label,spoken)
 request={'text':speech,'speaker':row['speaker'],'caption':caption(row),'seed':seed,'reference':str(ref.relative_to(ROOT)),'reference_sha256':expected,'model':manifest['model']}
 raw=RAW/f'{ident}.wav';meta=RAW/f'{ident}.json';log=RAW/f'{ident}.log'
 if not raw.exists() or not meta.exists() or json.loads(meta.read_text())!=request:
  print(f'GENERATE {index+1}/{len(rows)} {row["speaker"]} {ident}',flush=True)
  with log.open('w') as output:
   subprocess.run([str(ROOT/'.claude/skills/seedance/scripts/irodori_speak.sh'),speech,str(raw),str(ref),str(seed),request['caption']],cwd=ROOT,env={**os.environ,'HF_HUB_OFFLINE':'1'},stdout=output,stderr=subprocess.STDOUT,check=True)
  meta.write_text(json.dumps(request,ensure_ascii=False,indent=2)+'\n')
 source=raw
 if row['speaker']=='そば屋':
  source=RAW/f'{ident}_monster.wav'
  subprocess.run([str(ROOT/'.claude/skills/seedance/scripts/sobaya_monsterize.sh'),str(raw),str(source)],check=True)
 dest=OUT/'voice'/f'{ident}.wav';dest.parent.mkdir(parents=True,exist_ok=True)
 subprocess.run(['ffmpeg','-y','-v','error','-i',str(source),'-af','loudnorm=I=-18:TP=-2:LRA=7','-ar','24000','-ac','1','-c:a','pcm_s16le',str(dest)],check=True)
 with wave.open(str(dest)) as f:seconds=f.getnframes()/f.getframerate()
 manifest['clips'].append({**row,**request,'text':row['text'],'speechText':speech,'id':ident,'asset':f'audio/voice/{ident}.wav','seconds':seconds,'kind':'speech','sha256':sha(dest),'raw_sha256':sha(raw)})
 (RAW/'working-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 print(f'READY {ident} {seconds:.3f}s',flush=True)
pending=OUT/'voice-manifest.pending.json'
pending.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
pending.replace(OUT/'voice-manifest.json')
print(f'COMPLETE {len(manifest["clips"])} cues',flush=True)
