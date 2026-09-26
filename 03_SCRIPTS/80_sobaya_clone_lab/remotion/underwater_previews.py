"""Underwater sound candidates using existing Wan dialogue and pod ambience only."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parent.parent
out=root/'remotion/out/underwater';out.mkdir(exist_ok=True)
def run(args):subprocess.run(['ffmpeg','-v','error','-y',*args],check=True)
for name,cutoff,depth,bedlevel in [('mild',2000,.05,-34),('strong',950,.14,-29)]:
    voice=out/f'{name}_voice.wav'
    run(['-i',str(root/'opening_dialogue_isolated.wav'),'-af',f'atrim=start=3:end=6,asetpts=PTS-STARTPTS,highpass=f=90,lowpass=f={cutoff}:p=2,tremolo=f=0.8:d={depth},loudnorm=I=-19:TP=-3:LRA=7,apad=whole_dur=4','-t','4','-ar','48000','-ac','2',str(voice)])
    bed=out/f'{name}_bed.wav'
    run(['-stream_loop','-1','-i',str(root/'pod_ambience_loop.wav'),'-af',f'atrim=duration=4,highpass=f=45,lowpass=f=1200,loudnorm=I={bedlevel}:TP=-9:LRA=7,afade=t=in:d=0.1,afade=t=out:st=3.8:d=0.2','-t','4','-ar','48000','-ac','2',str(bed)])
    wav=out/f'underwater_{name}.wav'
    run(['-i',str(voice),'-i',str(bed),'-filter_complex','[0:a][1:a]amix=inputs=2:normalize=0,alimiter=limit=0.89:level=0:latency=1[a]','-map','[a]','-c:a','pcm_s16le',str(wav)])
    run(['-i',str(root/'final_remotion_pov_face_smooth.mp4'),'-i',str(wav),'-map','0:v:0','-map','1:a:0','-c:v','copy','-c:a','aac','-b:a','192k','-t','4','-movflags','+faststart',str(out/f'underwater_{name}.mp4')])
print(out)
