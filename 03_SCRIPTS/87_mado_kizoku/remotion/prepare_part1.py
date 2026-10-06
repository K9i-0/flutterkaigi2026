from pathlib import Path
import subprocess,json,math,shutil,wave,hashlib,os
import numpy as np
P=Path(__file__).resolve().parent.parent;W=P.parents[1]/'.local/mado-kizoku-part1';SR=48000

def pcm(p):return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-ar',str(SR),'-ac','2','-f','f32le','-']),dtype='<f4').reshape(-1,2).copy()
spec=[('sobaya','sobaya.wav',26,42,'Large',1,'そば屋','やはり、労働をサボっていただく\nおビールは格別ですわね'),('fukuchan','fukuchan_fit.wav',252,100,'Small',.65,'福ギュン','こちらのお菓子もギュンですわ'),('yametaro','yametaro_fit.wav',338,7,'Small',.35,'やめ太郎','来客用ですわ')]
audio=np.zeros((420*1600,2),np.float32);records=[];caps=[]
for name,candidate,start,seed,model,scale,label,text in spec:
 adopted=P/f'part1_{name}_irodori.wav';src=W/candidate if (W/candidate).exists() else adopted
 a=pcm(src)
 if name=='yametaro':
  a=a[:round(1.23*SR)].copy();fade=round(.025*SR);a[-fade:]*=np.linspace(1,0,fade)[:,None]
 gain=.85/max(float(np.max(np.abs(a))),1e-6);a*=gain
 end=start+math.ceil(len(a)/1600);assert end<=420,(name,end)
 audio[start*1600:start*1600+len(a)]+=a
 if src.resolve()!=adopted.resolve():shutil.copy2(src,adopted)
 records.append({'speaker':name,'file':adopted.name,'model':'Aratako/Irodori-TTS-v4-Large' if model=='Large' else 'Aratako/Irodori-TTS-v4.1-Small','reference':f'02_CHARACTERS/{name.capitalize()}_voice.wav','seed':seed,'cfg_text':5,'duration_scale':scale,'startFrame':start,'endFrame':end,'gain':gain,'postprocessing':'sobaya_monsterize.sh' if name=='sobaya' else 'none','sha256':hashlib.sha256(adopted.read_bytes()).hexdigest()})
 caps.append({'startFrame':start-(38 if start>=218 else 0),'endFrame':end-(38 if start>=218 else 0),'speaker':label,'text':text})
end=420;joined=np.concatenate([audio[:180*1600],audio[218*1600:end*1600]])
with wave.open(str(P/'remotion/public/part1_audio.wav'),'wb') as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR);w.writeframes(np.round(joined*32767).astype('<i2').tobytes())
m={'composition':{'id':'MadoKizokuPart1','width':1280,'height':720,'fps':30,'durationInFrames':end-38},'inputVideo':'part1.mp4','replacementAudio':'part1_audio.wav','overlays':[],'sourceSegments':[{'startFrame':0,'endFrame':180},{'startFrame':218,'endFrame':end}],'captions':caps,'audioRepairs':records,'notes':'Canonical voices for continuity. No audio/video time stretching. Shortened silent gap; 31 frames after final dialogue before part2.'}
(P/'remotion/src/part1-manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
if not (P/'remotion/public/part1.mp4').exists():os.link(P/'wan3_part1_480p.mp4',P/'remotion/public/part1.mp4')
(P/'audio_part1_record.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n');print(json.dumps(m,ensure_ascii=False,indent=2))
