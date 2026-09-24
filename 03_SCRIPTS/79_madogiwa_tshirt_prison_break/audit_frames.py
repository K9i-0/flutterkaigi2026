"""Extract labeled, unmodified frames for visual review; no generated-image editing."""
from pathlib import Path
import argparse, json, subprocess
from PIL import Image, ImageDraw
EP=Path(__file__).resolve().parent
parser=argparse.ArgumentParser();parser.add_argument('--final',action='store_true');args=parser.parse_args()
m=json.loads((EP/'remotion/src/edit-manifest.json').read_text())
source=EP/('final_remotion_prison_break_v2.mp4' if args.final else json.loads((EP/'wan3_config.json').read_text())['output'])
out=EP/'remotion/out'/('final-v2-audit' if args.final else 'raw-v2-audit');out.mkdir(parents=True,exist_ok=True)
times=list(range(33 if args.final else 30))
if args.final:
 times=sorted(set(times+[c[k]/m['composition']['fps'] for c in m['captions'] for k in ('startFrame','endFrame')]))
frames=[]
for sec in times:
 path=out/f'{sec:06.2f}.png'
 subprocess.run(['ffmpeg','-y','-v','error','-ss',str(sec),'-i',str(source),'-frames:v','1',str(path)],check=True)
 im=Image.open(path).convert('RGB');im.thumbnail((427,240));frames.append((sec,im.copy()))
for page in range((len(frames)+14)//15):
 group=frames[page*15:page*15+15];sheet=Image.new('RGB',(427*3,266*5),'#202020');draw=ImageDraw.Draw(sheet)
 for i,(sec,im) in enumerate(group):
  x=(i%3)*427;y=(i//3)*266;sheet.paste(im,(x,y));draw.text((x+8,y+242),f'{sec:.2f} s',fill='white')
 path=out/f'contact-{page+1}.jpg';sheet.save(path,quality=90);print(path)
