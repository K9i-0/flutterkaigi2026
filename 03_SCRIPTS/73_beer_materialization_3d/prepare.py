"""Rebuild local assets and integer-frame edit manifest from accepted WAV files."""
from pathlib import Path
import os,json,subprocess,math,hashlib,wave,array
EP=Path(__file__).resolve().parent
ROOT=EP.parents[1]
R=EP/'remotion'
assets={'sobaya':'04_GAME_ASSETS/3d/hazard_adopted/optimized_20260919/sobaya.glb','yametaro':'04_GAME_ASSETS/3d/characters/yametaro/rig_nose_v3/yametaro.glb','beer_mug':'04_GAME_ASSETS/3d/props/beer_mug_v2/beer_mug.glb'}
for name,src in assets.items():
 dst=R/'public/models'/f'{name}.glb';dst.parent.mkdir(parents=True,exist_ok=True)
 if not dst.exists():os.link(ROOT/src,dst)
lines=json.loads((R/'src/dialogue.json').read_text());frame=36
for row in lines:
 src=EP/f"line{row['id']}_{row['speaker']}.wav"
 secs=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(src)]))
 n=math.ceil(secs*24)
 dst=R/'public/audio'/src.name
 if dst.exists() and not os.path.samefile(src,dst):dst.unlink()
 if not dst.exists():os.link(src,dst)
 row.update(start=frame,end=frame+n,audio='audio/'+src.name)
 # RMS mouth envelope: audio-driven, exactly one sample per output frame.
 pcm=subprocess.check_output(['ffmpeg','-v','error','-i',str(src),'-f','s16le','-ac','1','-ar','24000','-'])
 samples=array.array('h',pcm);env=[]
 for i in range(n):
  seg=samples[i*1000:(i+1)*1000]
  rms=math.sqrt(sum((x/32768)**2 for x in seg)/max(1,len(seg)))
  env.append(round(min(.8,rms*6),4))
 row['mouth']=env
 frame+=n+int(row.get('pauseAfterFrames',18))
(R/'src/edit-manifest.json').write_text(json.dumps({'composition':{'width':1280,'height':720,'fps':24,'durationInFrames':frame+36},'lines':lines},ensure_ascii=False,indent=2)+'\n')
(EP/'asset-provenance.json').write_text(json.dumps({k:{'source':v,'sha256':hashlib.sha256((ROOT/v).read_bytes()).hexdigest()} for k,v in assets.items()},indent=2)+'\n')
print('duration frames',frame+36,'seconds',(frame+36)/24)
