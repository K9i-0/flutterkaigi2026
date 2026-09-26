"""Non-destructive crop candidate; original generated audio is copied unchanged."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parent.parent
subprocess.run(['ffmpeg','-v','error','-y','-i',str(root/'wan3_pov_replacement_seed26092680_480p.mp4'),'-vf',"zoompan=z='1.08+0.253333*min(on/60,1)':x='30':y='0':d=1:s=854x480:fps=30",'-c:v','libx264','-crf','18','-preset','fast','-c:a','copy',str(root/'final_remotion_pov_cropped.mp4')],check=True)
