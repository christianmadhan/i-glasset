#!/usr/bin/env python
"""Compose App Store marketing screenshots from raw simulator captures.

Usage: market.py <raw shots dir> <output dir> <fonts dir>

For every locale and device size, writes NN-<slug>.png framed on the brand's
cellar-green ground with a Libre Caslon headline, the raw capture inside a thin
bezel that runs off the bottom edge.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAW, OUT, FONTS = sys.argv[1:4]

SIZES = {
    # App Store Connect display families and the pixel sizes it accepts.
    "iphone-6.7": (1290, 2796),
    "iphone-6.5": (1242, 2688),
    "iphone-5.5": (1242, 2208),
}

# (raw file, slug, {locale: (headline, subline)})
SHOTS = [
    ("05-live.png", "live", {
        "da-DK": ("Smag blindt.", "Glasset er skjult, indtil værten afslører det."),
        "en-US": ("Taste blind.", "The glass stays hidden until the host reveals it."),
    }),
    ("06-smagsskema.png", "sheet", {
        "da-DK": ("Gæt for point.", "Duft, smag, drue, pris, årgang, land og region."),
        "en-US": ("Guess for points.", "Aroma, taste, grape, price, vintage, country and region."),
    }),
    ("09-afsloring.png", "reveal", {
        "da-DK": ("Afsløringen lander\npå alle telefoner.", "Flasken, gruppens snit og dine point – kategori for kategori."),
        "en-US": ("The reveal lands\non every phone.", "The bottle, the group average and your points, category by category."),
    }),
    ("08-live-sendt.png", "host", {
        "da-DK": ("Værten styrer aftenen.", "Se hvem der har bedømt, og afslør når alle er klar."),
        "en-US": ("The host runs the evening.", "See who has scored, and reveal when everyone is ready."),
    }),
    ("10-resultater.png", "results", {
        "da-DK": ("Stillingen efter\nhvert glas.", "Hvem gætter bedst i aften?"),
        "en-US": ("Standings after\nevery glass.", "Who is guessing best tonight?"),
    }),
    ("03-gruppe-stilling.png", "group", {
        "da-DK": ("Klubben holder\nregnskab.", "Point, forbrug og rekorder over alle aftener."),
        "en-US": ("The club keeps score.", "Points, spend and records across every evening."),
    }),
    ("11-top.png", "archive", {
        "da-DK": ("Dit eget arkiv.", "Alle glas gemt med billede, karakter og noter."),
        "en-US": ("Your own archive.", "Every glass kept with photo, score and notes."),
    }),
    ("04-deltag.png", "join", {
        "da-DK": ("Ingen konto.\nIngen server.", "Telefonerne finder hinanden på jeres eget wi-fi."),
        "en-US": ("No account.\nNo server.", "The phones find each other on your own Wi-Fi."),
    }),
]

NIGHT = (31, 41, 34)
NIGHT_DEEP = (22, 30, 25)
CREAM = (247, 241, 234)
MUTED = (186, 196, 188)
GOLD = (217, 164, 65)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return m


def background(W, H):
    img = Image.new("RGB", (W, H), NIGHT)
    px = img.load()
    for y in range(H):
        t = y / H
        c = tuple(int(NIGHT[i] + (NIGHT_DEEP[i] - NIGHT[i]) * t) for i in range(3))
        for x in range(W):
            px[x, y] = c
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((W * 0.1, H * 0.22, W * 0.9, H * 0.62), fill=GOLD + (70,))
    glow = glow.filter(ImageFilter.GaussianBlur(W // 5))
    return Image.alpha_composite(img.convert("RGBA"), glow)


def wrap(draw, text, fnt, width):
    out = []
    for para in text.split("\n"):
        words, cur = para.split(), ""
        for w in words:
            t = (cur + " " + w).strip()
            if draw.textlength(t, font=fnt) <= width:
                cur = t
            else:
                out.append(cur)
                cur = w
        out.append(cur)
    return out


def compose(raw_path, headline, subline, size):
    W, H = size
    s = W / 1290  # scale everything from the 6.7" design
    tall = H / W > 2.0

    canvas = background(W, H)
    draw = ImageDraw.Draw(canvas)

    margin = int(96 * s)
    f_head = font("LibreCaslonText-Regular.ttf", int((104 if tall else 92) * s))
    f_sub = font("PublicSans-Variable.ttf", int(44 * s))
    try:
        f_sub.set_variation_by_name("Regular")
    except Exception:
        pass

    y = int((150 if tall else 120) * s)
    for line in wrap(draw, headline, f_head, W - 2 * margin):
        draw.text((margin, y), line, font=f_head, fill=CREAM)
        y += int(f_head.size * 1.12)
    y += int(22 * s)
    for line in wrap(draw, subline, f_sub, W - 2 * margin):
        draw.text((margin, y), line, font=f_sub, fill=MUTED)
        y += int(f_sub.size * 1.4)

    # the phone: raw capture in a thin bezel, bleeding off the bottom
    shot = Image.open(raw_path).convert("RGB")
    phone_w = int(W * (0.82 if tall else 0.74))
    phone_h = int(phone_w * shot.height / shot.width)
    shot = shot.resize((phone_w, phone_h), Image.LANCZOS)
    radius = int(150 * phone_w / 1290)
    shot.putalpha(rounded_mask(shot.size, radius))

    bezel = int(16 * s)
    top = max(y + int(70 * s), int((640 if tall else 560) * s))
    left = (W - phone_w) // 2

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (left - bezel, top - bezel + int(40 * s), left + phone_w + bezel, top + phone_h + bezel),
        radius=radius + bezel, fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(48 * s)))
    canvas = Image.alpha_composite(canvas, shadow)

    frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle(
        (left - bezel, top - bezel, left + phone_w + bezel, top + phone_h + bezel),
        radius=radius + bezel, fill=(14, 18, 16, 255), outline=(78, 92, 82, 255), width=int(3 * s))
    canvas = Image.alpha_composite(canvas, frame)
    canvas.alpha_composite(shot, (left, top))

    return canvas.convert("RGB")


for i, (raw, slug, copy) in enumerate(SHOTS, start=1):
    for locale, (head, sub) in copy.items():
        for family, size in SIZES.items():
            d = os.path.join(OUT, locale, family)
            os.makedirs(d, exist_ok=True)
            out = os.path.join(d, f"{i:02d}-{slug}.png")
            compose(os.path.join(RAW, raw), head, sub, size).save(out, "PNG", optimize=True)
            print("wrote", out)
