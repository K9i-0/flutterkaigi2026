from pathlib import Path
import subprocess,numpy as np,wave,json,hashlib
p=Path(__file__).resolve().parent
src=p/'public/bgm_divertissement.mp3'
a=np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(src),'-ar','48000','-ac','2','-f','f32le','-']),dtype='<f4').reshape(-1,2).copy()
# Quiet pizzicato with controlled peaks; stop precisely at first notification.
stop=985*1600;a=a[:stop];a=.075*np.tanh(a*5/.075)
a[:8*1600]*=np.linspace(0,1,8*1600)[:,None]
a[-3*1600:]*=np.linspace(1,0,3*1600)[:,None]
with wave.open(str(p/'public/bgm_mix.wav'),'wb') as w:
 w.setnchannels(2);w.setsampwidth(2);w.setframerate(48000);w.writeframes(np.round(a*32767).astype('<i2').tobytes())
(p.parent/'bgm_record.json').write_text(json.dumps({'title':'Divertissement - Pizzicato (from the ballet Sylvia)','artist':'Kevin MacLeod','source':'https://incompetech.com/music/royalty-free/mp3-royaltyfree/Divertissement.mp3','license':'CC BY 4.0','source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'stopFrame':985,'fadeInFrames':8,'fadeOutFrames':3,'processing':'gain 5, soft peak ceiling 0.075; stereo preserved','peak':float(np.abs(a).max()),'listening':'not available in runtime'},indent=2)+'\n')
