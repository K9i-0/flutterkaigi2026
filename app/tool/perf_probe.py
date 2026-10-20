"""Same-device render ablations via VM service. uv run --with websockets python ...

Arguments: VM websocket URI, output JSON, optional case name.
Frame submission cadence is not a hardware display/GPU presentation measurement.
"""
import asyncio
import json
from pathlib import Path
import sys
import time
import websockets


async def main():
    async with websockets.connect(sys.argv[1], max_size=100_000_000) as ws:
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

        vm = await rpc('getVM')
        isolate = next(i['id'] for i in vm['isolates'] if i['name'] == 'main')

        async def action(**args):
            return await rpc('ext.flutter.madogiwa.catchAction',
                             isolateId=isolate, **args)

        cases = [
            ('standard-day', 'day', '', {}),
            ('no-stage-day', 'day', 'stage', {}),
            ('no-character-day', 'day', 'character', {}),
            ('no-items-day', 'day', 'items', {}),
            ('no-shadows-day', 'day', '', {'shadows': False}),
            ('standard-night', 'night', '', {}),
            ('no-bloom-night', 'night', '', {'bloom': False}),
            ('light-day', 'day', '', {k: False for k in
                ['shadows', 'reflections', 'surfaceDetail', 'bloom', 'fullResolution']}),
        ]
        render_cases = [
            *[(f'final-{character}-{tod}', tod, '', {'fullResolution': False, 'probe': {
                'animateGameplay': 'true', 'character': character}})
              for character in ['sobaya', 'cto_odatetsu', 'fukuchan']
              for tod in ['day', 'night']],
            *[(f'play-{character}-{tod}', tod, '', {'probe': {
                'animateGameplay': 'true', 'character': character, 'aa': 'fxaa',
                'scale': '.55', 'cascades': '1', 'shadowDistance': '24'}})
              for character in ['sobaya', 'cto_odatetsu', 'fukuchan']
              for tod in ['day', 'night']],
            ('active-original-day', 'day', '', {'probe': {'animateGameplay': 'true'}}),
            ('active-fxaa-day', 'day', '', {'probe': {'animateGameplay': 'true', 'aa': 'fxaa'}}),
            ('active-fxaa-80-day', 'day', '', {'probe': {'animateGameplay': 'true', 'aa': 'fxaa',
                'scale': '.8', 'cascades': '1', 'shadowDistance': '24'}}),
            *[(f'active-{scale}-day', 'day', '', {'probe': {'aa': 'fxaa',
                'cascades': '1', 'shadowDistance': '24', 'scale': scale,
                'animateGameplay': 'true'}}) for scale in ['.6', '.5', '.45']],
            *[(f'fxaa-{scale}-day', 'day', '', {'probe': {'aa': 'fxaa',
                'cascades': '1', 'shadowDistance': '24', 'scale': scale}})
              for scale in ['.8', '.7', '.6']],
            ('traffic-moving-day', 'day', '', {'probe': {'animateTraffic': 'true'}}),
            ('traffic-hidden-day', 'day', 'traffic', {}),
            ('empty-day', 'day', 'all3d', {}),
            ('fxaa-day', 'day', '', {'probe': {'aa': 'fxaa'}}),
            ('near-shadow-day', 'day', '', {'probe': {'cascades': '1', 'shadowDistance': '24'}}),
            ('fxaa-near-day', 'day', '', {'probe': {'aa': 'fxaa', 'cascades': '1', 'shadowDistance': '24'}}),
            ('fxaa-night', 'night', '', {'probe': {'aa': 'fxaa'}}),
            ('fxaa-near-90-day', 'day', '', {'probe': {'aa': 'fxaa', 'cascades': '1', 'shadowDistance': '24', 'scale': '.9'}}),
            *[(f'clear-{character}-night', 'night', '', {
                'fullResolution': False, 'bloom': False, 'probe': {
                'animateGameplay': 'true', 'character': character}})
              for character in ['sobaya', 'cto_odatetsu', 'fukuchan']],
        ]
        if len(sys.argv) > 3:
            groups = {
                'final': render_cases[:6],
                'play': render_cases[6:12],
                'quality': render_cases[12:15],
                'active': render_cases[15:18],
                'scale': render_cases[18:21],
                'traffic': [c for c in cases + render_cases if c[0] in
                    ['standard-day', 'traffic-moving-day', 'traffic-hidden-day']],
                'render': render_cases,
                'clear': render_cases[-3:],
            }
            cases = groups.get(sys.argv[3], [c for c in cases + render_cases if c[0] == sys.argv[3]])
            if sys.argv[3] == 'orbit':
                cases = [(f'orbit-{tod}', tod, '', {'fullResolution': False, 'probe': {
                    'animateGameplay': 'true', 'orbit': 'true', 'character': 'cto_odatetsu'}})
                    for tod in ['day', 'night']]
            if not cases:
                raise ValueError(f'Unknown case/group: {sys.argv[3]}')
        initial = await rpc('ext.flutter.madogiwa.inspectCatch', isolateId=isolate)
        results = []
        for name, tod, hide, flags in cases:
            settings = {k: True for k in
                        ['shadows', 'reflections', 'surfaceDetail', 'bloom', 'fullResolution']}
            settings.update({k: v for k, v in flags.items() if k != 'probe'})
            await action(action='graphics', json=json.dumps(settings))
            await action(action='benchmark', label=name, timeOfDay=tod, hide=hide,
                         **flags.get('probe', {}))
            started = time.monotonic()
            while time.monotonic() - started < 100:
                await asyncio.sleep(2)
                state = await rpc('ext.flutter.madogiwa.inspectCatch', isolateId=isolate)
                bench = state['benchmark']
                if not bench['active'] and bench['result']:
                    result = bench['result']
                    assert result.get('hide') == hide, 'Restart app to register diagnostic callback'
                    assert result.get('animateGameplay') == (flags.get('probe', {}).get('animateGameplay') == 'true')
                    result['renderer'] = state.get('renderer')
                    results.append(result)
                    Path(sys.argv[2]).write_text(json.dumps(results, indent=2))
                    print(json.dumps(result), flush=True)
                    break
            else:
                raise TimeoutError(name)
        await action(action='graphics', json=json.dumps(initial['graphics']))


asyncio.run(main())
