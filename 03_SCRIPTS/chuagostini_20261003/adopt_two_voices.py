from pathlib import Path
import json,hashlib,subprocess,shutil,numpy as np,soundfile as sf
root=Path.cwd();p=root/'03_SCRIPTS/chuagostini_20261003';w=root/'.local/chuagostini-20261003/voice-casting';sr=48000
# Sentence boundaries from ASR, then moved into measured silence. Phonemes are not stretched.
targets=[(0,3.4),(3.4,6.466667),(6.466667,10.566667),(10.566667,15.466667),(15.466667,18.733333),(18.733333,22.333333),(22.333333,28)]
regions={'female_cm':[(0,3.28),(3.97,7.49),(7.87,11.56),(12.03,16.49),(16.88,19.98),(20.36,23.47),(24.03,30)],'sobaya':[(0,2.48),(3.23,5.56),(6.27,9.15),(9.65,13.68),(14.14,16.89),(17.53,20.78),(21.28,26.250438)]}
# Only the center portions of detected pauses are removed. Keep natural silence on each side.
remove={'female_cm':[(4.80,5.10),(6.39,6.67),(26.72,26.98),(28.06,28.16)],'sobaya':[]}
base,_=sf.read(root/'.local/chuagostini-20261003/wan-voice-repair/completed_original.wav',always_2d=True);base=base[:30*sr];bg,_=sf.read(root/'.local/chuagostini-20261003/wan-voice-repair/background_48k.wav',always_2d=True)
reports=[]
for voice in regions:
 source=w/(voice+'.wav');audio,rate=sf.read(source);assert rate==sr
 source_name=f'narration_selected_{voice}.wav';shutil.copy2(source,p/source_name)
 mix=base.copy();mix[:28*sr]=bg[:28*sr];mix[28*sr-480:28*sr]*=np.linspace(1,0,480)[:,None]
 placements=[]
 for i,((a,b),(start,end)) in enumerate(zip(regions[voice],targets)):
  first,last=round(a*sr),min(round(b*sr),len(audio));pieces=[];cursor=first
  for x,y in remove[voice]:
   x,y=round(x*sr),round(y*sr)
   if first<x<y<last:pieces.append(audio[cursor:x]);cursor=y
  pieces.append(audio[cursor:last]);clip=np.concatenate(pieces)
  pos=round((start+.035)*sr);assert pos+len(clip)<=round(end*sr),(voice,i,len(clip)/sr,end-start)
  mix[pos:pos+len(clip)]+=clip[:,None]
  placements.append({'line':i+1,'source_start_sample':first,'source_end_sample':last,'target_start_sample':pos,'duration_samples':len(clip)})
 assert np.array_equal(mix[28*sr:],base[28*sr:]);assert abs(mix).max()<1
 master=f'narration_master_{voice}.wav';sf.write(p/master,mix,sr,subtype='PCM_24');shutil.copy2(p/master,p/'remotion/public'/master)
 output=f'final_remotion_cm_{voice}.mp4';subprocess.run(['ffmpeg','-y','-v','error','-i',str(p/'final_remotion_cm_wan.mp4'),'-i',str(p/master),'-map','0:v:0','-map','1:a:0','-c:v','copy','-c:a','aac','-b:a','192k','-t','30','-movflags','+faststart',str(p/output)],check=True)
 reports.append({'voice':voice,'source':source_name,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'master':master,'output':output,'sample_rate':sr,'placements':placements,'removed_silence_seconds':remove[voice],'time_stretch':False,'ending_pcm_equal_from_seconds':28,'peak':float(abs(mix).max())})
(p/'two-voice-edits.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2)+'\n')
print('Created both 30-second video versions from selected samples.')
