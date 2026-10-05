"""Adopt user-selected D without regenerating voice or modifying video."""
from pathlib import Path
import subprocess,json,hashlib
import numpy as np
P=Path(__file__).resolve().parent;R=P.parent.parent;W=R/'.local/gyungyun86-yametaro-final';W.mkdir(parents=True,exist_ok=True)
source=P/'combined_no_walk_hospital_fixed_720p.mp4';out=P/'final_gyungyun_kingdom_720p.mp4'
def pcm(path):
 return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ac','2','-ar','44100','-']),dtype='<f4').reshape(-1,2).copy()
original=pcm(source);mixed=original.copy()
amb=R/'.local/gyungyun86-yametaro-compare/separated/htdemucs/target/no_vocals.wav'
if not amb.exists():
 import os
 target=W/'target.wav'
 subprocess.run(['ffmpeg','-v','error','-y','-ss','4','-t','2.5','-i',str(P/'wan3_hospital_patch_seed861301_480p.mp4'),str(target)],check=True)
 subprocess.run([str(R/'.local/Irodori-TTS/.venv/bin/python'),'-m','demucs','--two-stems=vocals','-n','htdemucs','--shifts','0','-d','cpu','-o',str(W/'separated'),str(target)],check=True,env={**os.environ,'OMP_NUM_THREADS':'4'})
 amb=W/'separated/htdemucs/target/no_vocals.wav'
start=924*1470;end=997*1470
bg=pcm(amb)[2*1470:75*1470]
assert len(bg)==end-start
mixed[start:end]=bg
# Only silence margins removed; speech, internal pause, pitch and tempo unchanged.
voice=pcm(P/'yametaro_hospital_d.wav')[round(.8*44100):round(2.75*44100)]
position=round((802/30+4.12)*44100)
assert position>=start and position+len(voice)<=end
mixed[position:position+len(voice)]+=voice
assert np.array_equal(mixed[:start],original[:start]) and np.array_equal(mixed[end:],original[end:])
assert np.max(np.abs(mixed[start:end]))<1
wav=W/'final_mix.wav'
subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar','44100','-ac','2','-i','-','-c:a','pcm_f32le',str(wav)],input=mixed.astype('<f4').tobytes(),check=True)
subprocess.run(['ffmpeg','-v','error','-n','-i',str(source),'-i',str(wav),'-map','0:v:0','-map','1:a:0','-c:v','copy','-c:a','aac','-b:a','192k','-t',str(1169/30),'-movflags','+faststart',str(out)],check=True)
def vh(p):return subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-map','0:v:0','-c:v','copy','-f','hash','-hash','sha256','-'],text=True).strip()
assert vh(source)==vh(out)
subprocess.run(['ffmpeg','-v','error','-i',str(out),'-f','null','-'],check=True)
r={'status':'user_selected_D_completed','output':out.name,'source':source.name,'adopted_voice':'yametaro_hospital_d.wav','raw_voice':'yametaro_hospital_d_raw.wav','reference':'yametaro_hospital_d_reference_ep80.wav','model':'Aratako/Irodori-TTS-v4-Large','seed':7,'text':'そばやさん、だいじょうぶか？','cfg_text':5,'duration_scale':1,'uncut':True,'caption':'','reference_trimmed':False,'source_voice_slice_seconds':[.8,2.75],'voice_destination_sample':position,'replacement_samples':[start,end],'audio_sample_rate':44100,'processing':'Adopted D listen-copy loudnorm -18LUFS/-2dBTP; silence margins only removed, internal pause retained; no new TTS, pitch or time stretch','checks':{'video_encoded_packets_unchanged':True,'pcm_outside_replacement_exactly_unchanged':True,'peak':float(np.max(np.abs(mixed))),'full_decode':'passed','phoneme_lip_sync':'original visual performance retained; exact phoneme alignment not certified'},'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}
(P/'final_yametaro_d_edit.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print(json.dumps(r,ensure_ascii=False,indent=2))
