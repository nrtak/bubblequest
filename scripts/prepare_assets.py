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
