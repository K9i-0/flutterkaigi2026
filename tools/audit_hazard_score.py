"""Validate composed loops and Foley hashes, seams and PCM headroom."""
from pathlib import Path
import hashlib,json,wave
import numpy as np
ROOT=Path(__file__).resolve().parent.parent;OUT=ROOT/'04_GAME_ASSETS/audio/hazard'
score=json.loads((OUT/'score-manifest.json').read_text());grunts=json.loads((OUT/'combat/grunts-manifest.json').read_text());rows=[]
for row in score['files']+grunts['clips']:
 p=OUT/row['file'];assert hashlib.sha256(p.read_bytes()).hexdigest()==row['sha256']
 link=ROOT/'21_SOBAYA_HAZARD_LAB/assets/audio'/row['file'];assert link.resolve()==p.resolve()
 with wave.open(str(p)) as f:
  assert f.getsampwidth()==2
  sr=f.getframerate();channels=f.getnchannels();x=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').reshape(-1,channels).astype(float)/32768
 assert abs(len(x)/sr-row['seconds'])<1/sr
 assert np.isfinite(x).all() and np.max(np.abs(x))<.95
 result={'file':row['file'],'seconds':len(x)/sr,'channels':channels,'sample_rate':sr,'peak':float(np.max(np.abs(x))),'rms':float(np.sqrt(np.mean(x*x)))}
 if row.get('loop'):
  seam=float(np.max(np.abs(x[0]-x[-1])));typical=float(np.quantile(np.abs(np.diff(x,axis=0)),.995))
  assert channels==2 and len(x)/sr==48
  assert seam<max(.005,typical*2), (row['file'],seam,typical)
  result.update(seam=seam,sample_difference_p995=typical)
 rows.append(result)
report={'checks':rows,'music':score['music'],'note':'PCM/hash/seam checks; not perceptual approval or a device performance test.'}
(ROOT/'21_SOBAYA_HAZARD_LAB/qa/score-assets-20260906.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('PASS',len(rows),'audio files')
