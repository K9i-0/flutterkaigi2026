from pathlib import Path
import subprocess,numpy as np,wave,json,hashlib
r=Path(__file__).resolve().parents[4];d=r/'03_SCRIPTS/82_last_train_police_taxi';s=r/'03_SCRIPTS/71_hisoba_memory_review/wan3_hisoba_seed710920_480p.mp4'
raw=subprocess.check_output(['ffmpeg','-v','error','-ss','22.22','-t','1.75','-i',str(s),'-af','highpass=f=380,lowpass=f=2400','-f','f32le','-ac','1','-ar','48000','-'])
a=np.frombuffer(raw,dtype='<f4').copy();a/=max(abs(a));a*=0.85
# Source-derived rise and reversed fall produce a continuous repeatable wail, no synthesis.
a=np.concatenate([a,a[::-1]])
n=2880;a[:n]*=np.linspace(0,1,n);a[-n:]*=np.linspace(1,0,n)
p=d/'remotion/public/police_siren_wan71.wav'
with wave.open(str(p),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(48000);w.writeframes((a*32767).astype('<i2').tobytes())
(d/'remotion/siren-source.json').write_text(json.dumps({'source':str(s.relative_to(r)),'source_sha256':hashlib.sha256(s.read_bytes()).hexdigest(),'source_start_seconds':22.22,'source_end_seconds':23.97,'audio_origin':'existing Wan 3.0 output, episode 71','processing':'380–2400 Hz bandpass; peak 0.85; original rise + reversed fall; 60ms edge fades; no synthesized audio','output':str(p.relative_to(d/'remotion')),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()},ensure_ascii=False,indent=2)+'\n')
