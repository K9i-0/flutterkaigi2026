"""Frame-accurate source-audio edit and existing-sound design, no TTS/API."""
import json,subprocess
from pathlib import Path
p=Path(__file__).resolve().parents[1];m=json.loads((p/'src/trailer-manifest.json').read_text());fps=m['fps'];filters=[];labels=[]
for i,s in enumerate(m['segments']):
 d=s['duration']/fps
 if s['kind']=='video':
  start=s['sourceStart']/fps
  filters.append(f'[1:a]atrim=start={start}:duration={d},asetpts=PTS-STARTPTS,aresample=48000,afade=t=in:d=0.012,afade=t=out:st={d-.015}:d=0.015[a{i}]')
 else:
  start=m['audio']['sourceEffectStartFrame']/fps
  filters.append(f'[1:a]atrim=start={start}:duration=3,asetpts=PTS-STARTPTS,aresample=48000,asetrate=36000,aresample=48000,lowpass=f=150,highpass=f=30,volume=2.5,apad,atrim=duration={d},afade=t=in:d=0.02,afade=t=out:st={d-.55}:d=0.55[a{i}]')
 labels.append(f'[a{i}]')
filters.append(''.join(labels)+f'concat=n={len(labels)}:v=0:a=1,alimiter=limit=0.89:level=false:latency=true[out]')
subprocess.run(['ffmpeg','-v','error','-i',str(p/'out/trailer_picture.mp4'),'-i',str(p/'public/completed_cm.mp4'),'-filter_complex',';'.join(filters),'-map','0:v:0','-map','[out]','-c:v','copy','-c:a','aac','-b:a','192k','-movflags','+faststart',str(p.parent/'final_remotion_trailer.mp4'),'-y'],check=True)
