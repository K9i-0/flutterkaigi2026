"""Three original SFX-only alternatives; common event timing and loudness target."""
import json, math, random, wave, struct, subprocess
from pathlib import Path
R=Path(__file__).resolve().parents[1]
M=json.loads((R/'src/edit-manifest.json').read_text())
SR=48000; N=SR*8; FPS=M['composition']['fps']; OUT=R/'out/audio_candidates'; OUT.mkdir(parents=True,exist_ok=True)
TA=M['events']['alert']/FPS; TI=M['events']['identified']/FPS
names=['A_deep_pressure','B_critical_alarm','C_unknown_presence']
for mode,name in enumerate(names):
    rng=random.Random(6400+mode); a=[0.0]*N
    def layer(start,dur,hz,gain,end=None,rough=0,mod=0):
        lo=round(start*SR); length=round(dur*SR)
        for j in range(min(length,N-lo)):
            t=j/SR; u=j/max(1,length-1)
            env=min(1,t/.025)*min(1,(dur-t)/.14)
            ph=2*math.pi*(hz*t+((end if end is not None else hz)-hz)*t*t/(2*dur))
            v=math.sin(ph+mod*math.sin(2*math.pi*29*t))
            v+=rough*(.5*math.sin(ph*1.49)+.3*math.sin(ph*2.03))
            a[lo+j]+=gain*env*v
    # Restrained pre-detection unease.
    layer(0,TI+.1,48 if mode==0 else 67,.025,rough=.4)
    if mode==0:
        layer(TA,TI-TA,43,.16,37,rough=.7)
        layer(TA,TI-TA,87,.055,79,rough=.4)
        for frame in M['audio']['pulses']:
            t=frame/FPS
            layer(t,.56,155,.3,48,rough=.9,mod=.2)
            layer(t+.12,.32,194,.085,105,rough=.6)
    elif mode==1:
        layer(TA,TI-TA,98,.07,122,rough=.6)
        for frame in M['audio']['pulses']:
            t=frame/FPS
            layer(t,.22,610,.17,430,rough=.7,mod=.8)
            layer(t+.24,.24,455,.17,320,rough=.7,mod=.7)
            layer(t,.4,74,.12,52)
    else:
        layer(TA,TI-TA,191,.10,267,rough=.65,mod=.5)
        layer(TA,TI-TA,196,.10,272,rough=.65,mod=.45)
        layer(TA,TI-TA,39,.13,52,rough=.3)
        for frame in M['audio']['pulses']:
            t=frame/FPS
            layer(t,.5,710,.09,230,rough=.8,mod=1.8)
    # Unsettling lock confirmation rather than a cheerful success jingle.
    layer(TI,.38,240,.10,120,rough=.25)
    layer(TI+.12,.55,61,.11,43)
    # Short asymmetric echoes give depth without a giant exterior-space reverb.
    stereo=[]
    for i,v in enumerate(a):
        fade=min(1,i/1440,(N-1-i)/4800)
        l=v+(a[i-3312]*.19 if i>=3312 else 0)
        r=v+(a[i-4656]*.19 if i>=4656 else 0)
        stereo.extend((l*fade,r*fade))
    peak=max(map(abs,stereo)); scale=.70/max(peak,.70)
    raw=OUT/(name+'_raw.wav')
    with wave.open(str(raw),'wb') as w:
        w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h',round(v*scale*32767)) for v in stereo))
    # Two-pass EBU normalization; equal integrated level for a fair comparison.
    cmd=['ffmpeg','-hide_banner','-i',str(raw),'-af','loudnorm=I=-20:TP=-3:LRA=9:print_format=json','-f','null','-']
    p=subprocess.run(cmd,capture_output=True,text=True,check=True)
    stats=json.JSONDecoder().raw_decode(p.stderr[p.stderr.rfind('{'):])[0]
    filt='loudnorm=I=-20:TP=-3:LRA=9:linear=true:'+':'.join(f'{k}={stats[v]}' for k,v in [('measured_I','input_i'),('measured_TP','input_tp'),('measured_LRA','input_lra'),('measured_thresh','input_thresh'),('offset','target_offset')])
    final=OUT/(name+'.wav')
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(raw),'-af',filt,'-ar',str(SR),'-c:a','pcm_s16le',str(final)],check=True)
    raw.unlink()
    (OUT/(name+'_analysis.json')).write_text(json.dumps(stats,indent=2)+'\n')
    print(final.name)
