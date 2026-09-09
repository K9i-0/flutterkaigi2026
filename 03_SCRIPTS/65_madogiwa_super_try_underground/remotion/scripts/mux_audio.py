"""Mux original Wan audio at exact part boundary; no voice replacement."""
from pathlib import Path
import subprocess
r=Path(__file__).resolve().parents[2]
subprocess.run(['ffmpeg','-v','error','-i',str(r/'remotion/out/visual.mp4'),'-i',str(r/'wan3_part1_480p.mp4'),'-i',str(r/'wan3_part2_480p.mp4'),'-filter_complex','[1:a]atrim=duration=10,asetpts=PTS-STARTPTS,aformat=sample_rates=48000:channel_layouts=stereo[a0];[2:a]atrim=duration=30,asetpts=PTS-STARTPTS,aformat=sample_rates=48000:channel_layouts=stereo[a1];[a0][a1]concat=n=2:v=0:a=1[a]','-map','0:v','-map','[a]','-c:v','copy','-c:a','aac','-b:a','192k','-t','40','-movflags','+faststart','-y',str(r/'final_remotion_cm.mp4')],check=True)
