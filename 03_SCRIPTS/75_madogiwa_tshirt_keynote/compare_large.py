"""Generate local-only Large candidates with the adopted Small settings.

Run with .local/Irodori-TTS/.venv/bin/python. Does not adopt or overwrite audio.
"""
from pathlib import Path
import argparse
import dataclasses
import hashlib
import json
import os
import resource
import shutil
import subprocess
import sys
import threading
import time

EP = Path(__file__).resolve().parent
ROOT = EP.parents[1]
TTS = Path(os.environ.get('IRODORI_LARGE_DIR', ROOT / '.local/Irodori-TTS-large'))
OUT = ROOT / '.local/irodori-large-ep75'
MODEL = 'Aratako/Irodori-TTS-v4-Large'
MODEL_REVISION = '2e0c55428ce97268a507f1feeb2478f8d9148e8b'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, value):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    tmp.replace(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ids', nargs='*', help='Optional subset for an initial smoke run')
    parser.add_argument('--speakers', nargs='+', default=['yametaro', 'sobaya'])
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    page = OUT / 'index.html'
    if not page.exists():
        page.symlink_to(os.path.relpath(EP / 'compare_large.html', OUT))
    sys.path.insert(0, str(TTS))
    import torch
    from huggingface_hub import snapshot_download
    from irodori_tts.inference_runtime import InferenceRuntime, RuntimeKey, SamplingRequest, save_wav

    snapshot = Path(snapshot_download(MODEL, revision=MODEL_REVISION, local_files_only=True))
    commit = subprocess.check_output(['git', '-C', str(TTS), 'rev-parse', 'HEAD'], text=True).strip()
    previous_run = json.loads((OUT / 'runtime.json').read_text()) if (OUT / 'runtime.json').exists() else {}
    run = {'model': MODEL, 'revision': snapshot.name, 'runtimeCommit': commit,
           'torch': torch.__version__, 'device': 'mps', 'precision': 'fp32',
           'memoryNote': 'MPS allocations sampled every 0.5s; process RSS high-water from getrusage. These overlap and must not be added.',
           'auditoryReview': '未確認（比較試聴用）', 'adopted': False}
    peak = {key: previous_run.get(key, 0) for key in ['mpsAllocatedBytes', 'mpsDriverBytes']}
    stop = threading.Event()

    def monitor():
        while not stop.is_set():
            peak['mpsAllocatedBytes'] = max(peak['mpsAllocatedBytes'], torch.mps.current_allocated_memory())
            peak['mpsDriverBytes'] = max(peak['mpsDriverBytes'], torch.mps.driver_allocated_memory())
            stop.wait(0.5)

    threading.Thread(target=monitor, daemon=True).start()
    print('LOAD', MODEL, flush=True)
    start = time.perf_counter()
    runtime = InferenceRuntime.from_key(RuntimeKey(checkpoint=str(snapshot / 'model.safetensors'),
        model_device='mps', codec_device='mps', model_precision='fp32', codec_precision='fp32'))
    torch.mps.synchronize()
    run['loadSeconds'] = time.perf_counter() - start
    run['loadSecondsHistory'] = previous_run.get('loadSecondsHistory', [previous_run['loadSeconds']] if previous_run else []) + [run['loadSeconds']]
    print('LOADED', run['loadSeconds'], flush=True)
    record = OUT / 'generation.json'
    results = json.loads(record.read_text()) if record.exists() else []
    index = {(r['speaker'], r['id']): r for r in results}
    try:
        for speaker in args.speakers:
            suffix = '-nojobs' if speaker == 'yametaro' else ''
            rows = json.loads((EP / f'audio-generation{suffix}.json').read_text())
            for row in rows:
                if args.ids and row['id'] not in args.ids:
                    continue
                ref = ROOT / row['reference']
                assert sha(ref) == row['referenceSha256'], 'Reference changed'
                baseline = EP / f"line_{row['id']}_{speaker}.wav"
                assert sha(baseline) == row['sha256'], 'Baseline changed'
                folder = OUT / speaker
                folder.mkdir(exist_ok=True)
                small = folder / f"{row['id']}_small.wav"
                if not small.exists():
                    small.symlink_to(os.path.relpath(baseline, folder))
                raw = folder / f"{row['id']}_large_raw.wav"
                final = folder / f"{row['id']}_large.wav"
                request = SamplingRequest(text=row['speechText'], caption=row['caption'] or None,
                    ref_wav=str(ref), seed=row['seed'], duration_scale=row['durationScale'],
                    cfg_scale_text=row['textCFG'], trim_tail=not row['uncut'])
                identity = {'request': dataclasses.asdict(request), 'model': MODEL,
                    'revision': snapshot.name, 'runtimeCommit': commit,
                    'referenceSha256': row['referenceSha256'], 'precision': 'fp32',
                    'postprocess': row['postprocess'], 'uncut': row['uncut'],
                    'baselineSha256': row['sha256']}
                fingerprint = hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()
                prior = index.get((speaker, row['id']))
                if prior and prior['fingerprint'] == fingerprint and final.exists() and sha(final) == prior['sha256']:
                    print('CACHED', speaker, row['id'], flush=True)
                    continue
                print('GENERATE', speaker, row['id'], row['speechText'], flush=True)
                torch.mps.synchronize()
                started = time.perf_counter()
                result = runtime.synthesize(request, log_fn=lambda msg: print(msg, flush=True))
                save_wav(raw, result.audio, result.sample_rate)
                torch.mps.synchronize()
                synthesis_seconds = time.perf_counter() - started
                if row['uncut']:
                    shutil.copyfile(raw, final)
                else:
                    trimmed = folder / f"{row['id']}_large_trim.wav"
                    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(raw), '-af',
                        'silenceremove=start_periods=1:start_threshold=-40dB:start_silence=0.1,areverse,silenceremove=start_periods=1:start_threshold=-40dB:start_silence=0.2,areverse', str(trimmed)], check=True)
                    subprocess.run([str(ROOT / row['postprocess']), str(trimmed), str(final)], check=True)
                duration = float(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries',
                    'format=duration', '-of', 'csv=p=0', str(final)]))
                entry = {**row, 'model': MODEL, 'baselineModel': row['model'],
                    'baselineSha256': row['sha256'], 'baselineDuration': row['duration'],
                    'duration': duration, 'sha256': sha(final), 'fingerprint': fingerprint,
                    'identity': identity, 'synthesisSeconds': synthesis_seconds,
                    'realTimeFactor': synthesis_seconds / duration,
                    'stageTimings': result.stage_timings, 'messages': result.messages,
                    'smallFile': str(small.relative_to(OUT)), 'largeFile': str(final.relative_to(OUT)),
                    'rawFile': str(raw.relative_to(OUT)),
                    'auditoryReview': '未確認', 'adopted': False}
                index[(speaker, row['id'])] = entry
                write_json(record, list(index.values()))
                run.update(peak)
                run['processMaxRssBytes'] = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
                run['completed'] = len(index)
                write_json(OUT / 'runtime.json', run)
                print('DONE', speaker, row['id'], f'{duration:.2f}s audio / {synthesis_seconds:.2f}s generation', flush=True)
    finally:
        stop.set()
        run.update(peak)
        run['processMaxRssBytes'] = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
        write_json(OUT / 'runtime.json', run)


if __name__ == '__main__':
    main()
