"""Progressive face close-up; preserve source audio and four-second duration."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parent.parent
# Ease from the establishing view into a safe face crop before the shoulder rises.
p="min(max((on-12)/60,0),1)"
e=f"({p}*{p}*(3-2*{p}))"
filters=f"zoompan=z='1.08+(854/352-1.08)*{e}':x='30+205*{e}':y='168*{e}':d=1:s=854x480:fps=30"
subprocess.run(['ffmpeg','-v','error','-y','-i',str(root/'wan3_pov_replacement_seed26092680_480p.mp4'),'-vf',filters,'-c:v','libx264','-crf','18','-preset','fast','-c:a','copy',str(root/'final_remotion_pov_face_zoom.mp4')],check=True)
