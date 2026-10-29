"""Builds Shadow Ninja's music: two seamless 60-second loops in D minor, 64 BPM.

    python tools/make_music.py

  godot/audio/music_base.wav     soft and focused: a warm pad, a low drone, sparse plucked notes
                                 with a soft echo, and a quiet low pulse. Always playing.
  godot/audio/music_tension.wav  same key, chords and length: a muted bass ostinato, a faint tick
                                 and a thin high shimmer. The game fades it in as danger rises.

  godot/audio/heartbeat.wav      a muffled lub-dub; the game plays it faster and louder as the meter fills
  godot/audio/riser.wav          an uneasy high cluster (loops); fades in and rises in pitch near full
  godot/audio/caught.wav         a deep impact and a dissonant stab, when the meter fills
  godot/audio/lever.wav          a heavy metal clunk, then a door bolt sliding back somewhere off
  godot/audio/rattle.wav         a locked door's handle rattling: a few dull metal knocks
  godot/audio/siren.wav          the alarm (loops): a muffled two-tone wail, as if from the next room
  godot/audio/panel.wav          a stone through the alarm panel: a crack and a dying electric buzz
  godot/audio/scrape.wav         a desk dragged a little way: legs juddering on the floor (Floor 5 on)
  godot/audio/thud*.wav          a blow landing (Floor 6 on): thud, thud_small (one of several hits), thud_big (a special)
  godot/audio/shout.wav          a watcher landing a punch: a gruff, muffled shout that carries

Both versions of the game play these files (the HTML one from godot/audio/). Everything here is
synthesised with numpy, so the music is original and easy to change: edit, run, replay.
"""
import os
import wave
import numpy as np

SR = 22050                      # modest quality keeps the files small; the music is soft and dark anyway
BPM = 64
BEAT = 60 / BPM                 # 0.9375 s
LOOP = 16 * 4 * BEAT            # 16 bars = 60 s
TAIL = 4.0                      # rendered past the loop point, then folded back onto the start (seamless)
N = int((LOOP + TAIL) * SR)
t = np.arange(N) / SR
rng = np.random.default_rng(7)

def hz(note):                   # 'D3', 'Bb2', 'C#4' -> Hz
    names = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6,
             'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}
    name, octave = note[:-1], int(note[-1])
    return 440.0 * 2 ** ((names[name] + 12 * (octave + 1) - 69) / 12)

def lowpass(x, cutoff):         # one-pole low-pass
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y

def reverb(x, seconds=2.6, mix=0.35):   # convolution with a decaying-noise impulse: soft and wide
    n = int(seconds * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (SR * seconds / 5.5))
    ir = lowpass(ir, 2800)
    ir /= np.sqrt(np.sum(ir ** 2))
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:len(x)]
    return (1 - mix) * x + mix * wet

def place(dst, src, at):        # mix src into dst starting at time `at` (wrapping past the end)
    i = int(at * SR) % len(dst)
    end = min(len(dst), i + len(src))
    dst[i:end] += src[:end - i]
    if i + len(src) > len(dst):
        dst[:i + len(src) - len(dst)] += src[end - i:]

# ---------------------------------------------------------------- harmony: 4 chords, 4 bars each
CHORDS = [
    ('D2', ['D3', 'F3', 'A3', 'E4']),          # Dm(add9)
    ('Bb1', ['Bb2', 'D3', 'F3', 'A3']),        # Bbmaj7
    ('G1', ['G2', 'Bb2', 'D3', 'F3', 'A3']),   # Gm9
    ('A1', ['A2', 'D3', 'E3', 'G3']),          # A7sus4 - leans back to D
]
CHORD_LEN = LOOP / 4
PENTA = ['D4', 'F4', 'G4', 'A4', 'C5', 'D5', 'F5']

def pad():
    out = np.zeros(N)
    for c, (_, notes) in enumerate(CHORDS):
        start = c * CHORD_LEN - 1.0                     # chords overlap by a second or two
        dur = CHORD_LEN + 2.5
        tt = np.arange(int(dur * SR)) / SR
        env = np.minimum(1, tt / 3.0) * np.minimum(1, (dur - tt) / 3.5)
        env = np.clip(env, 0, 1) ** 1.5
        voice = np.zeros(len(tt))
        for note in notes:
            f = hz(note)
            for cents in (-4, 0, 5):                      # three slightly detuned copies: a warm chorus
                ff = f * 2 ** (cents / 1200)
                ph = rng.uniform(0, 2 * np.pi)
                voice += np.sin(2 * np.pi * ff * tt + ph) + 0.22 * np.sin(4 * np.pi * ff * tt + ph) \
                    + 0.08 * np.sin(6 * np.pi * ff * tt + ph)
        voice *= env * (1 + 0.15 * np.sin(2 * np.pi * 0.11 * tt))   # a slow breath
        place(out, voice / len(notes), start)
    return lowpass(out, 1400)

def drone():
    swell = 0.75 + 0.25 * np.sin(2 * np.pi * t / LOOP)  # one slow swell per loop (loops cleanly)
    return (np.sin(2 * np.pi * hz('D2') * t) + 0.5 * np.sin(2 * np.pi * hz('D1') * t)) * swell

def pluck(f, dur=2.4, bright=1.0):                       # kalimba-ish: a sine plus a quick inharmonic ping
    tt = np.arange(int(dur * SR)) / SR
    s = np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.55) + 0.35 * bright * np.sin(2 * np.pi * f * 2.76 * tt) * np.exp(-tt / 0.08)
    return s * np.minimum(1, tt / 0.004)

def plucks():
    out = np.zeros(N)
    step = BEAT / 2
    for k in range(int(LOOP / step)):
        bar_pos = k % 16
        p = 0.32 if bar_pos % 4 == 0 else 0.14           # sparse: more likely on beats
        if rng.random() < p:
            chord = CHORDS[int(k * step // CHORD_LEN) % 4][1]
            tones = [n for n in PENTA if n[:-1] in [c[:-1] for c in chord]] or PENTA
            note = tones[rng.integers(len(tones))] if rng.random() < 0.75 else PENTA[rng.integers(len(PENTA))]
            vel = 0.55 + 0.45 * rng.random()
            place(out, pluck(hz(note)) * vel, k * step + rng.normal(0, 0.01))
    echo = np.zeros(N)                                   # a soft dotted-eighth echo
    d = int(0.75 * BEAT * SR)
    for r in range(1, 4):
        echo[d * r:] += out[:-d * r] * (0.38 ** r)
    return out + lowpass(echo, 1800)

def thump(f0=58, dur=0.6):                               # a soft, muffled low pulse
    tt = np.arange(int(dur * SR)) / SR
    f = f0 * (1 + 0.6 * np.exp(-tt / 0.03))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 0.16) * np.minimum(1, tt / 0.006)

def pulse():
    out = np.zeros(N)
    for b in range(int(LOOP / BEAT)):
        if b % 2 == 0:
            place(out, thump() * (1.0 if b % 4 == 0 else 0.6), b * BEAT)
    return out

# ---------------------------------------------------------------- tension layer
def bass_note(f, dur):                                   # a muted, filtered pluck an octave low
    tt = np.arange(int(dur * SR)) / SR
    saw = 2 * ((f * tt) % 1) - 1
    return saw * np.exp(-tt / 0.12) * np.minimum(1, tt / 0.005)

def ostinato():
    out = np.zeros(N)
    step = BEAT / 2
    for k in range(int(LOOP / step)):
        root = CHORDS[int(k * step // CHORD_LEN) % 4][0]
        f = hz(root) * (2 if k % 8 in (3, 7) else 1)     # a lift on the "and" of 2 and 4
        place(out, bass_note(f, 0.4) * (1.0 if k % 2 == 0 else 0.7), k * step)
    return lowpass(out, 420)

def ticks():
    out = np.zeros(N)
    step = BEAT / 4
    click = rng.standard_normal(int(0.012 * SR)) * np.exp(-np.arange(int(0.012 * SR)) / (0.002 * SR))
    click = click - lowpass(click, 3000)                 # keep only the high part: a dry tick
    for k in range(int(LOOP / step)):
        place(out, click * (1.0 if k % 4 == 0 else 0.45), k * step)
    return out

def shimmer():
    trem = 0.5 + 0.5 * np.sin(2 * np.pi * 6.4 * t)
    s = np.zeros(N)
    for c, (_, notes) in enumerate(CHORDS):              # the chord's top voice, two octaves up, very thin
        f = hz(notes[-1]) * 2
        seg = (t >= c * CHORD_LEN) & (t < (c + 1) * CHORD_LEN + 1)
        s += np.where(seg, np.sin(2 * np.pi * f * t), 0)
    return lowpass(s * trem, 2500)

# ---------------------------------------------------------------- mix, loop, write
def fold(x):                                             # wrap the tail back onto the start: seamless loop
    n = int(LOOP * SR)
    y = x[:n].copy()
    y[:len(x) - n] += x[n:]
    return y

def write(path, x, peak):
    x = x / np.max(np.abs(x)) * peak
    pcm = (np.clip(x, -1, 1) * 32767).astype('<i2')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f'{path}: {len(x) / SR:.1f}s, {os.path.getsize(path) / 1e6:.1f} MB')

# ---------------------------------------------------------------- meter sounds (one-shots and a loop)
def heartbeat():                                         # lub-dub: two muffled low thumps
    x = np.zeros(int(0.7 * SR))
    place(x, thump(48, 0.45), 0.0)
    place(x, thump(60, 0.4) * 0.7, 0.19)
    return lowpass(x, 220)

def riser(seconds=8.0):                                  # an uneasy high cluster that loops seamlessly
    n = int(seconds * SR)
    tt = np.arange(n + SR) / SR
    x = np.zeros(len(tt))
    for note, amp in (('D5', 1.0), ('Eb5', 0.8), ('A5', 0.5), ('Ab4', 0.6)):   # minor seconds and a tritone: unease
        f = hz(note)
        x += amp * np.sin(2 * np.pi * f * tt + rng.uniform(0, 6)) * (0.6 + 0.4 * np.sin(2 * np.pi * rng.uniform(4, 7) * tt))
    x += 0.3 * lowpass(rng.standard_normal(len(tt)), 900)  # a breath of noise underneath
    x = lowpass(x, 2200)
    fade = np.linspace(0, 1, SR)                         # crossfade the extra second back onto the start
    y = x[:n].copy()
    y[:SR] = y[:SR] * fade + x[n:] * (1 - fade)
    return y

def caught_sting():                                      # a deep impact and a dissonant stab, ringing out
    n = int(3.0 * SR)
    tt = np.arange(n) / SR
    boom = np.sin(2 * np.pi * np.cumsum(38 * (1 + 1.5 * np.exp(-tt / 0.05))) / SR) * np.exp(-tt / 0.6)
    hit = lowpass(rng.standard_normal(n), 600) * np.exp(-tt / 0.08)
    stab = sum(np.sin(2 * np.pi * hz(nn) * tt) for nn in ('D4', 'Eb4', 'Ab4', 'D5')) * np.exp(-tt / 0.9) * np.minimum(1, tt / 0.01)
    return reverb(boom + 0.6 * hit + 0.25 * lowpass(stab, 1800), 2.4, 0.35)

def lever_clunk():                                       # pulling a lever: a heavy clunk, then a distant bolt
    n = int(1.6 * SR)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    knock = lowpass(rng.standard_normal(n), 1400) * np.exp(-tt / 0.018)                  # the handle hitting home
    ring = sum(a * np.sin(2 * np.pi * f * tt) for f, a in ((310, 1.0), (523, 0.6), (871, 0.35), (1290, 0.2)))
    body = np.sin(2 * np.pi * np.cumsum(70 * (1 + 0.8 * np.exp(-tt / 0.03))) / SR) * np.exp(-tt / 0.12)
    x += knock + 0.35 * ring * np.exp(-tt / 0.07) + 0.9 * body
    bolt = lowpass(rng.standard_normal(n), 700) * np.minimum(1, tt / 0.02) * np.exp(-tt / 0.05)   # the bolt slides
    thud = np.sin(2 * np.pi * 55 * tt) * np.exp(-tt / 0.09)
    place(x, 0.35 * (bolt + thud)[:int(0.5 * SR)], 0.38)
    return reverb(x, 1.2, 0.25)

def door_rattle():                                       # trying a locked door: the handle rattles against the bolt
    n = int(0.7 * SR)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    for at, amp in ((0.0, 1.0), (0.09, 0.8), (0.17, 0.9), (0.28, 0.55)):
        k = np.arange(int(0.12 * SR)) / SR
        hit = lowpass(rng.standard_normal(len(k)), 1800) * np.exp(-k / 0.012)
        ring = (np.sin(2 * np.pi * 410 * k) + 0.5 * np.sin(2 * np.pi * 690 * k)) * np.exp(-k / 0.035)
        place(x, amp * (hit + 0.3 * ring), at)
    return reverb(x, 0.8, 0.2)

def siren(seconds=2.4):                                  # a muffled two-tone wail that loops seamlessly
    n = int(seconds * SR)
    tt = np.arange(n) / SR
    f = np.where((tt // (seconds / 2)) % 2 == 0, hz('A4'), hz('Eb5'))      # a tritone apart: urgent, uneasy
    f = lowpass(f, 12)                                                      # glide between the two, don't jump
    ph = 2 * np.pi * np.cumsum(f) / SR
    ph *= round(ph[-1] / (2 * np.pi)) * 2 * np.pi / ph[-1]                 # a whole number of cycles: no click at the loop
    x = np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)
    return lowpass(x, 1200) * (0.85 + 0.15 * np.sin(2 * np.pi * tt * 4 / seconds))

def panel_zap():                                         # a stone through the panel: crack, then a buzz that dies
    n = int(1.2 * SR)
    tt = np.arange(n) / SR
    crack = lowpass(rng.standard_normal(n), 3000) * np.exp(-tt / 0.02)
    buzz = np.sign(np.sin(2 * np.pi * 120 * tt)) * lowpass(rng.standard_normal(n), 400) * np.exp(-tt / 0.35)
    fizz = np.sin(2 * np.pi * 120 * tt) * (np.sin(2 * np.pi * 9 * tt) > 0) * np.exp(-tt / 0.5)
    return reverb(crack + 0.4 * lowpass(buzz, 1500) + 0.25 * fizz, 0.9, 0.2)

def star_whoosh():                                       # a throwing star leaving the hand: a quick, thin swish
    n = int(0.28 * SR)
    tt = np.arange(n) / SR
    env = np.sin(np.pi * np.clip(tt / 0.22, 0, 1)) ** 2
    swish = lowpass(rng.standard_normal(n), 5200) - lowpass(rng.standard_normal(n), 1400)
    return reverb(swish * env, 0.5, 0.15)

def glass_break():                                       # a lamp shattering: a crack, a spray of glass, bits landing
    n = int(1.4 * SR)
    tt = np.arange(n) / SR
    x = lowpass(rng.standard_normal(n), 6000) * np.exp(-tt / 0.03)
    for k in range(26):                                  # shards: short high rings, scattered and fading
        at = 0.01 + rng.random() ** 1.6 * 0.9
        f = 2400 + rng.random() * 4200
        d = 0.05 + rng.random() * 0.12
        m = int(d * SR)
        t2 = np.arange(m) / SR
        ping = np.sin(2 * np.pi * f * t2) * np.exp(-t2 / (d / 4)) * (0.5 + rng.random() * 0.5) * (1.0 - at)
        place(x, ping, at)
    return reverb(x, 1.0, 0.25)

def star_tink():                                         # a star biting into a wall: a small metallic tink
    n = int(0.4 * SR)
    tt = np.arange(n) / SR
    x = (np.sin(2 * np.pi * 2350 * tt) + 0.6 * np.sin(2 * np.pi * 3720 * tt)) * np.exp(-tt / 0.05)
    x += lowpass(rng.standard_normal(n), 3000) * np.exp(-tt / 0.008)
    return reverb(x, 0.4, 0.15)

def desk_scrape():                                       # a desk dragged a little way: wooden legs juddering on the floor
    n = int(0.42 * SR)
    tt = np.arange(n) / SR
    env = np.sin(np.pi * np.clip(tt / 0.36, 0, 1)) ** 1.5
    judder = 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 23 * tt))          # stick-slip: the legs catch and let go
    grit = lowpass(rng.standard_normal(n), 900) - 0.5 * lowpass(rng.standard_normal(n), 160)
    groan = np.sin(2 * np.pi * (140 + 25 * tt) * tt) * 0.25            # a low creak in the wood
    return reverb((grit + groan) * judder * env, 0.6, 0.18)

def thud(f0=150, f1=52, dur=0.16, crack=0.5):            # a blow landing: a body-thump (a pitch drop) and a puff of cloth
    n = int((dur + 0.15) * SR)
    tt = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-tt / (dur * 0.35))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / (dur * 0.45))
    puff = lowpass(rng.standard_normal(n), 1100) * np.exp(-tt / 0.018) * crack
    return reverb(body + puff, 0.35, 0.12)

def shout():                                             # a watcher's punch lands: a gruff "hey!" through a wall
    n = int(0.5 * SR)
    tt = np.arange(n) / SR
    f = 150 * (1 + 0.25 * np.exp(-tt / 0.05)) * (1 - 0.15 * tt)
    ph = np.cumsum(f) / SR
    voice = 2 * (ph % 1) - 1                                       # a sawtooth: the throat
    x = lowpass(voice, 900) - 0.6 * lowpass(voice, 350)            # roughly an "eh" - mid formants
    x += 0.35 * lowpass(rng.standard_normal(n), 2000) * np.exp(-tt / 0.03)   # the h
    env = np.clip(tt / 0.03, 0, 1) * np.exp(-np.clip(tt - 0.18, 0, None) / 0.06)
    return reverb(lowpass(x * env, 1600), 0.8, 0.25)

if __name__ == '__main__':
    root = os.path.join(os.path.dirname(__file__), '..', 'godot', 'audio')
    base = reverb(0.55 * pad() + 0.22 * drone() + 0.30 * plucks(), 2.8, 0.4) + 0.32 * pulse()
    write(os.path.join(root, 'music_base.wav'), fold(base), 0.55)
    tension = reverb(0.7 * ostinato() + 0.12 * ticks() + 0.10 * shimmer(), 1.6, 0.25)
    write(os.path.join(root, 'music_tension.wav'), fold(tension), 0.5)
    write(os.path.join(root, 'heartbeat.wav'), heartbeat(), 0.8)
    write(os.path.join(root, 'riser.wav'), riser(), 0.5)
    write(os.path.join(root, 'caught.wav'), caught_sting(), 0.8)
    write(os.path.join(root, 'lever.wav'), lever_clunk(), 0.8)            # last: rng order keeps the others identical
    write(os.path.join(root, 'rattle.wav'), door_rattle(), 0.7)
    write(os.path.join(root, 'siren.wav'), siren(), 0.5)
    write(os.path.join(root, 'panel.wav'), panel_zap(), 0.75)
    write(os.path.join(root, 'whoosh.wav'), star_whoosh(), 0.55)
    write(os.path.join(root, 'glass.wav'), glass_break(), 0.8)
    write(os.path.join(root, 'tink.wav'), star_tink(), 0.6)
    write(os.path.join(root, 'scrape.wav'), desk_scrape(), 0.6)
    write(os.path.join(root, 'thud.wav'), thud(), 0.75)
    write(os.path.join(root, 'thud_small.wav'), thud(200, 85, 0.09, 0.35), 0.5)
    write(os.path.join(root, 'thud_big.wav'), thud(120, 36, 0.28, 0.8), 0.9)
    write(os.path.join(root, 'shout.wav'), shout(), 0.6)
