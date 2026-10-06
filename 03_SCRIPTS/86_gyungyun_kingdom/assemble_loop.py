"""Assemble a cyclic edit from one continuous hospital-exit/impact shot.
The manifest stores all cuts as integer frames, with exclusive end frames.
"""
from pathlib import Path
import hashlib,json,subprocess
EP=Path(__file__).resolve().parent
PLAN=EP/'loop_edit.json'
p=json.loads(PLAN.read_text())
fps=p['fps']; sr=48000
assert sr % fps == 0
spf=sr//fps
work=EP.parents[1]/'.local'/'gyungyun86-loop'
work.mkdir(parents=True,exist_ok=True)
args=['ffmpeg','-hide_banner','-loglevel','error','-n']; filters=[]; chunks=[]
for i,c in enumerate(p['clips']):
    source=EP/c['input']; lo=c['start_frame']; hi=c['end_frame']
    args+=['-i',str(source)]
    filters.append(f'[{i}:v]trim=start_frame={lo}:end_frame={hi},setpts=PTS-STARTPTS,scale=1280:720:flags=lanczos,setsar=1[v{i}]')
    pcm=subprocess.check_output(['ffmpeg','-v','error','-i',str(source),'-vn','-ar',str(sr),'-ac','2','-f','f32le','-'])
    segment=pcm[lo*spf*8:hi*spf*8]
    assert len(segment)==(hi-lo)*spf*8
    chunks.append(segment)
# Do not fade at the final-to-first boundary: both sides are contiguous source samples.
master=b''.join(chunks)
raw=work/'loop_master.f32'; raw.write_bytes(master)
args+=['-f','f32le','-ar',str(sr),'-ac','2','-i',str(raw)]
filters.append(''.join(f'[v{i}]' for i in range(len(p['clips'])))+f'concat=n={len(p["clips"])}:v=1:a=0[v]')
out=EP/p['output']
subprocess.run(args+['-filter_complex',';'.join(filters),'-map','[v]','-map',f'{len(p["clips"])}:a','-c:v','libx264','-preset','slow','-crf','16','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-movflags','+faststart',str(out)],check=True)
subprocess.run(['ffmpeg','-v','error','-i',str(out),'-f','null','-'],check=True)
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration,size:stream=codec_type,width,height,r_frame_rate,nb_frames','-of','json',str(out)],text=True))
frames=sum(c['end_frame']-c['start_frame'] for c in p['clips'])
v=next(s for s in probe['streams'] if s['codec_type']=='video')
assert int(v['nb_frames'])==frames
assert (v['width'],v['height'],v['r_frame_rate'])==(1280,720,'30/1')
# First/last clips must meet at adjacent frames of the same generated shot.
assert p['clips'][-1]['input']==p['clips'][0]['input']
assert p['clips'][-1]['end_frame']==p['clips'][0]['start_frame']
p['verification']={'frames':frames,'duration':frames/fps,'full_decode':'passed','loop_boundary':'adjacent source frames and PCM samples, no overlap/duplicate/fade','probe':probe,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}
PLAN.write_text(json.dumps(p,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(p['verification'],ensure_ascii=False,indent=2))
