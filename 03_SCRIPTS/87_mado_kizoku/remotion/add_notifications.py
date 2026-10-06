"""Repeat Wan-generated notification audio; no synthesized/external sound."""
from pathlib import Path
import json,subprocess,wave,hashlib
import numpy as np
P=Path(__file__).resolve().parent.parent
SR=48000

def pcm(path):
 return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-ar',str(SR),'-ac','2','-f','f32le','-']),dtype='<f4').reshape(-1,2).copy()
def save(path,a):
 with wave.open(str(path),'wb') as w:
  w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR);w.writeframes(np.round(np.clip(a,-1,1)*32767).astype('<i2').tobytes())
mfile=P/'remotion/src/edit-manifest.json';m=json.loads(mfile.read_text())
# Entire transient with short margins from the actual Wan laptop notification.
source=pcm(P/'wan3_part2_480p.mp4');sound=source[round(22.40*SR):round(22.86*SR)].copy()
f=round(.008*SR);sound[:f]*=np.linspace(0,1,f)[:,None];sound[-f:]*=np.linspace(1,0,f)[:,None]
sound/=max(float(np.max(np.abs(sound))),1e-8)
base=pcm(P/'remotion/public/repaired_audio.wav')
base=np.pad(base,((0,max(0,m['composition']['durationInFrames']*1600-len(base))),(0,0)))
mixed=base.copy()
# Remove the original one-off ping before scheduling its repeated copies.
mixed[553*1600:577*1600]=0
entries=[]
for frame,peak in [(558,.25),(575,.21),(590,.12),(604,.12),(616,.12),(626,.12)]:
 start=frame*1600;mixed[start:start+len(sound)]+=sound*peak
 entries.append({'startFrame':frame,'peakAmplitude':peak})
assert len(mixed)==m['composition']['durationInFrames']*1600
assert np.max(np.abs(mixed))<1
save(P/'remotion/public/audio_notifications.wav',mixed)
m['replacementAudio']='audio_notifications.wav'
m['notificationBurst']={'source':'wan3_part2_480p.mp4','sourceStartSeconds':22.4,'sourceEndSeconds':22.86,'events':entries,'method':'reuse generated notification, fixed gain, 8ms edge fades; no new synthesis','speechStartFrame':580,'replaceOriginalPingFrames':[553,577]}
mfile.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
record={'output':'final_remotion_subtitles_part2_v3.mp4','sourceVideo':'final_remotion_subtitles_part2_v2.mp4','videoProcessing':'stream copy; same captions, frames, timing','notificationBurst':m['notificationBurst'],'peakAmplitude':float(np.max(np.abs(mixed))),'sampleCount':len(mixed),'duration':len(mixed)/SR,'speechOutsideBurstUnchanged':bool(np.array_equal(base[:553*1600],mixed[:553*1600])),'listening':'not available in this runtime'}
(P/'notification_edit_v3.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(record,ensure_ascii=False,indent=2))
