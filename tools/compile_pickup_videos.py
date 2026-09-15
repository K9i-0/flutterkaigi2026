#!/usr/bin/env python3
"""Compile the public site's pickup cards into one locally rendered MP4."""
import argparse
import datetime as dt
import json
import math
from pathlib import Path
import random
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(args):
    subprocess.run([str(a) for a in args], check=True)


def probe(path):
    return json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(path)
    ]))


def select(episodes, limit, seed, order):
    seen, selected = set(), []
    for episode in sorted(episodes, key=lambda e: (
        e.get('featured_video_created_at') or e.get('created_at') or '', e['id']
    ), reverse=True):
        video_id = episode.get('primary_video_id')
        if episode.get('status') != 'published' or not episode.get('has_featured_video') or not video_id:
            continue
        if not re.fullmatch(r'[a-zA-Z0-9-]+', video_id):
            raise ValueError('Invalid video ID')
        if video_id in seen:
            continue
        seen.add(video_id)
        selected.append({'video_id': video_id, 'title': episode['title'], 'slug': episode['slug']})
    if limit:
        selected = selected[:limit]
    if order == 'shuffle':
        random.Random(seed).shuffle(selected)
    return selected


def download(url, target):
    if target.exists():
        probe(target)
        return
    part = target.with_suffix('.part')
    try:
        run(['curl', '--fail', '--location', '--silent', '--show-error',
             '--retry', '2', '--connect-timeout', '30', '--max-time', '1800',
             '--output', part, url])
        probe(part)
        part.replace(target)
    finally:
        part.unlink(missing_ok=True)


def normalize(source, target, width, height, fps):
    info = probe(source)
    video = next(s for s in info['streams'] if s['codec_type'] == 'video')
    duration = float(video.get('duration') or info['format']['duration'])
    if not math.isfinite(duration) or duration <= 0:
        raise ValueError(f'Invalid duration: {source}')
    frames = math.ceil(duration * fps)
    audio = any(s['codec_type'] == 'audio' for s in info['streams'])
    args = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-nostdin', '-y', '-i', source]
    if not audio:
        args += ['-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo']
    vf = (f'scale={width}:{height}:force_original_aspect_ratio=decrease:force_divisible_by=2,'
          f'pad={width}:{height}:(ow-iw)/2:(oh-ih)/2,setsar=1,fps={fps},'
          'tpad=stop_mode=clone:stop_duration=1,setpts=PTS-STARTPTS')
    args += ['-map', '0:v:0', '-map', '0:a:0' if audio else '1:a:0',
             '-vf', vf, '-af', 'aresample=48000,asetpts=PTS-STARTPTS,apad',
             '-t', str(frames / fps), '-c:v', 'libx264', '-preset', 'fast', '-crf', '20',
             '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-ar', '48000', '-ac', '2', '-b:a', '192k',
             '-map_metadata', '-1', '-movflags', '+faststart', target]
    run(args)
    return frames / fps


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--limit', type=int, default=0, help='Newest N pickup works; 0 = all')
    parser.add_argument('--seed', type=int, help='Repeatable shuffle seed')
    parser.add_argument('--order', choices=['shuffle', 'newest'], default='shuffle')
    parser.add_argument('--portrait', action='store_true', help='1080x1920 instead of 1920x1080')
    parser.add_argument('--size', help='Override resolution, e.g. 640x360')
    parser.add_argument('--fps', type=int, default=30)
    parser.add_argument('--dry-run', action='store_true', help='List videos without downloading or rendering')
    parser.add_argument('--catalog', type=Path, help='Read saved public API JSON (offline verification)')
    parser.add_argument('--output', type=Path, help='New .mp4 path; existing files are never overwritten')
    args = parser.parse_args()
    width, height = (1080, 1920) if args.portrait else (1920, 1080)
    if args.size:
        if not re.fullmatch(r'\d+x\d+', args.size):
            parser.error('--size must be WIDTHxHEIGHT')
        width, height = map(int, args.size.split('x'))
    if min(width, height) < 2 or width % 2 or height % 2 or not 1 <= args.fps <= 120 or args.limit < 0:
        parser.error('Use positive even dimensions, fps 1–120, and limit >= 0')
    origin = 'https://madogiwa.work'
    if args.catalog:
        catalog = json.loads(args.catalog.read_text())
    else:
        catalog = json.loads(subprocess.check_output([
            'curl', '--fail', '--location', '--silent', '--show-error',
            '--retry', '2', '--connect-timeout', '30', '--max-time', '120',
            origin + '/api/episodes?featured=true']))
    seed = args.seed if args.seed is not None else random.SystemRandom().randrange(2**32)
    videos = select(catalog['episodes'], args.limit, seed, args.order)
    if not videos:
        raise ValueError('No public pickup videos found')
    print(f'{len(videos)} videos | seed={seed} | {width}x{height} {args.fps}fps', flush=True)
    for i, item in enumerate(videos, 1):
        print(f'{i:02d}. {item["title"]} [{item["video_id"]}]', flush=True)
    if args.dry_run:
        return
    for tool in ('ffmpeg', 'ffprobe'):
        if not shutil.which(tool):
            raise ValueError(f'{tool} is required (macOS: brew install ffmpeg)')
    stamp = dt.datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    output = (args.output or ROOT / '.local/pickup-compilations' / f'pickup_{stamp}.mp4').resolve()
    if output.suffix.lower() != '.mp4':
        parser.error('--output must end in .mp4')
    manifest_path = output.with_suffix('.json')
    if output.exists() or manifest_path.exists():
        raise ValueError('Output or manifest already exists; choose a new output path')
    output.parent.mkdir(parents=True, exist_ok=True)
    cache = ROOT / '.local/pickup-compilations/cache'
    cache.mkdir(parents=True, exist_ok=True)
    work = output.parent / f'.{output.stem}-work'
    work.mkdir(exist_ok=False)
    manifest = {'created_at': dt.datetime.now(dt.timezone.utc).isoformat(), 'origin': origin,
                'selection': 'public pickup episodes, one primary video per episode',
                'order': args.order, 'seed': seed, 'width': width, 'height': height,
                'fps': args.fps, 'videos': videos, 'status': 'rendering'}
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    try:
        for index, item in enumerate(videos):
            print(f'[{index+1}/{len(videos)}] Download / encode: {item["title"]}', flush=True)
            source = cache / f'{item["video_id"]}.mp4'
            download(origin + '/media/' + item['video_id'], source)
            item['duration_seconds'] = normalize(source, work / f'{index:04d}.mp4', width, height, args.fps)
        playlist = work / 'concat.txt'
        playlist.write_text(''.join(f"file '{i:04d}.mp4'\n" for i in range(len(videos))))
        staged = work / 'complete.mp4'
        run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-nostdin', '-n', '-f', 'concat',
             '-safe', '1', '-i', playlist, '-c', 'copy', '-movflags', '+faststart', staged])
        run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-xerror', '-nostdin', '-i', staged,
             '-f', 'null', '-'])
        manifest['result'] = probe(staged)['format']
        manifest['result']['filename'] = str(output)
        # Hard-link publishes atomically without replacing any existing output.
        output.hardlink_to(staged)
        manifest['status'] = 'complete'
        shutil.rmtree(work)
        print(f'Complete: {output}', flush=True)
    except Exception as error:
        manifest['status'] = 'failed'
        manifest['error'] = str(error)
        raise
    finally:
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    try:
        main()
    except (Exception, KeyboardInterrupt) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
