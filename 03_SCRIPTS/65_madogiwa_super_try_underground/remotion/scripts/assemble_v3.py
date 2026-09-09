"""Reproduce v3 assembly without overwriting any v1/v2 asset."""
import argparse
import os
from pathlib import Path
import subprocess

r = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--mux-final', action='store_true')
args = p.parse_args()
part1 = r / 'wan3_part1_v3_480p.mp4'
part2 = r / 'wan3_part2_v3_480p.mp4'
audio = '[1:a]atrim=duration=15,asetpts=PTS-STARTPTS,aformat=sample_rates=48000:channel_layouts=stereo[a0];[2:a]atrim=duration=30,asetpts=PTS-STARTPTS,aformat=sample_rates=48000:channel_layouts=stereo[a1];[a0][a1]concat=n=2:v=0:a=1[a]'
if args.mux_final:
    subprocess.run(['ffmpeg','-v','error','-i',str(r/'remotion/out/visual_v3.mp4'),'-i',str(part1),'-i',str(part2),'-filter_complex',audio,'-map','0:v','-map','[a]','-c:v','copy','-c:a','aac','-b:a','192k','-t','45','-movflags','+faststart','-y',str(r/'final_remotion_cm_v3.mp4')],check=True)
else:
    output = r/'joined_wan_v3_480p.mp4'
    graph = '[0:v]trim=duration=15,setpts=PTS-STARTPTS[v0];[0:a]atrim=duration=15,asetpts=PTS-STARTPTS,aformat=sample_rates=48000:channel_layouts=stereo[a0];[1:v]trim=duration=30,setpts=PTS-STARTPTS[v1];[1:a]atrim=duration=30,asetpts=PTS-STARTPTS,aformat=sample_rates=48000:channel_layouts=stereo[a1];[v0][a0][v1][a1]concat=n=2:v=1:a=1[v][a]'
    subprocess.run(['ffmpeg','-v','error','-i',str(part1),'-i',str(part2),'-filter_complex',graph,'-map','[v]','-map','[a]','-c:v','libx264','-crf','16','-preset','fast','-c:a','aac','-b:a','192k','-movflags','+faststart','-y',str(output)],check=True)
    target = r/'remotion/public/input_v3.mp4'
    if target.exists():
        target.unlink()
    os.link(output,target)
