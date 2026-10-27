"""Run with: uv run --with pillow python audit.py"""
import json, subprocess
from pathlib import Path
from PIL import Image, ImageDraw
root=Path(__file__).resolve().parent
m=json.loads((root/'src/edit-manifest.json').read_text());fps=m['composition']['fps'];end=m['composition']['durationInFrames'];previous=0;rows=[]
for i,s in enumerate(m['shots']):
 assert s['startFrame']==previous and s['startFrame']<s['endFrame']<=end
 previous=s['endFrame'];duration=s['endFrame']-s['startFrame'];source=root/'public'/s['file']
 probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(source)]))
 assert (s['trimFrame']+duration)/fps<=float(probe['format']['duration'])+1/fps, f'Source too short: {source}'
 row=Image.new('RGB',(960,177),'#10202b')
 for j,offset in enumerate([0,duration//2,duration-1]):
  frame=root/'out'/f'source-{i}-{j}.png'
  subprocess.run(['ffmpeg','-y','-v','error','-ss',str((s['trimFrame']+offset)/fps),'-i',str(source),'-frames:v','1','-vf','scale=320:-1',str(frame)],check=True)
  row.paste(Image.open(frame),(j*320,25))
 ImageDraw.Draw(row).text((5,5),f'{i}: {source.name} / source {s["trimFrame"]/fps:.1f}s',fill='white');rows.append(row)
assert previous==end
previous=0
for c in m['captions']:
 assert previous<=c['startFrame']<c['endFrame']<=end
 previous=c['endFrame']
audio=root/'public'/m['audio']['file']
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(audio)]))
assert m['audio']['startFrame']+float(probe['format']['duration'])*fps<=end
sheet=Image.new('RGB',(960,177*len(rows)))
for i,row in enumerate(rows):sheet.paste(row,(0,177*i))
sheet.save(root/'out/source-audit.jpg')
print('Timeline and source coverage passed; visually review out/source-audit.jpg.')
