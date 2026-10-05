"""Replace only hospital in the selected no-walk version; retain other pixels."""
from pathlib import Path
import subprocess,json,hashlib
P=Path(__file__).resolve().parent
base=P/'combined_no_walk_720p.mp4';patch=P/'wan3_hospital_patch_seed861301_480p.mp4';out=P/'combined_no_walk_hospital_fixed_720p.mp4'
f=';'.join([
'[0:v]trim=end_frame=802,setpts=PTS-STARTPTS[v0]',
'[0:a]aresample=44100,atrim=end_sample=1178940,asetpts=PTS-STARTPTS[a0]',
'[1:v]trim=end_frame=300,setpts=PTS-STARTPTS,scale=1280:720:flags=lanczos,setsar=1[v1]',
'[1:a]aresample=44100,atrim=end_sample=441000,asetpts=PTS-STARTPTS[a1raw]',
'[2:a]aresample=44100,adelay=7000:all=1,apad=whole_dur=10[line]',
'[a1raw][line]amix=inputs=2:duration=first:normalize=0[a1]',
'[0:v]trim=start_frame=1101:end_frame=1168,setpts=PTS-STARTPTS[v2]',
'[0:a]aresample=44100,atrim=start_sample=1618470:end_sample=1716960,asetpts=PTS-STARTPTS[a2]',
'[v0][a0][v1][a1][v2][a2]concat=n=3:v=1:a=1[v][a]'])
subprocess.run(['ffmpeg','-v','error','-n','-i',str(base),'-i',str(patch),'-i',str(P/'sobaya_modern_dream_irodori.wav'),'-filter_complex',f,'-map','[v]','-map','[a]','-c:v','libx264','-crf','0','-preset','medium','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-movflags','+faststart',str(out)],check=True)
subprocess.run(['ffmpeg','-v','error','-i',str(out),'-f','null','-'],check=True)
def framehash(path,start,end):
 return subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-vf',f'trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS','-an','-f','hash','-hash','sha256','-'],text=True).strip()
assert framehash(base,0,802)==framehash(out,0,802)
assert framehash(base,1101,1168)==framehash(out,1102,1169)
r={'task_id':'9e5cdd16-9fe9-463c-a506-b8d1d4fba69a','status':'SUCCEEDED','seed':861301,'generation_resolution':'480P','generated_seconds':10,'estimated_usd':0.35,'output':out.name,'fps':30,'frames':1169,'seconds':1169/30,'edit':{'base':base.name,'prefix_frames':[0,802],'hospital':patch.name,'hospital_frames':[0,300],'sobaya_voice':'sobaya_modern_dream_irodori.wav','sobaya_voice_start_patch_frame':210,'corridor_base_frames':[1101,1168]},'checks':{'full_decode':'passed','prefix_decoded_pixels_exactly_unchanged':True,'corridor_decoded_pixels_exactly_unchanged':True,'hospital_visual':'2fps sample review: only Sobaya, Fukuchan and Yametaro; no Yumemin; mask remains worn','patch_asr':'目が覚めたぎゅん!そば屋さん、大丈夫か?','auditory_review':'not performed; ASR not listening or exact lip-sync approval'},'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}
(P/'generation_hospital_patch.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print(json.dumps(r,ensure_ascii=False,indent=2))
