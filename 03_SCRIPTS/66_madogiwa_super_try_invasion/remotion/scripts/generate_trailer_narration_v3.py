"""Regenerate only revised card 3; reuse accepted voices 1, 2, 4."""
from pathlib import Path
import json,subprocess,hashlib
r=Path(__file__).resolve().parents[4];p=r/'03_SCRIPTS/66_madogiwa_super_try_invasion';path=p/'trailer_voice_v3_manifest.json';m=json.loads(path.read_text());s=m['lines'][2];raw=p/'remotion/out/trailer_v3_3_raw.wav';out=p/s['file']
subprocess.run(['bash',str(r/'.claude/skills/seedance/scripts/irodori_speak.sh'),s['text'],str(raw),str(r/m['reference']),str(s['seed']),s['caption']],check=True)
subprocess.run(['bash',str(r/'.claude/skills/seedance/scripts/sobaya_monsterize.sh'),str(raw),str(out)],check=True)
s['duration']=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=nw=1:nk=1',str(out)]));s['sha256']=hashlib.sha256(out.read_bytes()).hexdigest();path.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
