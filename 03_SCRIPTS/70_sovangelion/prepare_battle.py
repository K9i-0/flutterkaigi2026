"""Relink canonical inputs and build the integer-frame 3 minute film manifest."""
from pathlib import Path
import os,json,math,subprocess,array,hashlib,shutil
E=Path(__file__).resolve().parent;ROOT=E.parents[1];P=E/'remotion/public/battle'
P.mkdir(parents=True,exist_ok=True)
def link(src,dst):
 dst.parent.mkdir(parents=True,exist_ok=True)
 if dst.exists() and not os.path.samefile(src,dst):dst.unlink()
 if not dst.exists():os.link(src,dst)
assets={'sobaya.glb':ROOT/'04_GAME_ASSETS/3d/hazard_adopted/optimized_20260919/sobaya.glb','yametaro.glb':ROOT/'04_GAME_ASSETS/3d/characters/yametaro/rig_nose_v3/yametaro.glb','takosan.glb':ROOT/'04_GAME_ASSETS/3d/characters/takosan/rig_sheet_v2/takosan.glb','mug.glb':ROOT/'04_GAME_ASSETS/3d/props/beer_mug_v2/beer_mug.glb','yotan.glb':ROOT/'04_GAME_ASSETS/voxel/models/yotan.glb','fukuchan.glb':ROOT/'04_GAME_ASSETS/voxel/models/fukuchan.glb','dock.png':E/'remake_dock_20260919/scene_b.png','takosan.png':E/'character_takosan_giant_core_sheet.png'}
for n,p in assets.items():link(p,P/n)
for p in (E/'battle_assets').glob('*.png'):link(p,P/p.name)
rows=json.loads((E/'battle-dialogue.json').read_text())
for r in rows:
 p=E/f"battle_line{r['id']}_{r['speaker']}.wav"
 if not p.exists():raise FileNotFoundError(p)
 link(p,P/p.name)
 dur=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(p)]))
 n=math.ceil(dur*24);r.update(audio='battle/'+p.name,end=r['start']+n)
 pcm=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','s16le','-ac','1','-ar','24000','-']);a=array.array('h',pcm)
 r['mouth']=[round(min(.85,math.sqrt(sum((s/32768)**2 for s in a[i*1000:(i+1)*1000])/max(1,len(a[i*1000:(i+1)*1000])))*7),4) for i in range(n)]
 print(r['id'],r['start']/24,r['end']/24,r['text'])
for a,b in zip(rows,rows[1:]):assert a['end']<b['start'],(a,b)
shots=[
('opening','battle',0,5),('title','title',5,8),('dock','dock3d',8,13),('commander','comms',13,19),('refuse','dock3d',19,23),('order','comms',23,27),
('inside','cockpit',27,34),('how','cockpit',34,40),('clockin','cockpit',40,44),('ui-start','ui',44,47),('release','launch',47,50),('lift','cockpit',50,53),('land','battle',53,57),
('walk-command','battle',57,61),('walk-question','cockpit',61,64),('ui-wait','ui',64,67),('whip','battle',67,71),('slide','cockpit',71,74),('confirmed','comms',74,78),('approve','cockpit',78,82),('counter','battle',82,90),
('mug','battle',90,94),('beam','battle',94,98),('spill','battle',98,102),('anger','battle',102,107),('override','ui',107,109),('confused','cockpit',109,114),
('rush','battle',114,119),('dodge','battle',119,123),('shoulder','battle',123,127),('bind','battle',127,132),('struggle','battle',132,136),('passenger','cockpit',136,140),('pull','battle',140,145),('smash','battle',145,149),('impact','plate',149,151),('explosion','battle',151,155),('aftermath','battle',155,158),('silenced','comms',158,161),('exhausted','cockpit',161,165),('ui-report','ui',165,169),('lastline','cockpit',169,174),('ending','plate',174,180)
]
manifest={'composition':{'width':1280,'height':720,'fps':24,'durationInFrames':4320},'lines':rows,'shots':[{'id':i,'kind':k,'start':int(s*24),'end':int(e*24)} for i,k,s,e in shots]}
(E/'remotion/src/battle-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(E/'battle-assets.json').write_text(json.dumps({n:{'source':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for n,p in assets.items()},indent=2)+'\n')
# Sound design uses only speech-free sections of the already generated Wan 70 soundtrack.
for name,source,start,duration in [('rumble','wan3_result_seed700030_480p.mp4',0,.85),('beam','wan3_result_seed700030_480p.mp4',1.05,1.3),('impact','wan3_result_seed700030_480p.mp4',2.8,1.6),('dock','wan3_result_remake_v1_seed700030_480p.mp4',0,1.5)]:
 dst=E/('battle_fx_'+name+'.wav')
 if not dst.exists() and (P/(name+'.wav')).exists():dst.write_bytes((P/(name+'.wav')).read_bytes())
 if not dst.exists():subprocess.run(['ffmpeg','-y','-v','error','-ss',str(start),'-t',str(duration),'-i',str(E/source),'-vn','-af',f'afade=t=in:d=0.025,afade=t=out:st={duration-.09}:d=0.09','-ar','48000','-ac','2',str(dst)],check=True)

 link(dst,P/(name+'.wav'))
