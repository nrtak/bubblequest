import json
import math
import pathlib
import struct
import wave
import zlib

root = pathlib.Path(__file__).resolve().parents[1] / 'BubbleQuest'
icons = root / 'Assets.xcassets' / 'AppIcon.appiconset'
icons.mkdir(parents=True, exist_ok=True)
(icons.parent / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}))
(icons / 'Contents.json').write_text(json.dumps({
    'images': [{'filename': 'AppIcon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
    'info': {'author': 'xcode', 'version': 1}
}))
circles = [(320, 355, 190, (247, 113, 145)), (715, 360, 190, (62, 199, 194)),
           (515, 710, 190, (255, 196, 88))]
pixels = bytearray()
for y in range(1024):
    pixels.append(0)
    for x in range(1024):
        color = (33, 37, 71)
        for cx, cy, radius, fill in circles:
            d = math.hypot(x - cx, y - cy)
            if d <= radius:
                color = (255, 239, 222) if d > radius - 10 else fill
                if math.hypot(x - cx + 55, y - cy + 65) < 34:
                    color = (255, 239, 222)
        pixels.extend(color)

def chunk(name, data):
    return struct.pack('>I', len(data)) + name + data + struct.pack('>I', zlib.crc32(name + data))

png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 1024, 1024, 8, 2, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(pixels)) + chunk(b'IEND', b'')
(icons / 'AppIcon.png').write_bytes(png)
with wave.open(str(root / 'pop.wav'), 'wb') as sound:
    sound.setparams((1, 2, 22050, 0, 'NONE', 'not compressed'))
    samples = [int(12000 * math.exp(-i / 550) * math.sin(2 * math.pi * (750 * i / 22050 - 300 * (i / 22050) ** 2))) for i in range(3300)]
    sound.writeframes(struct.pack('<' + 'h' * len(samples), *samples))

# Original pentatonic loops and short cues; no external audio downloads.
def write_tones(name, notes, beat, volume, soft=False):
    rate = 22050
    samples = []
    for frequency in notes:
        count = int(rate * beat)
        for i in range(count):
            t = i / rate
            envelope = min(1, t / 0.02) * max(0, 1 - t / beat)
            envelope *= math.exp(-t * (3 if soft else 8))
            tone = math.sin(2 * math.pi * frequency * t)
            tone += 0.2 * math.sin(4 * math.pi * frequency * t)
            samples.append(int(volume * envelope * tone))
    with wave.open(str(root / (name + '.wav')), 'wb') as sound:
        sound.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        sound.writeframes(struct.pack('<' + 'h' * len(samples), *samples))

write_tones('music-day', [392, 440, 523.25, 440, 587.33, 523.25, 440, 392,
                          329.63, 392, 440, 523.25, 440, 392, 329.63, 392] * 2, 0.5, 5000, True)
write_tones('music-evening', [261.63, 329.63, 392, 440, 392, 329.63, 293.66, 261.63,
                              329.63, 392, 523.25, 440, 392, 329.63, 293.66, 261.63] * 2, 0.65, 4500, True)
write_tones('launch', [440, 660], 0.055, 6500)
write_tones('load', [293.66, 392], 0.045, 3200)
write_tones('bomb', [110, 82.41, 65.41], 0.07, 9500)
write_tones('victory', [392, 440, 523.25, 659.25, 783.99], 0.14, 8500)
