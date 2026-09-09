"""Reproduce revised trailer audio; optional canonical Irodori Sobaya narration."""
import json,subprocess,sys
from pathlib import Path
p=Path(__file__).resolve().parents[1];voice='--voice' in sys.argv
suffix='voice-v3' if voice else 'v3'
m=json.loads((p/f'src/trailer-{suffix}-manifest.json').read_text());fps=m['fps'];filters=[];labels=[]
args=['ffmpeg','-v','error','-i',str(p/f'out/trailer_{suffix}_picture.mp4'),'-i',str(p/'public/completed_cm.mp4')]
if voice:
 for name in m['voiceFiles']:args+=['-i',str(p.parent/name)]
for i,s in enumerate(m['segments']):
 d=s['duration']/fps
 if s['kind']=='video':
  start=s['sourceStart']/fps
  filters.append(f'[1:a]atrim=start={start}:duration={d},asetpts=PTS-STARTPTS,aresample=48000,aformat=channel_layouts=stereo,afade=t=in:d=0.012,afade=t=out:st={d-.015}:d=0.015[a{i}]')
 else:
  label=f'fx{i}' if voice else f'a{i}'
  filters.append(f'[1:a]atrim=start=5.2:duration=3,asetpts=PTS-STARTPTS,aresample=48000,asetrate=36000,aresample=48000,aformat=channel_layouts=stereo,lowpass=f=150,highpass=f=30,volume={0.65 if voice else 2.5},apad,atrim=duration={d},afade=t=in:d=0.02,afade=t=out:st={d-.55}:d=0.55[{label}]')
  if voice:
   n=s['voiceIndex']+2
   filters.append(f'[{n}:a]aresample=48000,aformat=channel_layouts=stereo,loudnorm=I=-17:TP=-2:LRA=8,aresample=48000,adelay=400|400,apad,atrim=duration={d}[v{i}]')
   filters.append(f'[fx{i}][v{i}]amix=inputs=2:normalize=0[a{i}]')
 labels.append(f'[a{i}]')
filters.append(''.join(labels)+f'concat=n={len(labels)}:v=0:a=1,alimiter=limit=0.89:level=false:latency=true[out]')
args+=['-filter_complex',';'.join(filters),'-map','0:v:0','-map','[out]','-c:v','copy','-c:a','aac','-b:a','192k','-movflags','+faststart',str(p.parent/f'final_remotion_trailer_{suffix}.mp4'),'-y']
subprocess.run(args,check=True)
