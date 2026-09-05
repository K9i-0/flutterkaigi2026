"""Submit the authorized Fukuchan task for a Mixamo-compatible biped rig."""
import json
from pathlib import Path
from tripo_generate import api,save
ROOT=Path(__file__).resolve().parent.parent
folder=ROOT/'04_GAME_ASSETS/3d/characters/fukuchan/rig_source';folder.mkdir(exist_ok=True)
if (folder/'submission_started.json').exists():raise SystemExit('Already submitted: inspect status')
source=json.loads((folder.parent/'tripo_p2_20260905/task.json').read_text())['task_id']
payload={'input':source,'model':'v1.0-20240301','rig_type':'biped','spec':'mixamo','out_format':'glb'}
(folder/'.gitignore').write_text('raw/\ntask*.json\nsubmission_started.json\n')
with (folder/'submission_started.json').open('x') as f:json.dump({'source_task':source,'operation':'animations/rig'},f)
result=api('/animations/rig',json.dumps(payload).encode());save(folder/'task.json',{'task_id':result['data']['task_id'],'source_task':source,'model':payload['model']});print(json.dumps({'task_id':result['data']['task_id'],'status':'submitted'}))
