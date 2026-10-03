from pathlib import Path
import os,subprocess,json,hashlib
root=Path.cwd();w=root/'.local/chuagostini-20261003/voice-casting'
text='あなたのへやを、あこがれのまどぎわに。しゅうかん、まどぎわをつくる。そうかん。組み立てるたび、理想のまどぎわに近づいていく。アーロンチュアから、そばやのかめんまで。じつぶつだいでさいげん。まどぎわぞくのにちじょうを、リアルにたいかん。まどぎわのたのしみかたも、くわしくかいせつ。アーロンチュアのざいりょういっしきがついて、そうかんごうは、さんびゃくきゅうじゅうきゅうえん。'
voices=[
 dict(id='female_cm',label='CM風の女声',seed=121,model='Aratako/Irodori-TTS-v4.1-Small',ref=None,caption='明るく華やかな成人女性の声。テレビCMのプロの女性ナレーター。澄んだ中高音で、笑顔が伝わる親しみやすい響き。標準語の明瞭な発音、軽快なテンポ、商品への期待が膨らむ自然な抑揚。'),
 dict(id='female_announcer',label='女性アナウンサー',seed=2028,model='Aratako/Irodori-TTS-v4.1-Small',ref=None,caption='知的で落ち着いた成人女性の声。放送局の女性アナウンサー。安定した中音域、端正な標準語、滑らかで明瞭な発音。抑揚を抑えた上品で信頼感のある読み。'),
 dict(id='fukuchan',label='福ちゃん',seed=100,model='Aratako/Irodori-TTS-v4.1-Small',ref='02_CHARACTERS/Fukuchan_voice.wav',caption='明るくハキハキとした、笑顔のコマーシャルナレーション。テンポよく、商品を楽しそうに紹介する。'),
 dict(id='sobaya',label='そば屋',seed=42,model='Aratako/Irodori-TTS-v4-Large',ref='02_CHARACTERS/Sobaya_voice.wav',caption='落ち着いたコマーシャルナレーション。明瞭に、堂々と商品を紹介する。')]
records=[]
for v in voices:
 out=w/(v['id']+'_raw.wav');log=w/(v['id']+'.log')
 if v['ref']:
  cmd=[str(root/'tools/irodori_speak.sh'),text,str(out),str(root/v['ref']),str(v['seed']),v['caption']];cwd=root
 else:
  cmd=['uv','run','--no-sync','python','infer.py','--hf-checkpoint',v['model'],'--no-ref','--text',text,'--caption',v['caption'],'--seed',str(v['seed']),'--cfg-scale-text','5','--output-wav',str(out)];cwd=root/'.local/Irodori-TTS'
 env=os.environ.copy();env.update(IRODORI_TTS_CHECKPOINT=v['model'],IRODORI_CFG_SCALE_TEXT='5')
 with log.open('w') as f:subprocess.run(cmd,cwd=cwd,env=env,stdout=f,stderr=f,check=True)
 source=out
 if v['id']=='sobaya':
  source=w/'sobaya_processed.wav';subprocess.run([str(root/'tools/sobaya_monsterize.sh'),str(out),str(source)],stdout=subprocess.DEVNULL,check=True)
 final=w/(v['id']+'.wav')
 subprocess.run(['ffmpeg','-y','-v','error','-i',str(source),'-af','silenceremove=start_periods=1:start_threshold=-40dB:start_silence=0.08,areverse,silenceremove=start_periods=1:start_threshold=-40dB:start_silence=0.15,areverse,loudnorm=I=-17:TP=-2:LRA=7','-ar','48000','-ac','1',str(final)],check=True)
 v.update(file=final.name,duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(final)],text=True)),sha256=hashlib.sha256(final.read_bytes()).hexdigest(),text=text)
 records.append(v);(w/'candidates.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n');print(v['id'],v['duration'],flush=True)
