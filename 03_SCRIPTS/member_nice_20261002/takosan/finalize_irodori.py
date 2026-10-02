from pathlib import Path
import subprocess, array, math, hashlib, json
p=Path(__file__).resolve().parent
video=p/'takosan_nice_original_audio_480p.mp4'
voice=p/'clip1_line1_takosan_nice.wav'
def pcm(path,channels):
    data=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','s16le','-ac',str(channels),'-ar','48000','-'])
    a=array.array('h');a.frombytes(data);return a
original=pcm(video,2); line=pcm(voice,1); master=array.array('h',original)
start,end,insert=51840,109440,56640 # 1.08, 2.28, 1.18 seconds at 48 kHz
# Clear the original spoken word only, retain opening mouth sound and other audio.
master[start*2:end*2]=array.array('h',[0])*((end-start)*2)
rms=lambda a:math.sqrt(sum(float(v)*v for v in a)/max(1,len(a)))
gain=rms(original[57600*2:86400*2])/max(1,rms(line))
gain=min(gain,30000/max(1,max(abs(v) for v in line)))
for i,v in enumerate(line):
    j=(insert+i)*2
    if j>=end*2: raise RuntimeError('Voice exceeds replacement window')
    master[j]=master[j+1]=round(v*gain)
assert master[:start*2]==original[:start*2] and master[end*2:]==original[end*2:]
temp=p/'irodori_mix.pcm'
temp.write_bytes(master.tobytes())
output=p/'takosan_nice_irodori_480p.mp4'
subprocess.run(['ffmpeg','-y','-v','error','-i',str(video),'-f','s16le','-ar','48000','-ac','2','-i',str(temp),'-map','0:v:0','-map','1:a:0','-c:v','copy','-c:a','aac','-b:a','192k','-t','3','-movflags','+faststart',str(output)],check=True)
temp.unlink()
def video_hash(path):
    return subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-map','0:v:0','-c','copy','-f','hash','-hash','sha256','-']).decode().strip()
assert video_hash(video)==video_hash(output)
(p/'irodori_edit.json').write_text(json.dumps({'model':'Aratako/Irodori-TTS-v4-Large','reference':'takosan_a_reference.wav','seed':42,'postprocess':'none','text':'ナイス。','caption':None,'text_cfg':5,'duration_scale':1.0,'trim':True,'insertion_sample_48000':insert,'replacement_samples_48000':[start,end],'gain_db':20*math.log10(gain),'voice_sha256':hashlib.sha256(voice.read_bytes()).hexdigest(),'video_stream_identical':True,'outside_patch_pcm_identical':True,'asr':'ナイス','listening_and_exact_lip_sync':'not_verified'},ensure_ascii=False,indent=2)+'\n')
print(output)
