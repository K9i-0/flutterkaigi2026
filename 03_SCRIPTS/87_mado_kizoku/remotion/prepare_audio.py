from pathlib import Path
import json, subprocess, wave, hashlib, math
import numpy as np
P=Path(__file__).resolve().parent.parent
W=P.parents[1]/'.local/mado-kizoku-audio'
SR=48000
specs=[('sobaya_insult','sobaya_insult.wav','Sobaya',42,1.0,'優雅なお嬢様口調で、平然と毒舌を言う。自然な会話。',17,0,225),('yametaro','yametaro_kana.wav','Yametaro',7,1.0,'淡々と静かな圧をかける。自慢しない。',357,338,485),('sobaya_praise','sobaya_praise.wav','Sobaya',42,1.0,'一瞬ためらい、丁寧なお嬢様口調で取り繕う。',541,485,666),('takosan','takosan_small.wav','Takosan',43,1.0,'',693,690,810)]
def pcm(path):return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ar',str(SR),'-ac','2','-']),dtype='<f4').reshape(-1,2).copy()
orig=pcm(P/'wan3_part2_480p.mp4');out=orig.copy(); records=[]
for name,filename,speaker,seed,scale,caption,at,lo,hi in specs:
 adopted=P/(f'part2_{name}_irodori_v2.wav' if name=='takosan' else f'part2_{name}_irodori.wav')
 source=W/filename if (W/filename).exists() else adopted
 a=pcm(source)
 # Retain full generated waveform; no speech trimming or time stretching.
 gain=min(0.85/max(float(np.max(np.abs(a))),1e-6),4)
 a*=gain
 start=at*1600
 assert start+len(a)<=hi*1600,(name,len(a)/SR,(hi-at)/30)
 out[lo*1600:hi*1600]=0
 out[start:start+len(a)]+=a
 adopted=P/(f'part2_{name}_irodori_v2.wav' if name=='takosan' else f'part2_{name}_irodori.wav')
 import shutil
 if source.resolve()!=adopted.resolve(): shutil.copy2(source,adopted)
 records.append(dict(id=name,file=adopted.name,startFrame=at,endFrame=at+math.ceil(len(a)/1600),replaceStartFrame=lo,replaceEndFrame=hi,gain=gain,duration=len(a)/SR,model='Aratako/Irodori-TTS-v4.1-Small' if name=='takosan' else 'Aratako/Irodori-TTS-v4-Large',reference=f'02_CHARACTERS/{speaker}_voice.wav',seed=seed,duration_scale=scale,caption=caption,cfg_text=5,uncut=name in ('yametaro','takosan'),postprocess='sobaya_monsterize.sh' if speaker=='Sobaya' else 'none',sha256=hashlib.sha256(adopted.read_bytes()).hexdigest()))
# Single source of timing: integer source frames. Remove a redundant pause only.
last=records[-1]['endFrame']
# Keep the adopted one-second silent picture tail before end-credit fade.
picture_end=last+30
out[last*1600:picture_end*1600]=0
m=json.loads((P/'remotion/src/edit-manifest.json').read_text())
m['sourceSegments']=[dict(startFrame=0,endFrame=225),dict(startFrame=338,endFrame=picture_end)]
m['composition']['durationInFrames']=picture_end-113
m['audioRepairs']=records
joined=np.concatenate([out[:225*1600],out[338*1600:picture_end*1600]])
with wave.open(str(P/'remotion/public/repaired_audio.wav'),'wb') as w:
 w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR);w.writeframes((np.clip(joined,-1,1)*32767).astype('<i2').tobytes())
# Captions are refined using generated utterance boundaries, not planned shot windows.
m['captions']=[dict(startFrame=17,endFrame=130,speaker='そば屋',text='今度のプロジェクト、\nおコードがクソでしたわ。'),dict(startFrame=130,endFrame=records[0]['endFrame'],speaker='そば屋',text='ペットのお猿にでも\n書かせたのかしら？'),dict(startFrame=357-113,endFrame=records[1]['endFrame']-113,speaker='プログラマー猿',text='あのコードなら、\n全部ワイが書いてましてよ'),dict(startFrame=541-113,endFrame=records[2]['endFrame']-113,speaker='そば屋',text='……AIには出せない、\n人の温もりを感じましたわ'),dict(startFrame=693-113,endFrame=last-113,speaker='たこさん',text='本番もお燃えになってますわ')]
(P/'remotion/src/edit-manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
(P/'audio_repair_record.json').write_text(json.dumps({'repairs':records,'reference_choice':'Canonical voices explicitly requested; generated-video voices rejected by user','time_stretch':False,'original_audio_retained':'outside listed replacement intervals, before sourceSegments edit','listening':'not available in this runtime; ASR and waveform review only'},ensure_ascii=False,indent=2)+'\n')
print(json.dumps(records,ensure_ascii=False,indent=2));print('Final frames',last-113)
