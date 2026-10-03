"""Reproduce the original geometric icon and quiet synthesized placeholder audio.
Standard library only. Outputs are checked in; this script is not a build dependency.
"""
from pathlib import Path
import math
import struct
import wave
import zlib

resources = Path(__file__).resolve().parents[1] / "Target" / "Resources"

patterns = {
    "tile": ([740], 0.055, 0.032),
    "merge": ([180, 720], 0.09, 0.032),
    "invalid": ([130, 100], 0.055, 0.032),
    "exact": ([523, 659, 784, 1047], 0.20, 0.065),
    "countdown": ([680], 0.025, 0.032),
}
rate = 22050
for name, (frequencies, duration, spacing) in patterns.items():
    samples = []
    for frame in range(math.ceil((duration + spacing * (len(frequencies) - 1) + 0.01) * rate)):
        time = frame / rate
        value = 0.0
        for index, frequency in enumerate(frequencies):
            local = time - spacing * index
            if 0 <= local < duration:
                attack = min(1.0, local / 0.004)
                decay = math.exp(-7 * local / duration)
                value += math.sin(2 * math.pi * frequency * local) * attack * decay * 0.14
        samples.append(struct.pack("<h", int(max(-1, min(1, value)) * 32767)))
    with wave.open(str(resources / f"{name}.wav"), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(rate)
        audio.writeframes(b"".join(samples))

# The icon uses the same circles and diagonal strike as the SwiftUI TargetMark.
paper, ink, accent = (245, 240, 224), (26, 38, 48), (232, 71, 33)
def colour_at(x, y):
    dx, dy = x - 512, y - 512
    radius = math.hypot(dx, dy)
    colour = ink if 318 <= radius <= 354 or 166 <= radius <= 202 else paper
    if radius < 38:
        colour = accent
    diagonal = abs(dx + dy) / math.sqrt(2)
    along = abs(dx - dy) / math.sqrt(2)
    if diagonal < 52 and along < 410:
        colour = paper
    if diagonal < 22 and along < 410:
        colour = accent
    return colour

pixels = bytearray()
for y in range(1024):
    pixels.append(0)  # PNG row filter
    for x in range(1024):
        colours = [colour_at(x + a, y + b) for a, b in [(0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75)]]
        pixels.extend(round(sum(c[channel] for c in colours) / 4) for channel in range(3))
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1024, 1024, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(bytes(pixels), 9)) + chunk(b"IEND", b"")
(resources / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png").write_bytes(png)
