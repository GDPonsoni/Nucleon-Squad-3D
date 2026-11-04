#!/usr/bin/env python3
"""Gera as músicas do jogo (menu e um tema por capítulo) por síntese, sem samples.
Uso: python3 scripts/tools/gen_music.py   (só Python padrão, sem numpy)
Saída: assets/audio/music/<nome>.wav (mono, 22050 Hz, 16 bits), em laço perfeito.
Cada faixa: progressão de acordes, baixo, arpejo, pad e bateria, com timbre e andamento próprios.
"""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "music")
NOTES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
SCALES = {"minor": [0, 2, 3, 5, 7, 8, 10], "dorian": [0, 2, 3, 5, 7, 9, 10], "phrygian": [0, 1, 3, 5, 7, 8, 10],
          "harmonic": [0, 2, 3, 5, 7, 8, 11]}

def freq(midi): return 440.0 * 2 ** ((midi - 69) / 12)

def osc(kind, phase):
    p = phase % 1.0
    if kind == "sine": return math.sin(2 * math.pi * p)
    if kind == "tri": return 4 * abs(p - 0.5) - 1
    if kind == "saw": return 2 * p - 1
    if kind == "square": return 1.0 if p < 0.5 else -1.0
    return 0.0

def add_note(buf, start, dur, midi, kind, vol, attack=0.01, release=0.15, cutoff=0.25, detune=0.0):
    """Nota com envelope e passa-baixa de um polo (cutoff 0..1 = mais aberto)."""
    n0 = int(start * SR); n = int((dur + release) * SR); f = freq(midi)
    lp = 0.0; total = len(buf)
    for i in range(n):
        t = i / SR
        env = min(t / attack, 1.0) if t < attack else (1.0 if t < dur else max(0.0, 1 - (t - dur) / release))
        s = osc(kind, f * t)
        if detune: s = 0.5 * (s + osc(kind, f * (1 + detune) * t))
        lp += cutoff * (s - lp)
        buf[(n0 + i) % total] += lp * env * vol  # % = laço perfeito (a cauda volta ao início)

def add_drum(buf, start, kind, vol):
    n0 = int(start * SR); total = len(buf)
    if kind == "kick":
        for i in range(int(0.25 * SR)):
            t = i / SR; f = 50 + 90 * math.exp(-t * 30)
            buf[(n0 + i) % total] += math.sin(2 * math.pi * f * t) * math.exp(-t * 14) * vol
    elif kind == "snare":
        rnd = random.Random(n0); lp = 0.0
        for i in range(int(0.18 * SR)):
            t = i / SR; lp += 0.6 * (rnd.uniform(-1, 1) - lp)
            buf[(n0 + i) % total] += (lp * 0.8 + 0.3 * math.sin(2 * math.pi * 190 * t)) * math.exp(-t * 22) * vol
    elif kind == "hat":
        rnd = random.Random(n0 + 1); prev = 0.0
        for i in range(int(0.05 * SR)):
            t = i / SR; x = rnd.uniform(-1, 1); hp = x - prev; prev = x
            buf[(n0 + i) % total] += hp * math.exp(-t * 70) * vol

def track(name, bpm, key, scale, prog, bars, style):
    beat = 60.0 / bpm; bar = beat * 4; length = bar * bars
    buf = [0.0] * int(length * SR)
    root = 48 + NOTES[key]; sc = SCALES[scale]
    def degree(d, octave=0):
        return root + sc[d % 7] + 12 * (d // 7 + octave)
    for b in range(bars):
        chord = prog[b % len(prog)]; t0 = b * bar
        tones = [degree(chord), degree(chord + 2), degree(chord + 4)]
        # Pad: acorde longo e suave
        for m in tones:
            add_note(buf, t0, bar, m + 12, style["pad"], style["pad_vol"], attack=0.4, release=0.6, cutoff=0.08, detune=0.004)
        # Baixo
        for k, step in enumerate(style["bass"]):
            if step: add_note(buf, t0 + k * beat / 2, beat / 2 * 0.9, degree(chord) - 12, style["bass_wave"], style["bass_vol"], release=0.05, cutoff=0.15)
        # Arpejo
        if style["arp_vol"] > 0:
            per = style["arp_div"]
            for k in range(4 * per):
                m = tones[(k + (b % 2)) % 3] + 12 * (1 + (k // 3) % 2)
                add_note(buf, t0 + k * beat / per, beat / per * 0.7, m, style["arp_wave"], style["arp_vol"], release=0.08, cutoff=0.35)
        # Melodia na segunda metade: passeio pela escala, sempre começando em nota do acorde
        if b >= bars // 2 and style.get("lead_vol", 0.0) > 0:
            rnd = random.Random(name + str(b % 4))
            d = chord + 7
            for k in range(8):
                if rnd.random() < 0.7:
                    add_note(buf, t0 + k * beat / 2, beat / 2 * (1.6 if k % 4 == 3 else 0.9), degree(d), style["lead_wave"],
                             style["lead_vol"], attack=0.02, release=0.12, cutoff=0.22)
                d += rnd.choice([-2, -1, 1, 1, 2])
                d = max(chord + 4, min(chord + 11, d))
        # Bateria
        for k, hit in enumerate(style["drums"]):
            t = t0 + k * beat / 2
            if "k" in hit: add_drum(buf, t, "kick", style["drum_vol"])
            if "s" in hit: add_drum(buf, t, "snare", style["drum_vol"] * 0.7)
            if "h" in hit: add_drum(buf, t, "hat", style["drum_vol"] * 0.35)
    peak = max(abs(x) for x in buf) or 1.0
    gain = 0.7 / peak  # -3 dB de folga
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x * gain)) * 32767)) for x in buf))
    print(f"{name}: {length:.1f} s")

CALM = {"lead_wave": "tri", "lead_vol": 0.16, "pad": "tri", "pad_vol": 0.22, "bass": [1, 0, 0, 0, 1, 0, 0, 0], "bass_wave": "sine", "bass_vol": 0.35,
        "arp_wave": "sine", "arp_vol": 0.12, "arp_div": 2, "drums": [""] * 8, "drum_vol": 0.0}
track("menu", 84, "A", "minor", [0, 5, 3, 4], 16, CALM)
track("chapter_1", 112, "D", "dorian", [0, 3, 6, 4], 16, {**CALM, "arp_wave": "tri", "arp_vol": 0.14, "arp_div": 4,
      "bass": [1, 0, 1, 0, 1, 0, 1, 1], "bass_wave": "tri", "drums": ["kh", "h", "sh", "h", "kh", "kh", "sh", "h"], "drum_vol": 0.5})
track("chapter_2", 126, "E", "phrygian", [0, 1, 0, 6], 16, {**CALM, "pad": "saw", "pad_vol": 0.12, "bass": [1, 1, 0, 1, 1, 1, 0, 1],
      "bass_wave": "saw", "bass_vol": 0.4, "arp_wave": "square", "arp_vol": 0.07, "arp_div": 2,
      "drums": ["kh", "h", "skh", "h", "kh", "kh", "sh", "hs"], "drum_vol": 0.6})
track("chapter_3", 96, "C", "minor", [0, 5, 6, 4], 16, {**CALM, "pad": "saw", "pad_vol": 0.14, "bass_wave": "tri", "bass_vol": 0.4,
      "arp_wave": "sine", "arp_vol": 0.1, "arp_div": 3, "drums": ["k", "", "", "h", "s", "", "k", "h"], "drum_vol": 0.5})
track("chapter_4", 134, "F#", "minor", [0, 6, 5, 4], 16, {**CALM, "pad": "square", "pad_vol": 0.07, "bass": [1, 1, 1, 1, 1, 1, 1, 1],
      "bass_wave": "square", "bass_vol": 0.28, "arp_wave": "square", "arp_vol": 0.08, "arp_div": 4,
      "drums": ["kh", "h", "sh", "h", "kh", "h", "sh", "kh"], "drum_vol": 0.55})
track("chapter_5", 142, "G", "harmonic", [0, 5, 3, 4], 16, {**CALM, "pad": "saw", "pad_vol": 0.13, "bass": [1, 0, 1, 1, 1, 0, 1, 1],
      "bass_wave": "saw", "bass_vol": 0.38, "arp_wave": "saw", "arp_vol": 0.08, "arp_div": 4,
      "drums": ["kh", "h", "skh", "h", "kh", "kh", "skh", "sh"], "drum_vol": 0.65})
