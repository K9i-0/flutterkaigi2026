"""Reproduce local ep72 voice-edit candidates; run with the Large runtime Python.

Generation: tools/irodori_speak.sh, seed 42, no caption, auto duration, defaults.
Set IRODORI_TTS_CHECKPOINT explicitly for Large; use the extracted reference.wav.
Candidate generation is separate so existing takes are never silently replaced.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
EP = Path(__file__).resolve().parent
WORK = ROOT / '.local/ep72_okayaman_large_patch'
ORIGINAL = ROOT / '03_SCRIPTS/00_REPLY_CLIPS/72_おかやまん_おかやまん大変驚いております.mp4'

def run(*args):
    subprocess.run([str(x) for x in args], check=True)

def prepare():
    WORK.mkdir(parents=True, exist_ok=True)
    run('ffmpeg', '-v', 'error', '-y', '-i', ORIGINAL, '-t', '4.7', '-ar', '48000', '-c:a', 'pcm_s16le', WORK/'original.wav')
    run('ffmpeg', '-v', 'error', '-y', '-i', WORK/'original.wav', '-ss', '.24', '-t', '2.5', '-ac', '1', WORK/'reference.wav')

def package():
    config = json.loads((EP/'okayaman_patch_segments.json').read_text())
    original, rate = sf.read(WORK/'original.wav')
    original_rms = np.sqrt(np.mean(original[round(1.45*rate):round(2.59*rate)]**2))
    records = []
    public = EP/'remotion/public'
    public.mkdir(exist_ok=True)
    import shutil
    shutil.copyfile(ORIGINAL, public/'okayaman_original.mp4')
    import sys
    for name, item in config.items():
        if len(sys.argv) > 2 and name not in sys.argv[2:]:
            continue
        wav = WORK/f'{name}.wav'
        audio, sr = sf.read(wav)
        a, b = item['voiced']
        rms = np.sqrt(np.mean(audio[round(a*sr):round(b*sr)]**2))
        gain = round(float(20*np.log10(original_rms/rms)), 6)
        stereo = WORK/f'{name}_stereo.wav'
        run('ffmpeg', '-v', 'error', '-y', '-i', wav, '-af', 'apad=pad_dur=1', '-ar', '48000', '-ac', '2', '-c:a', 'pcm_s16le', stereo)
        patched = WORK/f'{name}_leveled.wav'
        run('python3', ROOT/'.claude/skills/wan-video/scripts/patch_pcm_audio.py', WORK/'original.wav', stereo, patched,
            '--target-start', item['target'], '--source-start', item['source'], '--duration', item['duration'], '--gain-db', gain)
        out = WORK/f'{name}.mp4'
        run('ffmpeg', '-v', 'error', '-y', '-i', ORIGINAL, '-i', patched, '-map', '0:v:0', '-map', '1:a:0', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '320k', '-t', '4.7', '-movflags', '+faststart', out)
        shutil.copyfile(out, public/f'okayaman_{name}.mp4')
        records.append({'name': name, 'gain_db': gain, **item, 'generated_sha256': hashlib.sha256(wav.read_bytes()).hexdigest(), 'video_sha256': hashlib.sha256(out.read_bytes()).hexdigest()})
    manifest = {'reference_source': 'generated_video', 'reference_start_in_reply': .24, 'reference_duration': 2.5,
        'reply_source_start_in_scene': 3.3, 'reference_sha256': hashlib.sha256((WORK/'reference.wav').read_bytes()).hexdigest(),
        'source_sha256': hashlib.sha256(ORIGINAL.read_bytes()).hexdigest(), 'seed': 42, 'caption': None,
        'duration_scale': 1, 'text_cfg': 3, 'time_stretch': False, 'takes': records}
    (WORK/('manifest_'+sys.argv[2]+'.json' if len(sys.argv)>2 else 'manifest.json')).write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')

if __name__ == '__main__':
    import sys
    {'prepare': prepare, 'package': package}[sys.argv[1]]()
