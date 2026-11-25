"""Generate War and Piece's short, dry card snap and landing tap (no samples)."""
from pathlib import Path
import math
import random
import struct
import wave

rate = 44100
duration = 0.145
rng = random.Random(182)
samples = []
low = 0.0
for i in range(round(rate * duration)):
    t = i / rate
    noise = rng.uniform(-1, 1)
    low += 0.31 * (noise - low)
    paper = noise - low
    # Two rapidly decaying paper transients, then a soft surface contact.
    snap = 0.48 * paper * (1 - math.exp(-t / 0.00035)) * math.exp(-t / 0.008)
    u = max(0.0, t - 0.012)
    flex = (0.18 * paper * (1 - math.exp(-u / 0.0005)) * math.exp(-u / 0.006)) if t >= 0.012 else 0
    v = max(0.0, t - 0.026)
    tap = (0.25 * math.sin(2 * math.pi * 225 * v) + 0.12 * low) * (1 - math.exp(-v / 0.0007)) * math.exp(-v / 0.012) if t >= 0.026 else 0
    samples.append((snap + flex + tap) * min(1.0, (duration-t)/0.008))
peak = max(abs(x) for x in samples)
samples = [x * 0.65 / peak for x in samples]
target = Path(__file__).resolve().parents[3] / 'audio/sfx/wp_card_deal.wav'
target.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(target), 'wb') as f:
    f.setparams((1, 2, rate, len(samples), 'NONE', 'not compressed'))
    f.writeframes(b''.join(struct.pack('<h', round(x * 32767)) for x in samples))
assert max(abs(x) for x in samples) < 1.0
print(f'Created {target.name}: {duration:.3f}s, mono PCM, peak {max(abs(x) for x in samples):.2f}')
