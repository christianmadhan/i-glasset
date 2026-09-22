#!/usr/bin/env python
"""Google Play listing graphics: the 512 px icon and the 1024×500 feature graphic.

Usage: play_graphics.py <repo root> <fonts dir>
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT, FONTS = sys.argv[1:3]
OUT = os.path.join(ROOT, "playstore", "graphics")
os.makedirs(OUT, exist_ok=True)

SOURCE_ICON = os.path.join(ROOT, "assets", "icon", "app_icon.png")
NIGHT, NIGHT_DEEP = (31, 41, 34), (22, 30, 25)
CREAM, MUTED, GOLD, LABEL = (247, 241, 234), (186, 196, 188), (217, 164, 65), (163, 175, 166)


def font(name, size, variation=None):
    f = ImageFont.truetype(os.path.join(FONTS, name), size)
    if variation:
        f.set_variation_by_name(variation)
    return f


# --- hi-res icon: Play wants 512×512, 32-bit PNG, square (Play rounds it itself)
Image.open(SOURCE_ICON).convert("RGB").resize((512, 512), Image.LANCZOS).save(
    os.path.join(OUT, "icon-512.png"), "PNG")

# --- feature graphic
W, H = 1024, 500
img = Image.new("RGB", (W, H), NIGHT)
px = img.load()
for y in range(H):
    t = y / H
    c = tuple(int(NIGHT[i] + (NIGHT_DEEP[i] - NIGHT[i]) * t) for i in range(3))
    for x in range(W):
        px[x, y] = c
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse((40, -80, 420, 580), fill=GOLD + (34,))
img = Image.alpha_composite(img.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(120)))

mark = Image.open(SOURCE_ICON).convert("RGBA").resize((260, 260), Image.LANCZOS)
mask = Image.new("L", (260, 260), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, 259, 259), radius=58, fill=255)
mark.putalpha(mask)
shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle((100, 140, 360, 400), radius=58, fill=(0, 0, 0, 140))
img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(24)))
img.alpha_composite(mark, (90, 120))

d = ImageDraw.Draw(img)
x = 420
d.text((x, 150), "HUCE  |  SMAG SAMMEN", font=font("PublicSans-Variable.ttf", 22, "Medium"), fill=LABEL)
d.text((x, 185), "I Glasset", font=font("LibreCaslonText-Regular.ttf", 96), fill=CREAM)
d.text((x, 310), "Blindsmagning med vennerne.", font=font("PublicSans-Variable.ttf", 32, "Regular"), fill=GOLD)
d.text((x, 354), "Ingen konto. Ingen server. Kun jeres wi-fi.",
       font=font("PublicSans-Variable.ttf", 26, "Regular"), fill=MUTED)
img.convert("RGB").save(os.path.join(OUT, "feature-graphic-1024x500.png"), "PNG")
print("wrote", OUT)
