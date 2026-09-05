"""Record one authorized Tripo biped rig job; preserve output and prevent repeats.
Usage: python3 tools/tripo_rig_character.py PATH/TO/generation/task.json PATH/TO/rig_source
"""
import argparse,json
from pathlib import Path
from tripo_generate import api,save
from tripo_setup import SetupError

def submit(source,folder):
    folder.mkdir(parents=True,exist_ok=True)
    marker=folder/'submission_started.json'
    if marker.exists() or (folder/'task.json').exists():raise SetupError('Already submitted; use tripo_generate.py status/download with this folder/config.json')
    task=json.loads(source.read_text())['task_id']
    balance=api('/account/balance')['data']
    if balance['balance']<25:raise SetupError('Insufficient existing credits')
    payload={'input':task,'model':'v1.0-20240301','rig_type':'biped','spec':'mixamo','out_format':'glb'}
    save(folder/'config.json',{'operation':'animations/rig','rig':payload})
    (folder/'.gitignore').write_text('raw/\ntask*.json\nsubmission_started.json\n')
    with marker.open('x') as f:json.dump({'source_task':task,'operation':'animations/rig','balance_before':balance},f)
    result=api('/animations/rig',json.dumps(payload).encode())
    save(folder/'task.json',{'task_id':result['data']['task_id'],'source_task':task,'model':payload['model']})
    print(json.dumps({'task_id':result['data']['task_id'],'status':'submitted'}))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('folder',type=Path);a=p.parse_args()
    try:submit(a.source,a.folder)
    except SetupError as e:raise SystemExit(str(e))
