#!/usr/bin/env python3
"""Generates procedural Undertale-style voice blips for every case object
(BUILD_BRIEF.md §6.4). stdlib only (wave, math, struct) — no pip installs.
Run once from the project root: python3 tools/generate_blips.py
Writes assets/audio/blips/{object_id}_{yes|no|huh}.wav; commit the WAVs.
"""
import wave, struct, math, json, os, glob

SR = 44100

def tone(freq, ms, wf):
    n = int(SR * ms / 1000)
    out = []
    for i in range(n):
        t = i / SR
        ph = (t * freq) % 1.0
        s = {"sine": math.sin(2 * math.pi * ph),
             "square": 1.0 if ph < 0.5 else -1.0,
             "triangle": 4 * abs(ph - 0.5) - 1.0,
             "saw": 2 * ph - 1.0}[wf]
        env = min(1.0, i / (SR * 0.005), (n - i) / (SR * 0.005))  # 5ms ramps
        out.append(s * env * 0.5)
    return out

CONTOURS = {"yes": [1.0, 1.3], "no": [1.0, 0.72], "huh": [1.0, 1.25, 0.85]}

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "audio", "blips")
os.makedirs(OUT_DIR, exist_ok=True)

count = 0
for path in sorted(glob.glob(os.path.join(ROOT, "data", "cases", "silent_study", "objects", "*.json"))):
    o = json.load(open(path))
    wf, hz = o["voice"]["waveform"], o["voice"]["base_hz"]
    for ans, mults in CONTOURS.items():
        samples = []
        for m in mults:
            samples += tone(hz * m, 70, wf) + [0.0] * int(SR * 0.025)
        out_path = os.path.join(OUT_DIR, "%s_%s.wav" % (o["id"], ans))
        w = wave.open(out_path, "w")
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in samples))
        w.close()
        count += 1

print("blips generated: %d files in %s" % (count, OUT_DIR))
