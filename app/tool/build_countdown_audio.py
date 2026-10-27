"""Synthesizes the round countdown sounds (standard library only, no recordings).

    python3 app/tool/build_countdown_audio.py

Writes assets/audio/recruit_exam/countdown_tick.wav (3, 2, 1) and
countdown_go.wav (start), 44.1 kHz 16-bit mono. The app reads them through
relative symlinks in app/assets/audio/.
"""

import array
import math
import pathlib
import wave

RATE = 44100
OUT = pathlib.Path(__file__).resolve().parents[2] / "assets/audio/recruit_exam"


def tone(freqs, seconds, decay, attack=0.004):
    out = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        # A few soft harmonics make a clear electronic beep, not a pure sine.
        v = sum(
            amp * math.sin(2 * math.pi * f * n * t)
            for f in freqs
            for n, amp in ((1, 1.0), (2, 0.28), (3, 0.12))
        )
        env = min(t / attack, 1) * math.exp(-t / decay)
        tail = min(max((seconds - t) / 0.02, 0), 1)
        out.append(v * env * tail)
    return out


def write(name, samples, peak):
    scale = peak / max(abs(s) for s in samples)
    OUT.mkdir(parents=True, exist_ok=True)
    data = array.array("h", (round(s * scale * 32767) for s in samples))
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


# G5 for each count, then an octave-up G6 + D7 chord that rings longer.
write("countdown_tick.wav", tone([784], 0.22, 0.07), peak=0.7)
write("countdown_go.wav", tone([1568, 2349], 0.75, 0.22), peak=0.8)
