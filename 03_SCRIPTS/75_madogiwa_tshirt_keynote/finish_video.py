from pathlib import Path
import subprocess,json,hashlib,argparse
EP=Path(__file__).resolve().parent
parser=argparse.ArgumentParser();parser.add_argument('--variant',default='sobaya',choices=['sobaya','nojobs']);args=parser.parse_args();suffix='-nojobs' if args.variant=='nojobs' else '';prefix='nojobs' if suffix else 'keynote'
out=EP/f'final_remotion_{prefix}.mp4'
subprocess.run(['ffmpeg','-y','-v','error','-i',str(EP/f'remotion/out/{prefix}-master.mp4'),'-i',str(EP/f'remotion/public/audio/master{suffix}.wav'),'-map','0:v:0','-map','1:a:0','-c:v','copy','-af','volume=3dB','-c:a','aac','-b:a','192k','-movflags','+faststart',str(out)],check=True)
subprocess.run(['ffmpeg','-v','error','-i',str(out),'-f','null','-'],check=True)
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(out)]))
(EP/f'remotion/out/final-probe{suffix}.json').write_text(json.dumps(probe,indent=2)+'\n')
print(out,hashlib.sha256(out.read_bytes()).hexdigest())
