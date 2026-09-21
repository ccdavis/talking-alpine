# /// script
# dependencies = []
# ///
"""Render the ready chime: three rising tones, 0.5 s, 22050 Hz mono 16-bit."""
import math, struct, sys, wave
rate = 22050
notes = [(523.25, 0.14), (659.25, 0.14), (783.99, 0.22)]
out = []
for f, dur in notes:
    n = int(rate * dur)
    for i in range(n):
        env = min(1.0, i / (rate * 0.01), (n - i) / (rate * 0.04))
        s = 0.45 * env * (math.sin(2 * math.pi * f * i / rate) + 0.3 * math.sin(4 * math.pi * f * i / rate))
        out.append(int(s * 32767))
w = wave.open(sys.argv[1], 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
w.writeframes(struct.pack('<%dh' % len(out), *out)); w.close()
print(sys.argv[1], len(out) / rate, 's')
