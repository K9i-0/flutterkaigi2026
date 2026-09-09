from pathlib import Path
import subprocess
p=Path(__file__).resolve().parents[2]
subprocess.run(['ffmpeg','-v','error','-i',str(p/'remotion/out/full_picture.mp4'),'-i',str(p/'wan3_part1_v3_480p.mp4'),'-i',str(p/'wan3_part2_v2_480p.mp4'),'-filter_complex','[1:a]atrim=0:20,asetpts=PTS-STARTPTS[a];[2:a]atrim=0:20,asetpts=PTS-STARTPTS[b];[a][b]concat=n=2:v=0:a=1[out]','-map','0:v:0','-map','[out]','-c:v','copy','-c:a','aac','-b:a','192k','-movflags','+faststart',str(p/'final_remotion_cm.mp4'),'-y'],check=True)
