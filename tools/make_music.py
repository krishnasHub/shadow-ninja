"""Builds Shadow Ninja's music: three seamless 60-second loops in D minor, 64 BPM.

    python tools/make_music.py

  godot/audio/music_base.wav     soft and focused: a warm pad, a low drone, sparse plucked notes
                                 with a soft echo, and a quiet low pulse. Always playing.
  godot/audio/music_tension.wav  same key, chords and length: a muted bass ostinato, a faint tick
                                 and a thin high shimmer. The game fades it in as danger rises.
  godot/audio/music_fight.wav    same key, chords and length: low drums driving on 16ths, a gritty bass,
                                 a backbeat, a heavy stab every two bars. Fades in during a fight (Floor 6 on).
  godot/audio/music_dark.wav     near silence: air, a far-off hum, the building settling. Replaces the base
                                 music when the lights go (Floor 7).
  godot/audio/step_*.wav         movement in the dark, in a big empty room (Floor 7): guards' boots, boots through
                                 a wall; his soft step, run and landing; his hands on a duct (grab, shimmy)
  godot/audio/takedown.wav       landing on a guard: a deep thud, the guard hitting the floor, his torch rattling

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

# ---------------------------------------------------------------- fight layer (Floor 6 on)
def drum(f0=70, dur=0.5, slap=0.4):                      # a big low drum: a pitch-dropping body and a skin slap
    tt = np.arange(int(dur * SR)) / SR
    f = f0 * (1 + 1.2 * np.exp(-tt / 0.025))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / (dur * 0.3))
    skin = lowpass(rng.standard_normal(len(tt)), 900) * np.exp(-tt / 0.02) * slap
    return (body + skin) * np.minimum(1, tt / 0.002)

FIGHT_HITS = {0: 1.0, 3: 0.6, 6: 0.75, 8: 0.9, 10: 0.55, 11: 0.7, 14: 0.8}   # 16ths in a bar: syncopated

def drums():
    out = np.zeros(N)
    step = BEAT / 4
    for k in range(int(LOOP / step)):
        pos = k % 16
        if pos in FIGHT_HITS:
            place(out, drum(64 if pos in (0, 8) else 82) * FIGHT_HITS[pos], k * step)
        elif rng.random() < 0.3:                         # ghost notes: small, higher drums in the gaps
            place(out, drum(120, 0.2, 0.6) * 0.25, k * step)
        if pos in (4, 12):                               # the backbeat: a hard, dry crack
            n = int(0.25 * SR)
            crack = rng.standard_normal(n) * np.exp(-np.arange(n) / (0.045 * SR))
            place(out, (lowpass(crack, 2600) - lowpass(crack, 300)) * 0.9, k * step)
            place(out, drum(180, 0.15, 0) * 0.4, k * step)
    return out

def grit_bass():                                         # the chord root on every 16th, driven into saturation
    out = np.zeros(N)
    step = BEAT / 4
    for k in range(int(LOOP / step)):
        root = CHORDS[int(k * step // CHORD_LEN) % 4][0]
        place(out, bass_note(hz(root), 0.22) * (1.0 if k % 4 == 0 else 0.55), k * step)
    return np.tanh(2.5 * lowpass(out, 700))

def stabs():                                             # a heavy, brassy chord hit every two bars
    out = np.zeros(N)
    bar = 4 * BEAT
    for b in range(0, int(LOOP / bar), 2):
        root, notes = CHORDS[int(b * bar // CHORD_LEN) % 4]
        tt = np.arange(int(1.4 * SR)) / SR
        hit = np.zeros(len(tt))
        for note in [root] + notes[:3]:
            for cents in (-8, 8):
                hit += 2 * ((hz(note) * 2 ** (cents / 1200) * tt) % 1) - 1
        place(out, hit * np.exp(-tt / 0.35) * np.minimum(1, tt / 0.004), b * bar)
    return lowpass(np.tanh(0.6 * out), 1500)

def swells():                                            # noise rising through the last bar into each chord change
    out = np.zeros(N)
    dur = 4 * BEAT
    tt = np.arange(int(dur * SR)) / SR
    for c in range(4):
        sw = lowpass(rng.standard_normal(len(tt)), 2200) * (tt / dur) ** 3
        place(out, sw, (c + 1) * CHORD_LEN - dur)
    return out

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

# ---------------------------------------------------------------- the blackout (Floor 7): near silence, and footsteps
def in_the_room(x, seconds, mix):                        # a dry sound with room left for its tail, in a big empty room
    return reverb(np.concatenate([x, np.zeros(int(seconds * SR))]), seconds, mix)

def boot(f0=105.0, f1=58.0, click=0.5, gap=0.055):       # a hard-soled boot: the heel comes down, then the sole slaps
    n = int(0.22 * SR)
    tt = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-tt / 0.02)
    heel = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 0.045)
    tap = lowpass(rng.standard_normal(n), 2600) * np.exp(-tt / 0.006) * click
    sole = lowpass(rng.standard_normal(n), 1300) * np.exp(-tt / 0.018) * 0.3
    x = heel + tap
    x[int(gap * SR):] += sole[:n - int(gap * SR)]
    return in_the_room(x, 1.6, 0.42)

def soft_step():                                         # his own foot: a muffled pad and a whisper of cloth
    n = int(0.16 * SR)
    tt = np.arange(n) / SR
    pad_ = np.sin(2 * np.pi * (70 + 40 * np.exp(-tt / 0.02)) * tt) * np.exp(-tt / 0.035)
    cloth = lowpass(rng.standard_normal(n), 900) * np.exp(-tt / 0.03) * 0.3
    return in_the_room(lowpass(pad_ + cloth, 700), 1.1, 0.35)

def ninja_run():                                         # his foot at a run: a split-toe slap and a flick of cloth, no heel, no weight
    n = int(0.14 * SR)
    tt = np.arange(n) / SR
    slap = lowpass(rng.standard_normal(n), 1700) * np.exp(-tt / 0.012)
    body = np.sin(2 * np.pi * np.cumsum(90 + 60 * np.exp(-tt / 0.012)) / SR) * np.exp(-tt / 0.02) * 0.5
    x = slap + body
    cloth = rng.standard_normal(n) * np.sin(np.pi * tt / tt[-1]) ** 2 * 0.09            # bright and airy: nothing like a boot
    return in_the_room(x + cloth - lowpass(cloth, 1500), 0.8, 0.22)

def ninja_land():                                        # he comes down: two feet just apart, knees taking it, cloth settling
    x = np.zeros(int(0.35 * SR))
    place(x, thud(115, 46, 0.12, 0.3), 0.0)
    place(x, thud(95, 42, 0.14, 0.35) * 0.8, 0.035)
    return in_the_room(x, 0.9, 0.25)

def metal(tt, partials):                                 # struck sheet metal: inharmonic partials, each ringing its own time
    return sum(a * np.sin(2 * np.pi * f * tt) * np.exp(-tt / d) for f, a, d in partials)

def duct_grab():                                         # both hands catch the duct: a slap, and the hollow metal booms
    n = int(0.6 * SR)
    tt = np.arange(n) / SR
    boom = metal(tt, [(142, 1.0, 0.13), (231, 0.7, 0.09), (387, 0.45, 0.06), (611, 0.25, 0.035)])
    hands = lowpass(rng.standard_normal(n), 1800) * np.exp(-tt / 0.01) * 0.8
    return in_the_room(lowpass(boom, 1500) + hands, 0.9, 0.3)

def duct_shimmy(f0=520.0):                               # a hand moves along: the thin metal flexes (a quick upward tick) and fabric rubs
    n = int(0.2 * SR)
    tt = np.arange(n) / SR
    flex = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 0.35 * (1 - np.exp(-tt / 0.015)))) / SR) * np.exp(-tt / 0.022)
    rub = rng.standard_normal(n) * np.sin(np.pi * tt / tt[-1]) ** 2 * 0.1
    return in_the_room(lowpass(flex, 2400) + lowpass(rub, 3200), 0.5, 0.2)

def takedown_thud():                                     # he lands on a guard: a deep body blow, the guard hits the floor, his torch rattles
    x = np.zeros(int(1.0 * SR))
    place(x, thud(135, 38, 0.3, 0.9), 0.0)
    place(x, thud(92, 34, 0.24, 0.45) * 0.7, 0.26)
    n = int(0.08 * SR)
    tt = np.arange(n) / SR
    tick = metal(tt, [(1450, 1.0, 0.012), (2230, 0.5, 0.008)])
    for at, level in [(0.36, 0.1), (0.45, 0.07), (0.51, 0.04)]:
        place(x, tick * level, at)
    return in_the_room(x, 1.0, 0.25)

def dark_room():                                   # the loop: air and a far-off hum, with something settling now and then
    n = int(LOOP * SR)
    spec = np.fft.rfft(rng.standard_normal(n))           # filtered in one piece, so the air loops with no seam
    freqs = np.fft.rfftfreq(n, 1 / SR)
    air = np.fft.irfft(spec / (1 + (freqs / 140) ** 2), n)
    air /= np.max(np.abs(air))
    tt = np.arange(n) / SR
    cycles = lambda f: round(f * LOOP) / LOOP            # whole cycles per loop, so the hum does too
    breath = 0.7 + 0.3 * np.sin(2 * np.pi * 3 * tt / LOOP)
    hum = np.sin(2 * np.pi * cycles(hz('D2')) * tt) + 0.6 * np.sin(2 * np.pi * cycles(hz('D2') * 1.006) * tt)
    x = 0.35 * air * breath + 0.05 * hum
    for at, f, dur, level in [(9.0, 62, 3.2, 0.5), (27.5, 47, 4.0, 0.7), (44.0, 83, 2.4, 0.4)]:   # the building settling
        m = int(dur * SR)
        st = np.arange(m) / SR
        groan = np.sin(2 * np.pi * np.cumsum(f * (1 + 0.05 * np.sin(2 * np.pi * 0.7 * st))) / SR)
        groan += 0.5 * np.sin(2 * np.pi * np.cumsum(f * 2.71 * np.ones(m)) / SR)   # inharmonic: metal, not a note
        env = np.sin(np.pi * st / dur) ** 2
        place(x, in_the_room(lowpass(groan * env, 500), 2.5, 0.6) * level, at)
    return x

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
    fight = reverb(0.8 * drums() + 0.35 * grit_bass() + 0.3 * stabs() + 0.12 * swells(), 1.2, 0.2)
    write(os.path.join(root, 'music_fight.wav'), fold(fight), 0.6)   # last: rng order keeps the others identical
    write(os.path.join(root, 'music_dark.wav'), dark_room(), 0.5)
    boot_a = boot()
    write(os.path.join(root, 'step_boot_a.wav'), boot_a, 0.8)
    write(os.path.join(root, 'step_boot_b.wav'), boot(92.0, 52.0, 0.35, 0.07), 0.7)   # the other foot lands a little heavier and duller
    write(os.path.join(root, 'step_boot_wall.wav'), lowpass(boot_a, 320), 0.6)        # the same boot, through a wall
    write(os.path.join(root, 'step_soft.wav'), soft_step(), 0.6)
    write(os.path.join(root, 'step_run.wav'), ninja_run(), 0.65)
    write(os.path.join(root, 'step_land.wav'), ninja_land(), 0.75)
    write(os.path.join(root, 'step_grab.wav'), duct_grab(), 0.7)
    write(os.path.join(root, 'step_shimmy_a.wav'), duct_shimmy(), 0.55)
    write(os.path.join(root, 'step_shimmy_b.wav'), duct_shimmy(450.0), 0.55)          # the other hand
    write(os.path.join(root, 'takedown.wav'), takedown_thud(), 0.9)
