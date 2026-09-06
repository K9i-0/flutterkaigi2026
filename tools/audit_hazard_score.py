"""Validate composed loops and Foley hashes, seams and PCM headroom."""
from pathlib import Path
import argparse,hashlib,json,wave,subprocess
import numpy as np
ROOT=Path(__file__).resolve().parent.parent;OUT=ROOT/'04_GAME_ASSETS/audio/hazard'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,default=ROOT/'21_SOBAYA_HAZARD_LAB/qa/score-assets-20260906.json')
args=parser.parse_args()
score=json.loads((OUT/'score-manifest.json').read_text());grunts=json.loads((OUT/'combat/grunts-manifest.json').read_text());rows=[]
rockets=json.loads((OUT/'rocket-audio-manifest.json').read_text())
for row in score['files']+grunts['clips']+rockets['files']:
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
 if row.get('loop') or row in rockets['files']:
  log=subprocess.run(['ffmpeg','-hide_banner','-i',str(p),'-af','loudnorm=I=-20:TP=-2:LRA=15:print_format=json','-f','null','-'],capture_output=True,text=True,check=True).stderr
  met=json.JSONDecoder().raw_decode(log[log.rindex('{'):])[0]
  assert float(met['input_tp']) < -1, (row['file'],met)
  result.update(integrated_lufs=float(met['input_i']),true_peak_dbtp=float(met['input_tp']))
  if not row.get('loop'):
   assert np.max(np.abs(x[0]))<.0001 and np.max(np.abs(x[-1]))<.0001
 rows.append(result)
report={'checks':rows,'music':score['music'],'note':'PCM/hash/seam checks; not perceptual approval or a device performance test.'}
args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('PASS',len(rows),'audio files')
