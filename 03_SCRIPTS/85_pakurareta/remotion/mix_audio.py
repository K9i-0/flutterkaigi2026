"""Build the audio master from adopted inputs using edit-manifest frame anchors.
Requires FFmpeg and NumPy. python mix_audio.py --prepare-stems recreates local stems.
"""
from pathlib import Path
import json,subprocess,sys,hashlib
import numpy as np
HERE=Path(__file__).resolve().parent;EP=HERE.parent;ROOT=EP.parents[1];WORK=ROOT/'.local/ep85-edit';SR=48000
M=json.loads((HERE/'src/edit-manifest.json').read_text());FPS=M['composition']['fps'];N=round(M['composition']['durationInFrames']/FPS*SR)
def read(p):
 return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-ac','2','-ar',str(SR),'-']),dtype='<f4').reshape(-1,2).copy()
def write(p,x):
 subprocess.run(['ffmpeg','-y','-v','error','-f','f32le','-ac','2','-ar',str(SR),'-i','-','-c:a','pcm_s16le',str(p)],input=x.astype('<f4').tobytes(),check=True)
def sample(frame):return round(frame/FPS*SR)
WORK.mkdir(exist_ok=True,parents=True)
original=read(EP/'wan3_result_seed851002_480p.mp4')[:N]
if '--prepare-stems' in sys.argv:
 write(WORK/'original.wav',original)
 subprocess.run([str(ROOT/'.local/Irodori-TTS/.venv/bin/python'),'-m','demucs.separate','-n','htdemucs','--two-stems','vocals','--shifts','0','-d','cpu','-o',str(WORK/'separated'),str(WORK/'original.wav')],check=True)
bg=read(WORK/'separated/htdemucs/original/no_vocals.wav')[:N]
mix=original.copy();report={'voiceEdits':[]}
for edit in M['voiceEdits']:
 a,b=sample(edit['replaceStartFrame']),sample(edit['replaceEndFrame']);fade=np.ones((b-a,1));k=sample(1);fade[:k]=np.linspace(0,1,k)[:,None];fade[-k:]=np.linspace(1,0,k)[:,None]
 mix[a:b]=original[a:b]*(1-fade)+bg[a:b]*fade
 voice=read((HERE/edit['file']).resolve());gain=10**(edit['gainDb']/20)
 for segment in edit['segments']:
  lo,hi=sample(segment['sourceStartFrame']),sample(segment['sourceEndFrame']);at=sample(segment['targetStartFrame']);clip=(read((HERE/segment['file']).resolve()) if 'file' in segment else voice)[lo:hi]*gain*10**(segment.get('gainDb',0)/20)
  assert at>=a and at+len(clip)<=b
  mix[at:at+len(clip)]+=clip
 report['voiceEdits'].append({'name':edit['name'],'sha256':hashlib.sha256((HERE/edit['file']).resolve().read_bytes()).hexdigest(),'gainDb':edit['gainDb'],'timeStretch':False,'segments':edit['segments']})
voice_only=mix.copy()
# Existing recorded office effects; source and license are recorded in office_sound_source.json.
b=M['officeAmbience'];bed=read((HERE/b['source']).resolve());bed=bed[sample(b['sourceStartFrame']):sample(b['sourceEndFrame'])];length=sample(b['endFrame']-b['startFrame']);overlap=sample(b['crossfadeFrames']);loop=bed.copy()
while len(loop)<length:
 f=np.linspace(0,1,overlap)[:,None];loop=np.concatenate([loop[:-overlap],loop[-overlap:]*(1-f)+bed[:overlap]*f,bed[overlap:]])
loop=loop[:length]*10**(b['gainDb']/20);k=sample(b['fadeInFrames']);loop[:k]*=np.linspace(0,1,k)[:,None];k=sample(b['fadeOutFrames']);loop[-k:]*=np.linspace(1,0,k)[:,None]
start=sample(b['startFrame']);mix[start:start+length]+=loop
assert np.max(np.abs(mix))<1,'clipping'
mask=np.ones(N,dtype=bool);mask[start:start+length]=False
for edit in M['voiceEdits']: mask[sample(edit['replaceStartFrame']):sample(edit['replaceEndFrame'])]=False
assert np.array_equal(mix[mask],original[mask]),'unexpected change outside requested intervals'
write(HERE/'public/mixed.wav',mix)
report.update(peakDbfs=float(20*np.log10(np.max(np.abs(mix)))),officeBedRmsDbfs=float(20*np.log10(np.sqrt(np.mean(loop**2)))) ,unchangedOutsideEditIntervals=True,officeBedOrigin=b['origin'],directListening=False)
(HERE/'out').mkdir(exist_ok=True)
(HERE/'out/mix-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False,indent=2))
