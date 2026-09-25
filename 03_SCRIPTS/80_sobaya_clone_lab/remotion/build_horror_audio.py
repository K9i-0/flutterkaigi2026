"""Rebuild the word repair and mix only adopted voice/Wan sound sources."""
import hashlib,json,subprocess,wave
from pathlib import Path
import numpy as np
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
M=json.loads((HERE/'src/horror-edit.json').read_text())
OUT=HERE/'out';OUT.mkdir(exist_ok=True)
RATE=48000

def decode(path,filters=None):
    args=['ffmpeg','-v','error','-i',str(path)]
    if filters:args+=['-af',filters]
    args+=['-ar',str(RATE),'-ac','2','-f','s16le','-']
    return np.frombuffer(subprocess.check_output(args),dtype='<i2').reshape(-1,2).copy()

def write(path,data):
    with wave.open(str(path),'wb') as w:
        w.setparams((2,2,RATE,0,'NONE','not compressed'));w.writeframes(data.astype('<i2').tobytes())

def samples(frame):return round(frame*RATE/M['fps'])
original=decode(ROOT/M['originalVideo'])[:samples(M['titleStartFrame'])]
patched=original.copy()
voice=M.get('takosanVoiceA')
if voice:
    a=samples(voice['replaceStartFrame']);b=samples(voice['replaceEndFrame'])
    bed_start=voice['ambienceSourceStartFrame']/M['fps'];bed_duration=voice['ambienceSourceDurationFrames']/M['fps']
    bed=decode(ROOT/M['originalVideo'],f"atrim=start={bed_start}:duration={bed_duration},asetpts=PTS-STARTPTS,lowpass=f=1800,volume={voice['ambienceGainDb']}dB").astype(float)
    # Overlap only the nonverbal Wan ambience, never speech phonemes.
    overlap=round(.05*RATE);joined=bed.copy();ramp=np.linspace(0,1,overlap)[:,None]
    while len(joined)<b-a:
        joined[-overlap:]=joined[-overlap:]*(1-ramp)+bed[:overlap]*ramp
        joined=np.concatenate([joined,bed[overlap:]])
    region=joined[:b-a]
    for line in voice['lines']:
        clip=decode(ROOT/line['asset']).astype(float)*10**(line['gainDb']/20)
        start=samples(line['startFrame'])-a
        assert start>=0 and start+len(clip)<=len(region), 'Voice exceeds replacement window'
        region[start:start+len(clip)]+=clip
    assert np.max(np.abs(region))<32768
    patched[a:b]=np.rint(region).astype('<i2')
    patch_matches=True
else:
    r=M['repair'];replacement=decode(ROOT/r['asset'])
    a=r['targetStartSample'];b=a+r['durationSamples'];c=r['sourceStartSample'];d=c+r['durationSamples']
    patch=np.rint(replacement[c:d].astype(float)*10**(r['gainDb']/20))
    assert np.max(np.abs(patch))<32768
    patched[a:b]=patch.astype('<i2')
    patch_matches=np.array_equal(patched[a:b],patch.astype('<i2'))
assert np.array_equal(patched[:a],original[:a]) and np.array_equal(patched[b:],original[b:])
write(OUT/'horror-dialogue-only.wav',patched)
base=np.zeros((samples(M['durationFrames']),2),dtype=float);base[:len(patched)]=patched/32768
q=M['quietBeforeBreak'];start,end=samples(q['startFrame']),samples(q['endFrame']);ramp=samples(q['rampFrames']);gain=10**(q['gainDb']/20)
envelope=np.full(end-start,gain);envelope[:ramp]=np.linspace(1,gain,ramp);envelope[-ramp:]=np.linspace(gain,1,ramp);base[start:end]*=envelope[:,None]
fx=np.zeros_like(base)
for e in M['effects']:
    startsec=e['sourceStartFrame']/M['fps'];duration=e['sourceDurationFrames']/M['fps']
    filters=f"atrim=start={startsec}:duration={duration},asetpts=PTS-STARTPTS,lowpass=f={e['lowpassHz']},afade=t=in:d=0.006,afade=t=out:st={max(0,duration-0.09)}:d=0.09,volume={e['gainDb']}dB"
    clip=decode(ROOT/M['originalVideo'],filters)/32768
    start=samples(e['startFrame']);fx[start:start+len(clip)]+=clip
call=M['titleCall'];clip=decode(ROOT/call['asset'])/32768*10**(call['gainDb']/20);start=samples(call['startFrame']);base[start:start+len(clip)]+=clip
fxgain=1.0
while np.max(np.abs(base+fx*fxgain))>0.985 and fxgain>0.01:fxgain*=0.9
mix=base+fx*fxgain
assert np.max(np.abs(mix))<1, 'Clipping: revise gains'
write(OUT/'horror-mix.wav',np.rint(mix*32767))
report={'sampleRate':RATE,'channels':2,'durationSamples':len(mix),'seconds':len(mix)/RATE,'replacementOutsidePcmIdentical':True,'replacementMode':'adopted_takosan_voice_a' if voice else 'word_repair','insertVerified':patch_matches,'targetSamples':[a,b],'timeStretch':False,'speechCrossfade':False,'peakDbfs':float(20*np.log10(np.max(np.abs(mix)))),'extraSfxGain':fxgain,'audioSources':'Wan original effects; Irodori member speech only','review':'ASR and PCM checks; listening and lip-sync approval remain separate'}
(OUT/'horror-audio-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False))
