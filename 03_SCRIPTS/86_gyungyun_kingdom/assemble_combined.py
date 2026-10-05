"""Frame-accurate assembly of existing repaired sources, no paid generation."""
from pathlib import Path
import json,subprocess,hashlib
EP=Path(__file__).resolve().parent
plan=json.loads((EP/'combined_edit.json').read_text())
for version in plan['versions']:
    args=['ffmpeg','-v','error','-n'];filters=[]
    for i,c in enumerate(version['clips']):
        args+=['-i',str(EP/c['input'])]
        lo,hi=c['start_frame'],c['end_frame']
        filters += [f'[{i}:v]trim=start_frame={lo}:end_frame={hi},setpts=PTS-STARTPTS,setsar=1[v{i}]',f'[{i}:a]aresample=44100,atrim=start_sample={lo*1470}:end_sample={hi*1470},asetpts=PTS-STARTPTS[a{i}]']
    filters.append(''.join(f'[v{i}][a{i}]' for i in range(len(version['clips'])))+'concat=n=3:v=1:a=1[v][a]')
    out=EP/version['output']
    subprocess.run(args+['-filter_complex',';'.join(filters),'-map','[v]','-map','[a]','-c:v','libx264','-crf','18','-preset','medium','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-movflags','+faststart',str(out)],check=True)
    subprocess.run(['ffmpeg','-v','error','-i',str(out),'-f','null','-'],check=True)
    probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=width,height,r_frame_rate,nb_frames,codec_type','-of','json',str(out)],text=True))
    expected=sum(c['end_frame']-c['start_frame'] for c in version['clips'])
    video=next(s for s in probe['streams'] if s['codec_type']=='video')
    assert int(video['nb_frames'])==expected
    assert (video['width'],video['height'],video['r_frame_rate'])==(1280,720,'30/1')
    version['verification']={'expected_frames':expected,'duration_seconds':expected/30,'probe':probe,'full_decode':'passed','sha256':hashlib.sha256(out.read_bytes()).hexdigest()}
    print(version['output'],expected/30,flush=True)
(EP/'combined_edit.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n')
