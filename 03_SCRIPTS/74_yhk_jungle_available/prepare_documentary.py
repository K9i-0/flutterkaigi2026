"""Create an integer-frame editorial manifest from measured canonical speech."""
from pathlib import Path
import json, subprocess, math, array, os, sys
EP=Path(__file__).resolve().parent; R=EP/'remotion'; FPS=24
rows=json.loads((R/'src/dialogue.json').read_text())
scene_specs=[('intro',25,2),('discovery',10,1),('offering',25,1),('window',25,2),('prayer',25,1),('waiting',25,2),('identity',25,5),('future',25,2),('ending',25,1)]
scenes=[];lines=[];cursor=0
for name,min_seconds,lead in scene_specs:
 start=cursor;cursor+=round(lead*FPS)
 for row in [r for r in rows if r['scene']==name]:
  src=EP/f"line_{row['id']}_{row['speaker']}.wav"
  if not src.exists() and '--draft' in sys.argv:
   src=EP/'voice_candidates'/('rejected_'+src.name)
  if not src.exists():raise SystemExit('Missing '+str(src))
  seconds=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(src)]))
  n=math.ceil(seconds*FPS)
  dest=R/'public/audio'/src.name;dest.parent.mkdir(exist_ok=True)
  if dest.exists() and not os.path.samefile(src,dest):dest.unlink()
  if not dest.exists():os.link(src,dest)
  pcm=subprocess.check_output(['ffmpeg','-v','error','-i',str(src),'-f','s16le','-ac','1','-ar','24000','-'])
  samples=array.array('h',pcm);env=[]
  for i in range(n):
   seg=samples[i*1000:(i+1)*1000];rms=math.sqrt(sum((v/32768)**2 for v in seg)/max(1,len(seg)));env.append(round(min(.85,rms*7),4))
  text=row['text'].replace('ワイエイチケー','YHK')
  if row['mode']=='chant':text=text.replace('。','……')
  lines.append({**row,'text':text,'startFrame':cursor,'endFrame':cursor+n,'audio':'audio/'+src.name,'mouth':env})
  cursor+=n+row['pauseAfterFrames']
 cursor=max(cursor,start+min_seconds*FPS)
 scenes.append({'id':name,'startFrame':start,'endFrame':cursor})
# Credits occupy the closing hold and extend only if necessary.
comp={'width':854,'height':480,'fps':FPS,'durationInFrames':cursor+4*FPS}
manifest={'composition':comp,'scenes':scenes,'lines':lines,'creditsStartFrame':cursor-24,'ambience':'audio/rainforest_cc0.ogg','narrator':'取材・語り：やめ太郎','status':'measured speech with natural holds'}
(R/'src/edit-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
source=EP/'audio_sources/rainforest_cc0.ogg';dest=R/'public/audio/rainforest_cc0.ogg'
if source.exists() and not dest.exists():os.link(source,dest)
for src in (EP/'backgrounds').glob('intro_*.png'):
 dest=R/'public/backgrounds'/src.name
 if not dest.exists():os.link(src,dest)
print('Duration',cursor/FPS+4,'seconds',comp['durationInFrames'],'frames')
for s in scenes:print(s['id'],round(s['startFrame']/FPS,2),round(s['endFrame']/FPS,2))
