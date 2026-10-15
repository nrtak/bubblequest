"""Render the game's original, seamless festival arrangements without dependencies."""
import array
import math
import pathlib
import random
import wave

RATE = 22050
ROOT = pathlib.Path(__file__).resolve().parents[1] / 'BubbleQuest'
# Root MIDI note, tempo, melody (pentatonic degrees; -1 is a rest), lead voice.
TRACKS = {
    'music-menu': (60, 94, [0, 2, 4, 2, 1, 0, -1, 1, 2, 4, 5, 4, 2, 1, 2, -1], 'bell'),
    'music-map': (62, 90, [0, -1, 1, 2, 4, 2, 1, -1, 2, 3, 4, -1, 3, 1, 0, -1], 'flute'),
    'music-day': (60, 104, [0, 1, 2, -1, 4, 2, 1, 0, 2, 4, 5, 4, 2, -1, 1, 2], 'pluck'),
    'music-evening': (57, 92, [2, -1, 4, 3, 2, 1, 0, -1, 1, 2, 4, -1, 3, 2, 1, 0], 'bell'),
    'music-water': (65, 96, [4, 2, 1, -1, 0, 1, 2, -1, 3, 4, 5, 4, 2, 1, 2, -1], 'flute'),
    'music-countryside': (67, 88, [0, 2, -1, 1, 2, 3, 2, -1, 4, 3, 2, 1, 0, -1, 1, 0], 'pluck'),
    'music-challenge': (62, 112, [0, 2, 1, 3, 2, -1, 4, 2, 1, 3, 2, 4, 5, 4, 2, -1], 'pluck'),
    'music-story': (60, 78, [2, -1, 1, -1, 0, 2, -1, -1, 1, -1, 3, 2, 1, -1, 0, -1], 'flute'),
}


def frequency(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def add_note(buffer, start, duration, midi, gain, voice='pluck', pan=0):
    count = int(duration * RATE)
    offset = round(start * RATE)
    hz = frequency(midi)
    length = len(buffer) // 2
    for i in range(count):
        t = i / RATE
        attack = min(1, t / .012)
        release = min(1, (duration - t) / .065)
        phase = 2 * math.pi * hz * t
        if voice == 'flute':
            tone = math.sin(phase + .012 * math.sin(2 * math.pi * 4.6 * t)) + .09 * math.sin(phase * 2)
            envelope = attack * release * math.exp(-t * 1.2)
        elif voice == 'bell':
            tone = math.sin(phase) + .15 * math.sin(phase * 3) * math.exp(-t * 5)
            envelope = attack * release * math.exp(-t * 3.8)
        else:
            tone = math.sin(phase) + .24 * math.sin(phase * 2) + .08 * math.sin(phase * 3)
            envelope = attack * release * math.exp(-t * 5)
        value = tone * envelope * gain
        frame = ((offset + i) % length) * 2
        buffer[frame] += value * (1 - pan * .35)
        buffer[frame + 1] += value * (1 + pan * .35)


def write_pcm(name, samples):
    peak = max(abs(x) for x in samples) or 1
    scale = min(1, .50 / peak)
    pcm = array.array('h', (round(max(-1, min(1, x * scale)) * 32767) for x in samples))
    if __import__('sys').byteorder != 'little':
        pcm.byteswap()
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as output:
        output.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
        output.writeframes(pcm.tobytes())


def render_track(name, root, tempo, melody, voice):
    beat = 60 / tempo
    duration = 24 * 4 * beat
    buffer = array.array('f', [0]) * (round(duration * RATE) * 2)
    scale = [0, 2, 4, 7, 9]
    chords = [(0, 4, 7), (-3, 0, 4), (-5, -1, 2), (-7, -3, 0)]
    rng = random.Random(name)
    for bar in range(24):
        chord = chords[(bar // 2) % 4]
        start = bar * 4 * beat
        for j, note in enumerate(chord):
            add_note(buffer, start + j * .025, beat * 3.5, root + note, .042, 'flute', (j - 1) * .7)
        for pulse in [0, 2]:
            add_note(buffer, start + pulse * beat, beat * 1.3, root + chord[0] - 12, .10, 'pluck', -.1)
        # A / B / A' phrases leave space between melody notes and change register gently.
        phrase = bar // 8
        for step in range(4):
            degree = melody[(bar % 8 * 2 + step) % len(melody)]
            if degree < 0 or (phrase == 1 and step == 3):
                continue
            if phrase == 1:
                degree = (degree + 2) % 7
            midi = root + 12 + scale[degree % 5] + 12 * (degree // 5)
            add_note(buffer, start + step * beat, beat * (.72 if step % 2 else 1.15), midi, .105, voice, .22)
        # Small offbeat plucks suggest a light festival rhythm without a heavy drum loop.
        for step in [1, 3]:
            add_note(buffer, start + (step + .5) * beat, beat * .45, root + chord[1] + 12, .038, 'pluck', -.5)
        if name != 'music-story':
            for step in range(4):
                offset = round((start + (step + .5) * beat) * RATE)
                previous = 0
                for i in range(int(.045 * RATE)):
                    noise = rng.uniform(-1, 1)
                    value = (noise - previous) * .007 * math.sin(math.pi * i / (.045 * RATE)) ** 2
                    previous = noise
                    at = ((offset + i) % (len(buffer) // 2)) * 2
                    buffer[at] += value
                    buffer[at + 1] += value
    # Circular early reflections preserve the loop boundary instead of adding a dead tail.
    dry = buffer[:]
    for delay, gain in [(round(.13 * RATE) * 2, .12), (round(.23 * RATE) * 2, .07)]:
        for i in range(len(buffer)):
            buffer[(i + delay) % len(buffer)] += dry[i] * gain
    write_pcm(name, buffer)


def render_effect(name, notes, beat, gain=.22, voice='bell'):
    duration = len(notes) * beat + .18
    buffer = array.array('f', [0]) * (round(duration * RATE) * 2)
    for i, note in enumerate(notes):
        add_note(buffer, i * beat, beat + .12, note, gain, voice)
    write_pcm(name, buffer)


def generate():
    for name, settings in TRACKS.items():
        render_track(name, *settings)
        print('Rendered', name)
    for args in [
        ('pop', [79, 72], .035, .20, 'pluck'),
        ('launch', [67, 74], .045, .15, 'flute'),
        ('load', [62, 67], .04, .10, 'pluck'),
        ('bomb', [43, 38, 31], .06, .25, 'pluck'),
        ('victory', [67, 69, 72, 76, 79], .11, .20, 'bell'),
        ('armor-crack', [86, 79, 74], .025, .12, 'pluck'),
        ('rescue', [72, 76, 79], .065, .15, 'bell'),
        ('big-drop', [67, 72, 79, 84], .045, .17, 'pluck'),
        ('milestone', [67, 72, 76, 79, 84, 79], .12, .20, 'bell'),
        ('stick', [55], .025, .05, 'pluck'),
        ('map-chime', [79, 86], .13, .09, 'bell'),
        ('map-water', [72, 74, 79], .07, .08, 'flute'),
        ('buddy-hello', [67, 72], .075, .09, 'pluck'),
    ]:
        render_effect(*args)


if __name__ == '__main__':
    generate()
