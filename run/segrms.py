# /// script
# dependencies = []
# ///
"""Print the loud stretches of a 16-bit PCM wav: start, end, RMS, peak (window 0.25 s)."""
import struct, array, sys
p = sys.argv[1]; thr = float(sys.argv[2]) if len(sys.argv) > 2 else 150
raw = open(p, 'rb').read()
ch = struct.unpack_from('<H', raw, 22)[0]; rate = struct.unpack_from('<I', raw, 24)[0]
a = array.array('h'); a.frombytes(raw[44:len(raw) - (len(raw) - 44) % 2]); a = a[::ch]
w = rate // 4; segs = []; cur = None
for i in range(0, len(a) - w, w):
    s = a[i:i + w]; rms = (sum(x * x for x in s) / w) ** 0.5; pk = max(abs(x) for x in s)
    if rms > thr:
        if cur is None: cur = [i / rate, i / rate, rms, pk]
        cur[1] = (i + w) / rate; cur[2] = max(cur[2], rms); cur[3] = max(cur[3], pk)
    elif cur:
        segs.append(cur); cur = None
if cur: segs.append(cur)
print(f"{len(a)/rate:.1f} s, {rate} Hz, {len(segs)} loud stretches")
for s in segs: print(f"  {s[0]:7.2f}-{s[1]:7.2f}  rms {s[2]:6.0f}  peak {s[3]:5.0f}")
