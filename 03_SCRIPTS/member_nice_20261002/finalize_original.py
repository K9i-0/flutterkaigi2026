from pathlib import Path
import subprocess
base=Path(__file__).resolve().parent
source=Path('/Users/kotahayashi/Downloads/Michael_Rosen_Nice_Di1hgIQhiG0.mp4')
for name in ['sobaya','takosan']:
 p=base/name
 subprocess.run(['ffmpeg','-y','-v','error','-i',str(p/f'{name}_nice_wan3_480p.mp4'),'-i',str(source),'-map','0:v:0','-map','1:a:0','-c:v','copy','-af','apad=whole_dur=3','-c:a','aac','-b:a','192k','-t','3','-movflags','+faststart',str(p/f'{name}_nice_original_audio_480p.mp4')],check=True)
