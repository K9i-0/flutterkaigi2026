"""3D re-encode rate and Dart CPU hot spots via VM service. uv run --with websockets python ...

Arguments: VM websocket URI, then `rate [WINDOWS]` or `cpu [SECONDS] [TOP]`.
rate: per 1 s timeline window, Flutter frames/s (what the FPS HUD counts), frames that
ran ScenePass (the 3D was actually encoded; flutter_scene re-presents the previous
image while the GPU is a frame behind) and the median ScenePass time on the UI thread.
cpu: inclusive and exclusive share of Dart CPU samples on the main isolate.
Neither is a GPU execution time or a measurement of what the panel displayed.
"""
import asyncio
import collections
import json
import statistics
import sys
import websockets


async def main():
    async with websockets.connect(sys.argv[1], max_size=1_000_000_000) as ws:
        seq = 0

        async def rpc(method, **params):
            nonlocal seq
            seq += 1
            await ws.send(json.dumps(dict(jsonrpc='2.0', id=seq, method=method, params=params)))
            while True:
                msg = json.loads(await ws.recv())
                if msg.get('id') == seq:
                    if 'error' in msg:
                        raise RuntimeError(msg['error'])
                    return msg['result']

        mode = sys.argv[2] if len(sys.argv) > 2 else 'rate'
        if mode == 'rate':
            await rate(rpc, int(sys.argv[3]) if len(sys.argv) > 3 else 6)
        else:
            await cpu(rpc, float(sys.argv[3]) if len(sys.argv) > 3 else 4,
                      int(sys.argv[4]) if len(sys.argv) > 4 else 60)


async def rate(rpc, windows):
    await rpc('setVMTimelineFlags', recordedStreams=['Dart', 'Embedder'])
    results = []
    for _ in range(windows):
        # The timeline ring buffer keeps about one second on a busy phone.
        await rpc('clearVMTimeline')
        await asyncio.sleep(1)
        events = (await rpc('getVMTimeline'))['traceEvents']

        def starts(name):
            return sorted(e['ts'] for e in events
                          if e.get('name') == name and e.get('ph') in ('B', 'X'))

        frames, scenes = starts('Animator::BeginFrame'), starts('ScenePass')
        if len(frames) < 2:
            continue
        open_, durations = {}, []
        for e in sorted((e for e in events if e.get('name') == 'ScenePass'),
                        key=lambda e: e['ts']):
            if e['ph'] == 'X':
                durations.append(e['dur'] / 1000)
            elif e['ph'] == 'B':
                open_[e['tid']] = e['ts']
            elif e['ph'] == 'E' and e['tid'] in open_:
                durations.append((e['ts'] - open_.pop(e['tid'])) / 1000)
        span = (frames[-1] - frames[0]) / 1e6
        results.append(dict(
            frames=(len(frames) - 1) / span,
            scene=len([t for t in scenes if frames[0] <= t <= frames[-1]]) / span,
            scenePassMs=statistics.median(durations) if durations else 0,
        ))
        print(json.dumps({k: round(v, 1) for k, v in results[-1].items()}), flush=True)
    if results:
        print('MEAN', json.dumps({k: round(statistics.mean(r[k] for r in results), 1)
                                  for k in results[0]}))


async def cpu(rpc, seconds, top):
    vm = await rpc('getVM')
    isolate = next(i['id'] for i in vm['isolates'] if i['name'] == 'main')
    await rpc('clearCpuSamples', isolateId=isolate)
    await asyncio.sleep(seconds)
    r = await rpc('getCpuSamples', isolateId=isolate,
                  timeOriginMicros=0, timeExtentMicros=2**62)
    functions, samples = r['functions'], r['samples']

    def name(i):
        f = functions[i]['function']
        owner = f.get('owner', {})
        uri = (f.get('location') or {}).get('script', {}).get('uri', '')
        cls = owner.get('name', '') + '.' if owner.get('type') == '@Class' else ''
        return f"{cls}{f.get('name')} [{uri.split('/')[-1] or functions[i].get('kind')}]"

    inclusive, exclusive = collections.Counter(), collections.Counter()
    for s in samples:
        stack = s.get('stack', [])
        if stack:
            exclusive[name(stack[0])] += 1
        for i in set(stack):
            inclusive[name(i)] += 1
    n = len(samples)
    print('samples', n)
    for title, counter in (('inclusive', inclusive), ('exclusive', exclusive)):
        print('---', title)
        for k, v in counter.most_common(top):
            print(f'{v * 100 / n:5.1f}% {k}')


asyncio.run(main())
