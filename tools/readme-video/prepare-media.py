"""Normalize simulator captures without changing their speed or cropping UI."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parent
for name in ['odatetsu','fukugyun','sobaya','gallery','characters']:
    source=root/'public'/f'{name}.mp4'
    if not source.exists():continue
    subprocess.run(['ffmpeg','-y','-v','error','-i',str(source),'-t','25','-vf','transpose=2,scale=1600:-2,fps=30','-an','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(root/'public'/f'{name}-landscape.mp4')],check=True)
