"""Render the modern take with canonical masked Sobaya speech; no paid calls.
Requires separated ambience prepared by Demucs htdemucs (--shifts 0).
"""
from pathlib import Path
import subprocess,json
EP=Path(__file__).resolve().parent
ROOT=EP.parent.parent
source=EP/'wan3_modern_seed861201_480p.mp4'
amb=ROOT/'.local/gyungyun86-modern-audit/separated/htdemucs/sobaya_window/no_vocals.wav'
out=EP/'modern_sobaya_irodori_preview_720p.mp4'
if not amb.exists():
    import os
    work=ROOT/'.local/gyungyun86-modern-audit'
    work.mkdir(parents=True,exist_ok=True)
    window=work/'sobaya_window.wav'
    subprocess.run(['ffmpeg','-v','error','-y','-ss','8.266666667','-t','3.5','-i',str(source),str(window)],check=True)
    subprocess.run([str(ROOT/'.local/Irodori-TTS/.venv/bin/python'),'-m','demucs','--two-stems=vocals','-n','htdemucs','--shifts','0','-d','cpu','-o',str(work/'separated'),str(window)],check=True,env={**os.environ,'OMP_NUM_THREADS':'4'})
# Source cut 248/30 to 353/30. Speech begins at frame 264, ends before corridor.
filters=';'.join([
 '[0:v]scale=1280:720:flags=lanczos,setsar=1[v]',
 '[0:a]atrim=end=8.266666667,asetpts=PTS-STARTPTS[a0]',
 '[1:a]atrim=duration=3.5,asetpts=PTS-STARTPTS,aresample=44100,apad=whole_dur=3.5[amb]',
 '[2:a]aresample=44100,adelay=533.333333:all=1,apad=whole_dur=3.5[line]',
 '[amb][line]amix=inputs=2:normalize=0:duration=first[a1]',
 '[0:a]atrim=start=11.766666667:end=14,asetpts=PTS-STARTPTS[a2]',
 '[a0][a1][a2]concat=n=3:v=0:a=1[a]'
])
subprocess.run(['ffmpeg','-v','error','-n','-i',str(source),'-i',str(amb),'-i',str(EP/'sobaya_modern_dream_irodori.wav'),'-filter_complex',filters,'-map','[v]','-map','[a]','-c:v','libx264','-crf','18','-preset','medium','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-t','14','-movflags','+faststart',str(out)],check=True)
subprocess.run(['ffmpeg','-v','error','-i',str(out),'-f','null','-'],check=True)
print(out)
