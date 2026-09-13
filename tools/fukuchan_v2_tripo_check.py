"""Free, recorded rig check for the v2 body. Never sends a paid job."""
import json
from pathlib import Path
from tripo_generate import api, save

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / '04_GAME_ASSETS/3d/characters/fukuchan/v2_20260913/body'
target = FOLDER / 'rig_check.json'
if target.exists():
    result = json.loads(target.read_text())
else:
    source = json.loads((FOLDER / 'task.json').read_text())['task_id']
    result = api('/animations/rig-check', json.dumps({'input': source}).encode())
    save(target, result)
if result['data'].get('task_id'):
    result = api('/tasks/' + result['data']['task_id'])
    save(FOLDER / 'rig_check_result.json', result)
data = result['data']
print(json.dumps({k: data[k] for k in ('task_id', 'status', 'output', 'riggable', 'rig_type', 'credits_consumed') if k in data}))
