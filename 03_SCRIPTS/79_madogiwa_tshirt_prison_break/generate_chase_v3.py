"""Episode launcher using the currently documented Qwen Cloud endpoint.
Reuses the shared validated workflow; logs only task/status and non-secret metadata.
"""
import importlib.util
import json
from pathlib import Path
from datetime import datetime, timezone
import sys
EP = Path(__file__).resolve().parent
ROOT = EP.parents[1]
spec = importlib.util.spec_from_file_location('wan', ROOT / '.claude/skills/wan-video/scripts/qwen_wan3_generate.py')
wan = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wan)
wan.SUBMIT_URL = 'https://maas.qwencloudapi.com/api/v1/services/aigc/video-generation/video-synthesis'
wan.QUERY_URL = 'https://maas.qwencloudapi.com/api/v1/tasks/{task_id}'
record_path = EP / 'generation-record_chase_v3.json'
if '--submit' in sys.argv and record_path.exists():
    raise SystemExit('Existing task record found. Poll the existing task; do not resubmit.')
record = {'model':'wan3.0-video','generation_seconds':12,'final_seconds':33,'resolution':'480P','estimated_usd':0.42,'standard_usd':0.60,'endpoint':wan.SUBMIT_URL}
original = wan.api_json

def logged(url, api_key, **kwargs):
    result = original(url, api_key, **kwargs)
    out = result.get('output', {})
    if out.get('task_id'):
        record['task_id'] = out['task_id']
    if out.get('task_status'):
        record['status'] = out['task_status']
    if result.get('usage'):
        record['usage'] = result['usage']
    record['updated_at'] = datetime.now(timezone.utc).isoformat()
    if 'task_id' in record:
        record_path.write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n')
    return result
wan.api_json = logged
sys.argv = [sys.argv[0], str(EP/'wan3_chase_v3_config.json'), *sys.argv[1:]]
raise SystemExit(wan.main())
