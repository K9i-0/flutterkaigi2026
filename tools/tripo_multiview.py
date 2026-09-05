"""Recorded P2 multiview generation using already authorized local credits."""
import argparse, hashlib, json, mimetypes, uuid
from datetime import datetime, timezone
from pathlib import Path
from tripo_generate import api, save, status, download
from tripo_setup import SetupError


def submit(config_path):
    folder=config_path.parent;config=json.loads(config_path.read_text());views=config['images'];options=config['generation']
    if 'front' not in views or not 2<=len(views)<=4 or not set(views)<=set(['front','left','back','right']):raise SetupError('Need front and 1–3 other named views')
    if options['model']!='P2-20260801' or options.get('texture_quality')!='detailed':raise SetupError('Expected P2 detailed')
    marker=folder/'submission_started.json'
    if marker.exists() or (folder/'task.json').exists():raise SetupError('Already submitted: inspect status instead')
    images={v:(folder/p).resolve() for v,p in views.items()}
    for p in images.values():
        if not p.is_file() or p.stat().st_size>20*1024*1024:raise SetupError('Missing/oversized input')
    before=api('/account/balance')['data']
    if before['balance']<120:raise SetupError('Insufficient credits for documented estimate')
    inputs=[];hashes={}
    for view,p in images.items():
        digest=hashlib.sha256(p.read_bytes()).hexdigest();hashes[view]=digest;cache=folder/('upload_'+view+'.json')
        if cache.exists():
            result=json.loads(cache.read_text())
            if result['input_sha256']!=digest:raise SetupError('Input changed since upload')
        else:
            boundary='tripo-'+uuid.uuid4().hex
            body=(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{view}{p.suffix}"\r\nContent-Type: {mimetypes.guess_type(p.name)[0]}\r\n\r\n').encode()+p.read_bytes()+f'\r\n--{boundary}--\r\n'.encode()
            result=api('/files',body,f'multipart/form-data; boundary={boundary}');result['input_sha256']=digest;save(cache,result)
        inputs.append({view:result['data']['file_token']})
    with marker.open('x') as f:json.dump({'started_at':datetime.now(timezone.utc).isoformat(),'balance_before':before,'input_sha256':hashes},f)
    result=api('/generation/multiview-to-model',json.dumps(dict(options,inputs=inputs)).encode())
    save(folder/'task.json',{'task_id':result['data']['task_id'],'input_sha256':hashes,'balance_before':before,'model':options['model']})
    print(json.dumps({'task_id':result['data']['task_id'],'status':'submitted','views':list(views)}))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('command',choices=['submit','status','download']);parser.add_argument('config',type=Path);args=parser.parse_args();p=args.config.resolve()
    try:
        if args.command=='submit':submit(p)
        elif args.command=='status':status(p.parent)
        else:download(p.parent)
    except SetupError as e:raise SystemExit(str(e))
