"""Local-only full keynote Large auditions for the four remaining canonical voices.

Run with .local/Irodori-TTS-large/.venv/bin/python. Resumable; no casting adoption.
"""
from pathlib import Path
import dataclasses
import hashlib
import json
import subprocess
import sys
import time
import wave

EP = Path(__file__).resolve().parent
ROOT = EP.parents[1]
OUT = ROOT / '.local/irodori-large-ep75/cast-keynotes'
TTS = ROOT / '.local/Irodori-TTS-large'
MODEL = 'Aratako/Irodori-TTS-v4-Large'
REVISION = '2e0c55428ce97268a507f1feeb2478f8d9148e8b'
CAST = {
    'fukuchan': ('福ちゃん', 'Fukuchan_voice.wav', 100, '3b597fdb0c6c7e103a1998345f56565652b86b6344127b3d5d52e0a1fd5b9f35'),
    'yotan': ('よーたん', 'Yotan_voice.wav', 100, '9bd48c5577f5c70c7ed1ff7d684cca3f98ed23f24e89a02eee20907b47c1ec0c'),
    'okayaman': ('窓際王おかやまん', 'Okayaman_voice.wav', 42, '6939d8da2ce43a33ad672610fb9843481220b37010a968d76a98a0cbaf1ee357'),
    'yumetele': ('ゆめテレアナウンサー', 'YumeTeleAnchor_voice.wav', 2026, 'e3cd210adad43fb3338684555e7e066f83cfad2400265c8a73fa55b9f96b753f'),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, data):
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    temp.replace(path)


def assemble(speaker, rows, records):
    """Preserve the keynote's pauses at 24fps, without changing speech speed."""
    folder = OUT / speaker
    joined = folder / 'joined.wav'
    timeline = []
    with wave.open(str(joined), 'wb') as dest:
        dest.setparams((1, 2, 48000, 0, 'NONE', 'not compressed'))
        cursor = 0
        for row in rows:
            source = folder / f"{row['id']}.wav"
            pcm = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(source), '-f', 's16le', '-ac', '1', '-ar', '48000', '-'])
            samples = len(pcm) // 2
            timeline.append({'id': row['id'], 'text': row['text'], 'start': cursor / 48000, 'end': (cursor + samples) / 48000})
            dest.writeframes(pcm)
            pause = row['pauseFrames'] * 2000
            dest.writeframes(b'\0\0' * pause)
            cursor += samples + pause
    final = OUT / f'keynote_{speaker}_large.wav'
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(joined), '-af', 'loudnorm=I=-16:TP=-1.5:LRA=11', '-ar', '48000', '-ac', '1', '-c:a', 'pcm_s16le', str(final)], check=True)
    subprocess.run(['ffmpeg', '-v', 'error', '-i', str(final), '-f', 'null', '-'], check=True)
    with wave.open(str(final)) as audio:
        seconds = audio.getnframes() / audio.getframerate()
    write_json(OUT / f'keynote_{speaker}_large.json', {'speaker': speaker, 'name': CAST[speaker][0], 'model': MODEL, 'lines': len(rows), 'seconds': seconds, 'sha256': sha(final), 'timeline': timeline, 'auditoryReview': '未確認・ユーザー試聴用', 'adopted': False})
    print('FULL_READY', speaker, f'{seconds:.3f}s', str(final), flush=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rows = json.loads((EP / 'remotion/src/dialogue.json').read_text())
    for name, ref, seed, expected in CAST.values():
        assert sha(ROOT / '02_CHARACTERS' / ref) == expected, name
    sys.path.insert(0, str(TTS))
    import torch
    from huggingface_hub import snapshot_download
    from irodori_tts.inference_runtime import InferenceRuntime, RuntimeKey, SamplingRequest, save_wav
    snapshot = Path(snapshot_download(MODEL, revision=REVISION, local_files_only=True))
    commit = subprocess.check_output(['git', '-C', str(TTS), 'rev-parse', 'HEAD'], text=True).strip()
    record = OUT / 'generation.json'
    records = json.loads(record.read_text()) if record.exists() else {}
    runtime = None
    for speaker, (name, reference, seed, expected) in CAST.items():
        folder = OUT / speaker
        folder.mkdir(exist_ok=True)
        for row in rows:
            # The same product-presentation direction for all voices; no news-role change.
            request = SamplingRequest(text=row['speechText'], caption=row['caption'], ref_wav=str(ROOT / '02_CHARACTERS' / reference), seed=seed, duration_scale=1.0, cfg_scale_text=3.0, trim_tail=True)
            identity = {'request': dataclasses.asdict(request), 'referenceSha256': expected, 'model': MODEL, 'modelRevision': REVISION, 'runtimeCommit': commit, 'precision': 'fp32', 'postprocess': 'wrapper silence trim only'}
            fingerprint = hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()
            key = speaker + '/' + row['id']
            final = folder / f"{row['id']}.wav"
            prior = records.get(key, {})
            if prior.get('fingerprint') == fingerprint and final.exists() and sha(final) == prior['sha256']:
                print('CACHED', key, flush=True)
                continue
            if runtime is None:
                print('LOAD', MODEL, flush=True)
                runtime = InferenceRuntime.from_key(RuntimeKey(checkpoint=str(snapshot / 'model.safetensors'), model_device='mps', codec_device='mps', model_precision='fp32', codec_precision='fp32'))
            print('GENERATE', key, row['speechText'], flush=True)
            started = time.monotonic()
            result = runtime.synthesize(request, log_fn=lambda msg: None)
            raw = folder / f"{row['id']}_raw.wav"
            save_wav(raw, result.audio, result.sample_rate)
            subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(raw), '-af', 'silenceremove=start_periods=1:start_threshold=-40dB:start_silence=0.1,areverse,silenceremove=start_periods=1:start_threshold=-40dB:start_silence=0.2,areverse', str(final)], check=True)
            with wave.open(str(final)) as audio:
                duration = audio.getnframes() / audio.getframerate()
            assert duration > 0.1, key
            records[key] = {'speaker': speaker, 'id': row['id'], 'text': row['text'], 'speechText': row['speechText'], 'fingerprint': fingerprint, 'identity': identity, 'sha256': sha(final), 'duration': duration, 'synthesisSeconds': time.monotonic() - started, 'auditoryReview': '未確認', 'adopted': False}
            write_json(record, records)
            print('DONE', key, len(records), '/128', f'{duration:.2f}s', flush=True)
        assemble(speaker, rows, records)
    print('COMPLETE', flush=True)


if __name__ == '__main__':
    main()
