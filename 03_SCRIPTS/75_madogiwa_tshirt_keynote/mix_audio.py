from pathlib import Path
import json,subprocess,hashlib
import numpy as np
EP=Path(__file__).resolve().parent;SR=48000
mp=EP/'remotion/src/edit-manifest.json';m=json.loads(mp.read_text());N=round(m['durationInFrames']/24*SR)
master=np.zeros((N,2),np.float32);voice=np.zeros(N,np.float32)
def decode(path,filters='anull',channels=2):
 b=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-af',filters,'-ar',str(SR),'-ac',str(channels),'-f','f32le','-'])
 return np.frombuffer(b,dtype='<f4').reshape(-1,channels).copy()
def add(a,start,gain=1):
 n=min(len(a),N-start)
 if n>0:master[start:start+n]+=a[:n]*gain
for l in m['lines']:
 a=decode(EP/l['audio'],'loudnorm=I=-18:TP=-2:LRA=7')
 start=round(l['start']/24*SR);add(a,start)
 voice[start:start+min(len(a),N-start)]=1
ap=decode(EP/'audio_sources/applause_cc0.ogg','loudnorm=I=-20:TP=-3:LRA=7')
la=decode(EP/'audio_sources/laughter_ccby4.mp3','loudnorm=I=-23:TP=-3:LRA=7')
events=[]
def reaction(source,start,frames,offset=0,gain=1,kind='applause'):
 n=round(frames/24*SR);a=source[round(offset*SR):round(offset*SR)+n].copy()
 if len(a)<n:a=np.pad(a,((0,n-len(a)),(0,0)))
 fadein=min(int(.15*SR),n//4);fadeout=min(int(.65*SR),n//3)
 a[:fadein]*=np.linspace(0,1,fadein)[:,None];a[-fadeout:]*=np.linspace(1,0,fadeout)[:,None]
 pos=round(start/24*SR);mask=voice[pos:pos+n]
 a[:len(mask)]*= (1-.82*mask[:,None])
 add(a,pos,gain);events.append(dict(kind=kind,start=start,durationInFrames=frames,sourceOffsetSeconds=offset,gain=gain))
reaction(ap,0,57,0,.8)
ids=['three','first','second','third','understand','reveal','arms','wear','today','all']
for i,l in enumerate(m['lines']):
 if l['id'] in ids:
  reaction(ap,l['end']+3,l['pauseFrames']-1,(i*3)%38,1.2 if l['id'] in ['reveal','third'] else .8)
 if l['id'] in ['repeat2','nobody']:
  reaction(la,l['end']+2,50,0,1,kind='laughter')
# Maintain the dialogue's exact timing; only add a low theatre reflection.
echo=int(.075*SR);master[echo:]+=master[:-echo]*.045
peak=float(np.max(np.abs(master)))
if peak>.94:master*=.94/peak
out=EP/'remotion/public/audio';out.mkdir(exist_ok=True)
subprocess.run(['ffmpeg','-y','-v','error','-f','f32le','-ar',str(SR),'-ac','2','-i','-','-c:a','pcm_s16le',str(out/'master.wav')],input=master.astype('<f4').tobytes(),check=True)
m['audioReady']=True;m['soundEvents']=events;mp.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
(EP/'audio-mix.json').write_text(json.dumps({'sampleRate':SR,'channels':2,'peakBeforeLimiter':peak,'dialogueLUFS':-18,'applauseLUFS':-20,'laughterLUFS':-23,'duckingWhenSpeaking':.18,'echoDelaySeconds':.075,'echoGain':.045,'masterSha256':hashlib.sha256((out/'master.wav').read_bytes()).hexdigest(),'events':events},ensure_ascii=False,indent=2)+'\n')
print('Mixed',N/SR,'seconds; peak',peak)
