"""Normalize the finished mix while copying the rendered video without re-encoding."""
from pathlib import Path
import subprocess,json
EP=Path(__file__).resolve().parent
src=EP/'remotion/out/documentary-master.mp4';dst=EP/'final_remotion_documentary.mp4'
subprocess.run(['ffmpeg','-y','-v','error','-i',str(src),'-map','0:v:0','-map','0:a:0','-c:v','copy','-af','loudnorm=I=-16:TP=-1.5:LRA=11','-c:a','aac','-b:a','192k','-ar','48000','-movflags','+faststart',str(dst)],check=True)
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_streams','-show_format','-of','json',str(dst)]))
(EP/'remotion/out/final-probe.json').write_text(json.dumps(probe,indent=2)+'\n')
m=json.loads((EP/'remotion/src/edit-manifest.json').read_text());v=next(x for x in probe['streams'] if x['codec_type']=='video')
assert int(v['nb_read_frames'])==m['composition']['durationInFrames']
assert (v['width'],v['height'])==(854,480)
subprocess.run(['ffmpeg','-v','error','-i',str(dst),'-f','null','-'],check=True)
print('Export complete:',dst,'frames',v['nb_read_frames'],'duration',v['duration'])
