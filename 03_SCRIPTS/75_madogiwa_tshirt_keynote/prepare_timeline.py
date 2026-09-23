from pathlib import Path
import json,subprocess,math
EP=Path(__file__).resolve().parent
rows=json.loads((EP/'remotion/src/dialogue.json').read_text());cursor=58
lines=[]
for row in rows:
 p=EP/f"line_{row['id']}_sobaya.wav"
 duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(p)])) if p.exists() else max(1.0,len(row['text'])/6)
 frames=math.ceil(duration*24)
 lines.append({**row,'start':cursor,'end':cursor+frames,'audio':p.name})
 cursor+=frames+row['pauseFrames']
manifest={'fps':24,'width':1280,'height':720,'durationInFrames':cursor+24,'endcardStart':lines[-1]['end']+50,'audioReady':(EP/'remotion/public/audio/master.wav').exists(),'lines':lines}
(EP/'remotion/src/edit-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('Timeline',cursor+24,'frames',round((cursor+24)/24,2),'seconds')
