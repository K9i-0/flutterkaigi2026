"""Assemble only user-requested visual replacements, retaining corrected AAC audio.
Run from any directory with Python 3 and FFmpeg installed. No paid API calls.
"""
from pathlib import Path
import json,subprocess,hashlib
EP=Path(__file__).resolve().parent
PLAN=EP/'visual_patch_edit.json'
p=json.loads(PLAN.read_text());out=EP/p['output']
if out.exists():raise SystemExit(f'Refusing to overwrite {out}')
def probe(path):
 return json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=codec_name,width,height,r_frame_rate','-of','json',str(path)],text=True))
args=['ffmpeg','-v','error'];filters=[]
for i,clip in enumerate(p['clips']):
 source=EP/clip['input'];assert source.is_file()
 args+=['-i',str(source)]
 # Frame indices apply after 30fps normalization; exact 870-frame destination.
 filters.append(f'[{i}:v]fps=30,trim=start_frame={clip["source_start_frame"]}:end_frame={clip["source_end_frame"]},setpts=PTS-STARTPTS,scale=1280:720:flags=lanczos,setsar=1[v{i}]')
args+=['-i',str(EP/p['audio_input'])]
filters.append(''.join(f'[v{i}]' for i in range(len(p['clips'])))+f'concat=n={len(p["clips"])}:v=1:a=0[outv]')
args+=['-filter_complex',';'.join(filters),'-map','[outv]','-map',f'{len(p["clips"])}:a:0','-c:v','libx264','-crf','18','-preset','medium','-pix_fmt','yuv420p','-c:a','copy','-movflags','+faststart',str(out)]
subprocess.run(args,check=True)
# Hash decoded PCM, plus encoded AAC packets, proving no audio changes.
def ahash(path,codec):
 return subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-map','0:a:0','-c:a',codec,'-f','hash','-hash','sha256','-'],text=True).strip()
for codec in ['copy','pcm_s16le']:assert ahash(out,codec)==ahash(EP/p['audio_input'],codec),codec
frames=subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-count_frames','-show_entries','stream=nb_read_frames','-of','csv=p=0',str(out)],text=True).strip();assert int(frames)==870
subprocess.run(['ffmpeg','-v','error','-i',str(out),'-f','null','-'],check=True)
p['verification']={'frames':int(frames),'final_media':probe(out),'audio_aac_packet_hash_unchanged':True,'audio_decoded_pcm_hash_unchanged':True,'full_decode':'passed','output_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'video_scale':'one Lanczos upscale per original 480p segment; no scale-up from previously upscaled720p','visual_review':'pending'}
PLAN.write_text(json.dumps(p,ensure_ascii=False,indent=2)+'\n');print(json.dumps(p['verification'],ensure_ascii=False,indent=2))
