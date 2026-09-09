"""Mix original Wan speech and selected B directly to preserve source timing."""
import json,subprocess
from pathlib import Path
r=Path(__file__).resolve().parents[1];m=json.loads((r/'src/production-manifest.json').read_text());fps=m['composition']['fps']
parts=['[2:a]asplit=3[b0][b1][b2]','[1:a]aresample=48000,asetpts=PTS-STARTPTS[wan]']
for i,s in enumerate(m['audioSegments']):
 dur=s['duration']/fps;start=s['startFrom']/fps;delay=round(s['from']/fps*48000)
 parts.append(f'[b{i}]atrim=start={start}:duration={dur},asetpts=PTS-STARTPTS,afade=t=in:d=0.016667,afade=t=out:st={dur-.05}:d=0.05,volume=0.8,adelay={delay}S:all=1[a{i}]')
parts.append('[wan][a0][a1][a2]amix=inputs=4:duration=first:normalize=0,alimiter=limit=0.891251:level=false:latency=true,apad,atrim=duration=30[out]')
subprocess.run(['ffmpeg','-v','error','-y','-i',str(r/'out/production_picture.mp4'),'-i',str(r/'public'/m['inputVideo']),'-i',str(r/'public'/m['alertAudio']),'-filter_complex',';'.join(parts),'-map','0:v:0','-map','[out]','-c:v','copy','-c:a','aac','-b:a','192k','-ar','48000','-movflags','+faststart',str(r.parent/'final_remotion_cm.mp4')],check=True)
