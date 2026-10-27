"""Normalize standard simctl captures to native-size 60fps without speeding up.

simctl writes a display rotation matrix; ffmpeg autorotation handles it.
Never apply the explicit transpose used for the earlier AXe recordings.
"""
from pathlib import Path
import subprocess,json
root=Path(__file__).resolve().parent
m=json.loads((root/'src/edit-manifest.json').read_text())
for name in sorted({s['file'] for s in m['shots']}):
 target=root/'public'/name;source=target.with_suffix('.mov')
 if target.exists():continue
 temporary=target.with_suffix('.partial.mp4')
 # Static title produces one frame in simctl; explicitly hold it for the ending.
 vf='tpad=stop_mode=clone:stop_duration=8,fps=60' if name=='title-v4.mp4' else 'fps=60'
 subprocess.run(['ffmpeg','-y','-v','error','-i',str(source),'-vf',vf,'-an','-c:v','libx264','-threads','2','-preset','fast','-crf','16','-pix_fmt','yuv420p','-movflags','+faststart',str(temporary)],check=True)
 temporary.replace(target)
