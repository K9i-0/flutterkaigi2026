"""Arrange existing renders for QA; no texture edits."""
from pathlib import Path
import subprocess
P=Path(__file__).resolve().parent
for view in ['front','oblique']:
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(P.parent/'front_fidelity_20260917'/('candidate_'+view+'.png')),'-i',str(P/'qa'/('candidate_'+view+'.png')),'-filter_complex','hstack=inputs=2','-frames:v','1',str(P/('comparison_'+view+'.png'))],check=True)
subprocess.run(['ffmpeg','-v','error','-y','-i',str(P.parent/'wan_multiview_20260917/inputs/front.png'),'-i',str(P/'qa/candidate_front.png'),'-filter_complex','[0:v]crop=180:180:324:20,scale=900:900:flags=lanczos[ref];[ref][1:v]hstack=inputs=2','-frames:v','1',str(P/'comparison_reference.png')],check=True)
