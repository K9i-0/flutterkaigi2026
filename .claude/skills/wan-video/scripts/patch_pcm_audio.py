#!/usr/bin/env python3
"""Replace an equal-duration PCM16 WAV region without shifting other samples."""
import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import sys
import wave


def read_pcm(path):
    with wave.open(str(path), 'rb') as w:
        if w.getcomptype() != 'NONE' or w.getsampwidth() != 2:
            raise ValueError('Inputs must be uncompressed PCM16 WAV files')
        spec = (w.getnchannels(), w.getframerate())
        frames = w.getnframes()
        data = w.readframes(frames)
    if len(data) != frames * spec[0] * 2:
        raise ValueError('Truncated WAV input')
    return data, spec, frames


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('original', type=Path)
    ap.add_argument('replacement', type=Path)
    ap.add_argument('output', type=Path)
    ap.add_argument('--target-start', type=float, required=True, help='Seconds in original')
    ap.add_argument('--source-start', type=float, required=True, help='Seconds in replacement')
    ap.add_argument('--duration', type=float, required=True, help='Same duration in both files')
    ap.add_argument('--gain-db', type=float, default=0, help='Constant gain on inserted region only')
    args = ap.parse_args()
    report_path = args.output.with_suffix('.patch.json')
    try:
        values = (args.target_start, args.source_start, args.duration, args.gain_db)
        if not all(math.isfinite(v) for v in values):
            raise ValueError('All numeric arguments must be finite')
        if min(args.target_start, args.source_start) < 0 or args.duration <= 0:
            raise ValueError('Start times must be nonnegative and duration positive')
        if args.output.resolve() in {args.original.resolve(), args.replacement.resolve()}:
            raise ValueError('Output must differ from both inputs')
        if args.output.exists() or report_path.exists():
            raise ValueError('Refusing to overwrite output or report; choose a new filename')
        original, spec, frames = read_pcm(args.original)
        replacement, other_spec, other_frames = read_pcm(args.replacement)
        if spec != other_spec:
            raise ValueError('Inputs must have identical sample rates and channel counts')
        channels, rate = spec
        start = round(args.target_start * rate)
        source = round(args.source_start * rate)
        count = round(args.duration * rate)
        if count <= 0 or start + count > frames or source + count > other_frames:
            raise ValueError('Requested region is empty or exceeds an input')
        frame_bytes = channels * 2
        a, b = start * frame_bytes, (start + count) * frame_bytes
        c, d = source * frame_bytes, (source + count) * frame_bytes
        patch = replacement[c:d]
        if args.gain_db != 0:
            gain = 10 ** (args.gain_db / 20)
            samples = array.array('h', patch)
            if sys.byteorder != 'little':
                samples.byteswap()
            scaled = [round(v * gain) for v in samples]
            if any(v < -32768 or v > 32767 for v in scaled):
                raise ValueError('Gain would clip PCM16; reduce --gain-db')
            samples = array.array('h', scaled)
            if sys.byteorder != 'little':
                samples.byteswap()
            patch = samples.tobytes()
        result = original[:a] + patch + original[b:]
        assert len(result) == len(original)
        assert result[:a] == original[:a] and result[b:] == original[b:]
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open('xb') as handle:
            with wave.open(handle, 'wb') as w:
                w.setparams((channels, 2, rate, 0, 'NONE', 'not compressed'))
                w.writeframes(result)
        decoded, _, _ = read_pcm(args.output)
        if decoded != result:
            raise ValueError('Written PCM does not match the intended output')
        report = {
            'original': str(args.original), 'replacement': str(args.replacement),
            'output': str(args.output), 'sample_rate': rate, 'channels': channels,
            'frames': frames, 'target_start_frame': start, 'source_start_frame': source,
            'frame_count': count, 'gain_db': args.gain_db,
            'time_stretch': False, 'crossfade': False, 'outside_patch_pcm_identical': True,
            'insert_pcm_sha256': hashlib.sha256(patch).hexdigest(),
            'original_file_sha256': hashlib.sha256(args.original.read_bytes()).hexdigest(),
            'replacement_file_sha256': hashlib.sha256(args.replacement.read_bytes()).hexdigest(),
            'output_file_sha256': hashlib.sha256(args.output.read_bytes()).hexdigest(),
            'review': 'Timing/PCM checks only; boundaries, voice, ambience and lip sync need review',
        }
        with report_path.open('x', encoding='utf-8') as handle:
            json.dump(report, handle, ensure_ascii=False, indent=2)
            handle.write('\n')
        print(f'Wrote {args.output}; outside region unchanged; report: {report_path}')
        return 0
    except (ValueError, OSError, wave.Error, OverflowError) as exc:
        print(f'Error: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
