"""Assemble the approved chase, cut costume morph, preserve approved opening PCM."""
from pathlib import Path
import subprocess,json,sys
p=Path(__file__).resolve().parent
m=json.loads((p/'remotion/src/edit-manifest.json').read_text());e=m['videoEdit'];v=p/e['intro']['source'];c=p/e['chase']['source'];out=p/'remotion/public'
if not (out/'final_audio_v2.wav').exists():
 subprocess.run([sys.executable,str(p/'finish_audio.py'),'--manifest','remotion/src/edit-manifest_v2.json','--music-start-frame','801'],check=True)
# Integer frame cuts; retime only explosion footage. Crop baked-in chase bars.
fg='[0:v]trim=start_frame=0:end_frame=330,setpts=PTS-STARTPTS[a];[1:v]crop=854:394:0:42,scale=1040:480,crop=854:480,setsar=1,split[x][y];[x]trim=start_frame=0:end_frame=255,setpts=PTS-STARTPTS[b];[y]trim=start_frame=255:end_frame=338,setpts=(PTS-STARTPTS)*165/83,fps=30,tpad=stop_mode=clone:stop_duration=0.1,trim=end_frame=165[d];[0:v]trim=start_frame=750:end_frame=900,setpts=PTS-STARTPTS[z];[a][b][d][z]concat=n=4:v=1:a=0[o]'
subprocess.run(['ffmpeg','-y','-v','error','-i',str(v),'-i',str(c),'-filter_complex',fg,'-map','[o]','-an','-c:v','libx264','-crf','16','-pix_fmt','yuv420p',str(out/'input_v3.mp4')],check=True)
# Keep speech at native speed; extend only explosion audio to match the slow shot.
fg='[0:a]atrim=0:11,asetpts=PTS-STARTPTS[a];[1:a]aresample=48000,aformat=channel_layouts=stereo,asplit=3[x][y][z];[x]atrim=0:8.5,asetpts=PTS-STARTPTS[b];[y]atrim=8.5:10.8,asetpts=PTS-STARTPTS,atempo=0.5348837209,apad,atrim=duration=4.3[d];[z]atrim=10.8:12,asetpts=PTS-STARTPTS,apad,atrim=duration=1.2,afade=t=out:st=1.18:d=0.02[f];[0:a]atrim=25:33,asetpts=PTS-STARTPTS,afade=t=in:d=0.01[g];[a][b][d][f][g]concat=n=5:v=0:a=1,apad,atrim=duration=33[o]'
subprocess.run(['ffmpeg','-y','-v','error','-i',str(out/'final_audio_v2.wav'),'-i',str(c),'-filter_complex',fg,'-map','[o]','-ar','48000','-ac','2','-c:a','pcm_s16le',str(out/'final_audio_v3.wav')],check=True)
