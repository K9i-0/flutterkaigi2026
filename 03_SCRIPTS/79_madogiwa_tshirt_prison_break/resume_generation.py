"""Poll an existing task and download the result; never submit a paid request."""
from pathlib import Path
import importlib.util,json,os,time
from datetime import datetime,timezone
from urllib.request import urlopen
EP=Path(__file__).resolve().parent;ROOT=EP.parents[1]
spec=importlib.util.spec_from_file_location('wan',ROOT/'.claude/skills/wan-video/scripts/qwen_wan3_generate.py');wan=importlib.util.module_from_spec(spec);spec.loader.exec_module(wan)
p=EP/'generation-record_v2.json';record=json.loads(p.read_text());task=record['task_id']
while True:
 result=wan.api_json('https://maas.qwencloudapi.com/api/v1/tasks/'+task,os.environ['DASHSCOPE_API_KEY'])
 out=result.get('output',{});status=out.get('task_status','UNKNOWN');print(status,flush=True)
 record.update(status=status,updated_at=datetime.now(timezone.utc).isoformat())
 if result.get('usage'):record['usage']=result['usage']
 p.write_text(json.dumps(record,indent=2)+'\n')
 if status=='SUCCEEDED':
  dest=EP/json.loads((EP/'wan3_config.json').read_text())['output']
  with urlopen(out['video_url'],timeout=180) as response:dest.write_bytes(response.read())
  print('Downloaded:',dest,flush=True);break
 if status in {'FAILED','CANCELED','UNKNOWN'}:raise SystemExit('Task '+status+' '+str(out.get('message','')))
 time.sleep(10)
