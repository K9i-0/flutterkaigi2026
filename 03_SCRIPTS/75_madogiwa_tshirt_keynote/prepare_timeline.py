from pathlib import Path
import json,subprocess,math,argparse
EP=Path(__file__).resolve().parent
parser=argparse.ArgumentParser();parser.add_argument('--variant',default='sobaya',choices=['sobaya','nojobs']);args=parser.parse_args();nojobs=args.variant=='nojobs';suffix='-nojobs' if nojobs else '';speaker='yametaro' if nojobs else 'sobaya'
rows=json.loads((EP/f'remotion/src/dialogue{suffix}.json').read_text());cursor=58
lines=[]
for row in rows:
 p=EP/f"line_{row['id']}_{speaker}.wav"
 duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(p)])) if p.exists() else max(1.0,len(row['text'])/6)
 frames=math.ceil(duration*24)
 mouth=[]
 if nojobs and p.exists():
  import numpy as np
  buf=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-ac','1','-ar','48000','-f','f32le','-'])
  a=np.frombuffer(buf,dtype='<f4');a=np.pad(a,(0,max(0,frames*2000-len(a))))[:frames*2000]
  rms=np.sqrt(np.mean(a.reshape(frames,2000)**2,axis=1));ref=max(float(np.quantile(rms,.92)),.01)
  mouth=[round(min(.78,float((v/ref)**.65)*.67),4) if v>max(.004,ref*.10) else 0 for v in rms]
 lines.append({**row,'start':cursor,'end':cursor+frames,'audio':p.name,**({'mouth':mouth} if nojobs else {})})
 cursor+=frames+row['pauseFrames']
manifest={'fps':24,'width':1280,'height':720,'durationInFrames':cursor+24,'endcardStart':lines[-1]['end']+50,'audioReady':(EP/f'remotion/public/audio/master{suffix}.wav').exists(),'lines':lines}
(EP/f'remotion/src/edit-manifest{suffix}.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('Timeline',cursor+24,'frames',round((cursor+24)/24,2),'seconds')
