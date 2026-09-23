from pathlib import Path
import subprocess,json,hashlib
EP=Path(__file__).resolve().parent
out=EP/'final_remotion_keynote.mp4'
subprocess.run(['ffmpeg','-y','-v','error','-i',str(EP/'remotion/out/keynote-master.mp4'),'-i',str(EP/'remotion/public/audio/master.wav'),'-map','0:v:0','-map','1:a:0','-c:v','copy','-af','volume=3dB','-c:a','aac','-b:a','192k','-movflags','+faststart',str(out)],check=True)
subprocess.run(['ffmpeg','-v','error','-i',str(out),'-f','null','-'],check=True)
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(out)]))
(EP/'remotion/out/final-probe.json').write_text(json.dumps(probe,indent=2)+'\n')
print(out,hashlib.sha256(out.read_bytes()).hexdigest())
