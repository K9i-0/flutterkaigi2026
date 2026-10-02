"""Decode final output and export every edit/caption boundary for visual QA."""
import json,subprocess,sys,hashlib
from pathlib import Path
root=Path(__file__).resolve().parent;manifest=json.loads((root/'src/edit-manifest.json').read_text());vertical='--vertical' in sys.argv;config=manifest['verticalComposition' if vertical else 'composition'];movie=root.parent/('final_remotion_trailer_9x16.mp4' if vertical else 'final_remotion_trailer.mp4');out=root/('out/audit-vertical' if vertical else 'out/audit');out.mkdir(parents=True,exist_ok=True)
info=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','format=duration:stream=codec_name,width,height,r_frame_rate,nb_read_frames,sample_rate','-of','json',str(movie)]))
v=next(x for x in info['streams'] if x['codec_name']=='h264');assert int(v['nb_read_frames'])==config['durationInFrames'];assert (v['width'],v['height'])==(config['width'],config['height'])
subprocess.run(['ffmpeg','-v','error','-i',str(movie),'-f','null','-'],check=True)
frames={0,1019,45,200,370,520,700,900}
for row in manifest['shots']+manifest['captions']:
 for edge in [row['startFrame'],row['endFrame']]:frames.update(f for f in [edge-1,edge,edge+1] if 0<=f<1020)
# One sequential decode; save boundary strips at review resolution.
expr='+'.join(f'eq(n,{f})' for f in sorted(frames))
subprocess.run(['ffmpeg','-v','error','-i',str(movie),'-vf',f"select='{expr}',scale={'360:640' if vertical else '640:360'}",'-fps_mode','vfr','-y',str(out/'boundary-%03d.png')],check=True)
for f in [45,200,370,520,700,900]:
 subprocess.run(['ffmpeg','-v','error','-ss',str(f/30),'-i',str(movie),'-frames:v','1','-y',str(out/f'hero-{f}.png')],check=True)
(root.parent/('video-audit-vertical.json' if vertical else 'video-audit.json')).write_text(json.dumps({'sha256':hashlib.sha256(movie.read_bytes()).hexdigest(),'probe':info,'decodedToEnd':True,'boundaryFrames':sorted(frames),'audioListening':'Not available in this execution environment'},indent=2)+'\n')
print('Video fully decoded; frame count correct; boundary stills exported.')
