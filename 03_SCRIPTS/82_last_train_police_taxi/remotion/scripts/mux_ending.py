from pathlib import Path
import json,subprocess
p=Path(__file__).resolve().parents[1]
e=json.loads((p/'src/ending-edit.json').read_text()); fps=e['composition']['fps']
subprocess.run(['ffmpeg','-y','-v','error','-i',str(p/'out/ending_picture.mp4'),'-i',str(p/'public'/e['inputVideo']),'-map','0:v:0','-map','1:a:0','-c:v','copy','-af',f"afade=t=out:st={e['audioFadeStartFrame']/fps}:d={(e['audioEndFrame']-e['audioFadeStartFrame'])/fps}",'-c:a','aac','-b:a','192k','-t',str(e['composition']['durationInFrames']/fps),'-movflags','+faststart',str(p.parent/'final_remotion_exterior_punchline.mp4')],check=True)
