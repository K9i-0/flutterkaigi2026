"""Validate final game audio against canonical manifests (standard library)."""
from pathlib import Path
from array import array
import argparse,hashlib,json,math,sys,wave
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'04_GAME_ASSETS/audio/hazard'
parser=argparse.ArgumentParser()
parser.add_argument('--report',type=Path,default=ROOT/'21_SOBAYA_HAZARD_LAB/qa/voice-assets-20260906.json')
args=parser.parse_args()
manifest=json.loads((OUT/'voice-manifest.json').read_text())
lines=json.loads((OUT/'voice-lines.json').read_text())
assert {(c['speaker'],c['text']) for c in manifest['clips']}=={(c['speaker'],c['text']) for c in lines}
checks=[]
for clip in manifest['clips']:
    file=OUT/'voice'/Path(clip['asset']).name
    link=ROOT/'21_SOBAYA_HAZARD_LAB/assets'/clip['asset']
    assert link.resolve()==file.resolve()
    with wave.open(str(file)) as f:
        assert f.getnchannels()==1 and f.getsampwidth()==2 and f.getframerate()==24000
        duration=f.getnframes()/f.getframerate()
        values=array('h',f.readframes(f.getnframes()))
    if sys.byteorder=='big':values.byteswap()
    rms=math.sqrt(sum(x*x for x in values)/len(values))/32768
    peak=max(abs(x) for x in values)/32768
    assert abs(duration-clip['seconds'])<1/24000
    assert .015<rms<.7 and peak<.999 and duration>.25
    digest=hashlib.sha256(file.read_bytes()).hexdigest()
    if 'sha256' in clip:assert digest==clip['sha256']
    checks.append({'id':clip['id'],'speaker':clip['speaker'],'duration':duration,'peak':peak,'rms':rms,'sha256':digest})
for row in json.loads((OUT/'soundscape-manifest.json').read_text())['files']:
    assert hashlib.sha256((OUT/row['file']).read_bytes()).hexdigest()==row['sha256']
result={'cues':len(checks),'speech':sum(c['kind']=='speech' for c in manifest['clips']),
 'nonverbal':sum(c['kind']=='nonverbal' for c in manifest['clips']),
 'checks':checks,'note':'File integrity, waveform range and duration checks only; not perceptual audio approval.'}
p=args.report
p.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('PASS',len(checks),'cues')
