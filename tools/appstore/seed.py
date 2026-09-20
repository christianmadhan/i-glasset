#!/usr/bin/env python
"""Seed the simulator's I Glasset store with a realistic wine club.

Usage: seed.py <app Documents dir> [my user id]

Writes <Documents>/I Glasset/data/*.json in the exact shapes LocalStore reads,
and renders a bottle "photo" per glass under tastings/<id>/items/<itemId>.jpg.
"""
import hashlib
import json
import os
import random
import shutil
import sys
import uuid
from datetime import datetime, timedelta, timezone

from PIL import Image, ImageDraw, ImageFilter, ImageFont

DOCS = sys.argv[1]
ME = sys.argv[2] if len(sys.argv) > 2 else str(uuid.uuid4())
ROOT = os.path.join(DOCS, "I Glasset")
DATA = os.path.join(ROOT, "data")

rng = random.Random(20260920)


def uid():
    return str(uuid.UUID(int=rng.getrandbits(128), version=4))


def iso(dt):
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")


def local(y, m, d, hh=19, mm=0):
    # Danish summer time (UTC+2) for every date used here.
    return datetime(y, m, d, hh, mm, tzinfo=timezone(timedelta(hours=2)))


# ---------------------------------------------------------------- people

PEOPLE = [
    # id, display name, skill at guessing, palate bias
    (ME, "Christian Witt", 0.65, 0.0),
    (uid(), "Marie Holm", 0.6, 0.3),
    (uid(), "Jonas Kjær", 0.5, -0.2),
    (uid(), "Sofie Lund", 0.88, 0.1),
    (uid(), "Anders Bech", 0.4, -0.4),
    (uid(), "Line Dahl", 0.55, 0.2),
]
IDS = {p[1].split()[0]: p[0] for p in PEOPLE}

profiles = []
for i, (pid, name, _, _) in enumerate(PEOPLE):
    profiles.append({
        "id": pid,
        "display_name": name,
        "avatar_seed": "%08x" % rng.getrandbits(32),
        "is_guest": False,
        "created_at": iso(local(2025, 11, 7, 18, 30) + timedelta(minutes=7 * i)),
    })

# ---------------------------------------------------------------- group

GROUP_ID = uid()
group = {
    "id": GROUP_ID,
    "name": "Vinklubben Østerbro",
    "description": "Seks venner, én flaske ad gangen. Vi mødes den sidste fredag i måneden.",
    "focus": ["Vin"],
    "access": "approval",
    "invite_code": "GRP-K7QZ",
    "created_by": ME,
    "created_at": iso(local(2025, 11, 7, 18, 40)),
}
group_members = []
for i, (pid, _, _, _) in enumerate(PEOPLE):
    group_members.append({
        "id": f"{GROUP_ID}:{pid}",
        "group_id": GROUP_ID,
        "user_id": pid,
        "role": "owner" if pid == ME else "member",
        "status": "active",
        "joined_at": iso(local(2025, 11, 7, 18, 40) + timedelta(minutes=9 * i)),
    })

# ---------------------------------------------------------------- vocabulary

AROMAS = ["Kirsebær", "Solbær", "Blåbær", "Blomme", "Rose", "Violer",
          "Urter", "Tjære", "Tobak", "Læder", "Vanilje", "Peber"]
FLAVOURS = ["Rød frugt", "Mørk frugt", "Høj syre", "Stramme tanniner",
            "Blød tannin", "Lakrids", "Urter", "Peber", "Fad"]
GRAPES = ["Nebbiolo", "Sangiovese", "Barbera", "Aglianico",
          "Lagrein", "Cannonau", "Cabernet", "Corvina"]
COUNTRIES = ["Italien", "Frankrig", "Spanien", "Portugal", "Østrig"]
REGIONS = ["Piemonte", "Toscana", "Alto Adige", "Campania", "Sardinien", "Veneto"]
EXTRAS = ["Økologisk", "Ståltank", "Tre år på store fade",
          "Vulkansk jord", "Gamle stokke", "Højtliggende marker"]

DEFAULT_CONFIG = {
    "blind": "Alt skjult",
    "reveal": "Efter hvert glas",
    "order": "Fast",
    "scale": "1-10",
    "show_others": "Efter afsløring",
    "timer": "Ingen",
    "code_mode": "Automatisk",
    "guests": "Kun gruppen",
    "require_notes": False,
    "guess_on": True,
    "cats": {k: {"on": True, "pts": 5 if k == "region" else 3}
             for k in ["duft", "smag", "drue", "pris", "alkohol", "argang", "region", "ekstra"]},
}

# ---------------------------------------------------------------- bottles
# (name, producer, grape, country, region, vintage, abv, price, aromas, flavours,
#  extra, host_notes, style)
# style = (glass, label, capsule, shape)

STYLES = {
    "green-cream-burgundy": ("#1f3b2c", "#f2e9d6", "#7a1f2e", "bordeaux"),
    "green-white-black": ("#22402f", "#fbfaf5", "#1c1c1c", "bordeaux"),
    "brown-cream-gold": ("#2e1c15", "#efe4cc", "#b8902f", "burgundy"),
    "black-black-gold": ("#15151a", "#181818", "#b8902f", "bordeaux"),
    "green-cream-green": ("#1e3a2a", "#f4ecdc", "#2f4f3a", "burgundy"),
    "brown-white-red": ("#31201a", "#f9f7f0", "#8b2f2f", "bordeaux"),
    "black-cream-burgundy": ("#121216", "#efe6d3", "#6d1a2a", "burgundy"),
}

T_PIEMONTE = [
    ("Langhe Nebbiolo Serra", "Cascina Roveri", "Nebbiolo", "Italien", "Piemonte", 2022, 13.5, 165,
     ["Kirsebær", "Rose", "Urter"], ["Rød frugt", "Høj syre", "Stramme tanniner"], None,
     "Indgangsglasset. Let, duftende – et godt sted at kalibrere.", "green-cream-burgundy"),
    ("Barbera d'Alba Vigna Vecchia", "Poderi Ferrero", "Barbera", "Italien", "Piemonte", 2021, 14.0, 140,
     ["Blomme", "Kirsebær", "Vanilje"], ["Rød frugt", "Høj syre", "Blød tannin"], None,
     "Mange vil gætte Sangiovese på syren.", "brown-white-red"),
    ("Barbaresco Rio Sordo", "Ca' Bruna", "Nebbiolo", "Italien", "Piemonte", 2020, 14.0, 340,
     ["Rose", "Tjære", "Kirsebær", "Læder"], ["Stramme tanniner", "Høj syre", "Rød frugt"], None,
     None, "green-white-black"),
    ("Barolo Cannubi Alto", "Tenuta Marchesa", "Nebbiolo", "Italien", "Piemonte", 2019, 14.5, 520,
     ["Tjære", "Rose", "Tobak", "Læder"], ["Stramme tanniner", "Lakrids", "Rød frugt"], "Tre år på store fade",
     "Aftenens dyreste. Dekanteret kl. 17.", "black-black-gold"),
    ("Roero Riserva Costa Bianca", "Poderi Ferrero", "Nebbiolo", "Italien", "Piemonte", 2020, 14.0, 230,
     ["Kirsebær", "Violer", "Urter"], ["Rød frugt", "Blød tannin", "Høj syre"], None,
     None, "green-cream-green"),
    ("Dolcetto d'Alba Bricco Nero", "Cascina Roveri", "Barbera", "Italien", "Piemonte", 2023, 12.5, 110,
     ["Blåbær", "Blomme", "Violer"], ["Mørk frugt", "Blød tannin"], None,
     "Snyder: lav alkohol, mørk farve.", "black-cream-burgundy"),
]

T_TOSCANA = [
    ("Chianti Classico Le Pietre", "Fattoria Colle Verde", "Sangiovese", "Italien", "Toscana", 2021, 13.5, 155,
     ["Kirsebær", "Urter", "Tobak"], ["Rød frugt", "Høj syre", "Stramme tanniner"], None,
     None, "green-cream-burgundy"),
    ("Rosso di Montalcino Poggio Serena", "Poggio Serena", "Sangiovese", "Italien", "Toscana", 2022, 14.0, 195,
     ["Kirsebær", "Blomme", "Læder"], ["Rød frugt", "Blød tannin", "Fad"], None,
     None, "brown-cream-gold"),
    ("Morellino di Scansano Vento", "Podere Il Vento", "Sangiovese", "Italien", "Toscana", 2022, 13.5, 120,
     ["Blomme", "Kirsebær", "Peber"], ["Rød frugt", "Blød tannin"], "Økologisk",
     None, "green-white-black"),
    ("Bolgheri Rosso Le Dune", "Tenuta Le Dune", "Cabernet", "Italien", "Toscana", 2021, 14.0, 260,
     ["Solbær", "Vanilje", "Tobak"], ["Mørk frugt", "Fad", "Stramme tanniner"], None,
     None, "black-black-gold"),
    ("Chianti Classico Gran Selezione Vigna del Sole", "Fattoria Colle Verde", "Sangiovese", "Italien", "Toscana",
     2019, 14.5, 410,
     ["Kirsebær", "Tjære", "Læder", "Tobak"], ["Stramme tanniner", "Høj syre", "Lakrids"], "Gamle stokke",
     None, "black-cream-burgundy"),
]

T_VULKAN = [
    ("Etna Rosso Contrada Nera", "Vigneti Neri", "Nerello Mascalese", "Italien", "Sicilien", 2021, 13.5, 220,
     ["Kirsebær", "Rose", "Urter"], ["Rød frugt", "Høj syre", "Blød tannin"], "Vulkansk jord",
     None, "green-cream-green"),
    ("Aglianico del Vulture Pietra Nera", "Cantine del Vulture", "Aglianico", "Italien", "Basilicata", 2019, 14.0, 185,
     ["Blomme", "Tjære", "Peber"], ["Mørk frugt", "Stramme tanniner", "Lakrids"], "Vulkansk jord",
     None, "brown-white-red"),
    ("Taurasi Monte Vesuvio", "Tenuta Fumarola", "Aglianico", "Italien", "Campania", 2017, 14.0, 310,
     ["Tjære", "Læder", "Tobak", "Kirsebær"], ["Stramme tanniner", "Mørk frugt", "Fad"], "Vulkansk jord",
     None, "black-black-gold"),
    ("Lacryma Christi del Vesuvio Rosso", "Tenuta Fumarola", "Piedirosso", "Italien", "Campania", 2022, 13.0, 130,
     ["Kirsebær", "Violer", "Urter"], ["Rød frugt", "Blød tannin"], "Vulkansk jord",
     None, "green-cream-burgundy"),
]

T_ITALIEN = [
    ("Valpolicella Ripasso Ca' del Vento", "Ca' del Vento", "Corvina", "Italien", "Veneto", 2021, 13.5, 145,
     ["Kirsebær", "Blomme", "Vanilje"], ["Rød frugt", "Blød tannin", "Fad"], None,
     "Blødt åbningsglas. Ripasso-sødmen afslører det for de fleste.", "brown-cream-gold"),
    ("Lagrein Riserva Gries", "Kellerei Sankt Anna", "Lagrein", "Italien", "Alto Adige", 2020, 13.5, 210,
     ["Blåbær", "Violer", "Peber"], ["Mørk frugt", "Blød tannin", "Peber"], "Højtliggende marker",
     "Næsten ingen gætter Lagrein. Se på farven.", "green-white-black"),
    ("Taurasi Vigna Antica", "Tenuta Fumarola", "Aglianico", "Italien", "Campania", 2018, 14.0, 325,
     ["Tjære", "Læder", "Kirsebær", "Tobak"], ["Stramme tanniner", "Mørk frugt", "Lakrids"], "Vulkansk jord",
     "Serveres efter 40 min i karaffel. Spørg om syren.", "black-black-gold"),
    ("Cannonau di Sardegna Riserva Sa Pedra", "Cantina Oristano", "Cannonau", "Italien", "Sardinien", 2020, 14.5, 175,
     ["Blomme", "Urter", "Peber"], ["Rød frugt", "Urter", "Blød tannin"], None,
     None, "green-cream-green"),
    ("Barbera d'Asti Superiore Bricco Alto", "Cascina Roveri", "Barbera", "Italien", "Piemonte", 2021, 14.0, 160,
     ["Kirsebær", "Blomme", "Vanilje"], ["Høj syre", "Rød frugt", "Blød tannin"], None,
     None, "brown-white-red"),
    ("Brunello di Montalcino Poggio Serena", "Poggio Serena", "Sangiovese", "Italien", "Toscana", 2018, 14.5, 495,
     ["Kirsebær", "Læder", "Tobak", "Tjære"], ["Stramme tanniner", "Høj syre", "Lakrids"], "Tre år på store fade",
     "Aftenens finale. Ikke afslør prisen før sidst.", "black-cream-burgundy"),
]

MY_NOTES = [
    "Lys, næsten gennemsigtig. Roser og kirsebær – det må være Nebbiolo.",
    "Saftig syre, ingen tanniner at tale om. Hverdagsvin i bedste forstand.",
    "Tjære og roser. Lang eftersmag. Vil gerne have den om ti år.",
    "Stor. Tanninerne fylder hele munden. Dyr, og det smager sådan.",
    "Elegant og lidt stram. Kunne være Roero.",
    "Mørk farve men let i kroppen. Snydeglas?",
    "Klassisk toscansk – kirsebær og en smule urter.",
    "Blødere end forventet. Fad i eftersmagen.",
    "Frugtig og ligetil. Solrig.",
    "Solbær og vanilje. Cabernet, ikke Sangiovese.",
    "Massiv. Ung endnu. Ville gerne have en bøf.",
    "Røg og røde bær. Etna?",
    "Mørk og kraftig – Aglianico-tanniner.",
    "Læder og tørret frugt. Moden Taurasi.",
    "Let, blomstret. Sjov kontrast til resten.",
    "Sødmefuld frugt, bløde tanniner. Ripasso.",
    "Violer og blåbær, meget mørk. Lagrein – eller Syrah?",
]

# ---------------------------------------------------------------- scoring (mirrors GuessScorer)

def score_guess(item, guess, config):
    rows = {}
    total = 0
    cats = config["cats"]
    has_extra = bool(item.get("extra"))
    for key, rule in cats.items():
        if not rule["on"]:
            continue
        if key == "ekstra" and not has_extra:
            continue
        mx = rule["pts"]
        if key == "duft":
            got = min(len(set(guess["guess_aromas"]) & set(item["aromas"])), mx)
        elif key == "smag":
            got = min(len(set(guess["guess_flavours"]) & set(item["flavours"])), mx)
        elif key == "drue":
            got = mx if eq(guess["guess_grape"], item["grape"]) else 0
        elif key == "pris":
            d = abs(guess["guess_price"] - item["price"])
            got = mx if d <= 25 else (-(-mx * 2 // 3) if d <= 50 else (-(-mx // 3) if d <= 100 else 0))
        elif key == "alkohol":
            d = abs(guess["guess_abv"] - item["abv"])
            got = mx if d < 0.05 else (1 if d <= 1 else 0)
        elif key == "argang":
            d = abs(guess["guess_vintage"] - item["vintage"])
            got = mx if d == 0 else (1 if d <= 2 else 0)
        elif key == "region":
            cp = max(mx - 2, 1)
            rp = mx - cp
            got = (cp if eq(guess["guess_country"], item["country"]) else 0) + \
                  (rp if eq(guess["guess_region"], item["region"]) else 0)
        elif key == "ekstra":
            got = mx if eq(guess["guess_extra"], item["extra"]) else 0
        else:
            got = 0
        rows[key] = {"got": got, "max": mx}
        total += got
    return rows, total


def eq(a, b):
    return a is not None and b is not None and a.strip().lower() == b.strip().lower()


def pick(lst, k, must=None):
    out = []
    if must:
        out.extend(must)
    pool = [x for x in lst if x not in out]
    rng.shuffle(pool)
    out.extend(pool[: max(0, k - len(out))])
    return out[:k]


def make_guess(item, skill):
    hits = [a for a in item["aromas"] if rng.random() < skill]
    aromas = pick(AROMAS, 3, hits)
    hits = [f for f in item["flavours"] if rng.random() < skill]
    flavours = pick(FLAVOURS, 3, hits)
    grape = item["grape"] if rng.random() < skill * 0.85 else rng.choice(
        [g for g in GRAPES if g != item["grape"]])
    country = item["country"] if rng.random() < 0.85 + skill * 0.1 else rng.choice(
        [c for c in COUNTRIES if c != item["country"]])
    region = item["region"] if rng.random() < skill * 0.7 else rng.choice(
        [r for r in REGIONS if r != item["region"]])
    price = item["price"] + rng.gauss(0, 25 + (1 - skill) * 130)
    price = max(50, min(1500, round(price / 25) * 25))
    abv = item["abv"] + rng.choice([0, 0, 0.5, -0.5, 1, -1] if skill > 0.6 else [0, 0.5, -0.5, 1, -1, 1.5])
    abv = max(8, min(20, round(abv * 2) / 2))
    vintage = item["vintage"] + int(round(rng.gauss(0, 0.6 + (1 - skill) * 2)))
    extra = None
    if item.get("extra"):
        extra = item["extra"] if rng.random() < skill * 0.6 else rng.choice(
            [e for e in EXTRAS if e != item["extra"]])
    return {
        "guess_aromas": aromas,
        "guess_flavours": flavours,
        "guess_grape": grape,
        "guess_country": country,
        "guess_region": region,
        "guess_extra": extra,
        "guess_price": float(price),
        "guess_abv": float(abv),
        "guess_vintage": int(vintage),
    }


def make_score(item, bias):
    # Pricier bottles taste better on average, with personal spread.
    base = 6.2 + min(item["price"], 600) / 600 * 2.4
    s = base + bias + rng.gauss(0, 0.55)
    return round(max(4.5, min(9.8, s)) * 10) / 10


# ---------------------------------------------------------------- bottle art

def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def font(path, size, index=0):
    try:
        return ImageFont.truetype(path, size, index=index)
    except Exception:
        return ImageFont.load_default()


SERIF = "/System/Library/Fonts/Supplemental/BigCaslon.ttf"
SANS = "/System/Library/Fonts/Helvetica.ttc"


def wrap(draw, text, fnt, width):
    words = text.split()
    lines, cur = [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=fnt) <= width:
            cur = t
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def bottle_outline(shape, W, H):
    """Left-edge x for each y from top of capsule to base."""
    cx = W / 2
    body_w = 300
    neck_w = 88
    top = 130
    base = 1040
    pts = []
    if shape == "bordeaux":
        shoulder_top, shoulder_bot = 400, 470
    else:
        shoulder_top, shoulder_bot = 330, 560
    for y in range(top, base + 1):
        if y < shoulder_top:
            half = neck_w / 2 + (2 if y > top + 40 else 0)
        elif y < shoulder_bot:
            t = (y - shoulder_top) / (shoulder_bot - shoulder_top)
            # ease-out curve for the shoulder
            t = 1 - (1 - t) ** (2.4 if shape == "bordeaux" else 1.6)
            half = neck_w / 2 + (body_w / 2 - neck_w / 2) * t
        else:
            half = body_w / 2
        pts.append((cx - half, y))
    right = [(W - x, y) for (x, y) in reversed(pts)]
    return pts + right, top, base, body_w, neck_w


def make_bottle(path, spec):
    W, H = 900, 1200
    glass, label_col, capsule, shape = STYLES[spec["style"]]
    glass, label_col, capsule = hexrgb(glass), hexrgb(label_col), hexrgb(capsule)
    dark_label = sum(label_col) < 200

    # background: warm cellar gradient with a glow behind the bottle
    img = Image.new("RGB", (W, H))
    px = img.load()
    top_c, bot_c = (66, 50, 44), (24, 18, 16)
    for y in range(H):
        t = y / H
        c = tuple(int(top_c[i] + (bot_c[i] - top_c[i]) * t) for i in range(3))
        for x in range(W):
            px[x, y] = c
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((W / 2 - 420, 120, W / 2 + 420, 900), fill=(150, 105, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    img = Image.blend(img, Image.composite(glow, img, glow.convert("L").point(lambda v: min(255, v * 2))), 0.55)

    # table plane and shadow
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle((0, 1045, W, H), fill=(38, 28, 24, 255))
    d.line((0, 1045, W, 1045), fill=(90, 70, 58, 140), width=2)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((W / 2 - 250, 1005, W / 2 + 250, 1090), fill=(0, 0, 0, 170))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    img = Image.alpha_composite(img.convert("RGBA"), shadow)

    # bottle
    poly, top, base, body_w, neck_w = bottle_outline(shape, W, H)
    bottle = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bottle)
    bd.polygon(poly, fill=glass + (255,))
    # base curvature
    bd.ellipse((W / 2 - body_w / 2, base - 26, W / 2 + body_w / 2, base + 26), fill=glass + (255,))
    # punt hint
    bd.ellipse((W / 2 - body_w / 2 + 30, base - 16, W / 2 + body_w / 2 - 30, base + 16),
               fill=tuple(max(0, c - 14) for c in glass) + (255,))

    # shading: darker right edge, highlight streak on the left
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for i in range(70):
        a = int(150 * (i / 70) ** 1.6)
        x = W / 2 + body_w / 2 - 70 + i
        sd.line((x, 0, x, H), fill=(0, 0, 0, a))
    for i in range(46):
        a = int(110 * (1 - abs(i - 23) / 23) ** 1.4)
        x = W / 2 - body_w / 2 + 34 + i
        sd.line((x, 0, x, H), fill=(255, 255, 255, a))
    shade = shade.filter(ImageFilter.GaussianBlur(6))
    shade.putalpha(Image.composite(shade.getchannel("A"), Image.new("L", (W, H), 0), bottle.getchannel("A")))
    bottle = Image.alpha_composite(bottle, shade)

    # capsule
    cap = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(cap)
    cd.rectangle((W / 2 - neck_w / 2 - 4, top - 6, W / 2 + neck_w / 2 + 4, top + 118), fill=capsule + (255,))
    cd.rectangle((W / 2 - neck_w / 2 - 6, top - 8, W / 2 + neck_w / 2 + 6, top + 22), fill=capsule + (255,))
    band = (184, 144, 47) if capsule != (184, 144, 47) else (250, 244, 225)
    cd.rectangle((W / 2 - neck_w / 2 - 4, top + 96, W / 2 + neck_w / 2 + 4, top + 100), fill=band + (255,))
    for i in range(30):
        a = int(120 * (i / 30))
        cd.line((W / 2 + neck_w / 2 - 26 + i, top - 8, W / 2 + neck_w / 2 - 26 + i, top + 118), fill=(0, 0, 0, a))
    cd.line((W / 2 - neck_w / 2 + 14, top - 6, W / 2 - neck_w / 2 + 14, top + 118), fill=(255, 255, 255, 70), width=6)
    bottle = Image.alpha_composite(bottle, cap)

    # label
    lx0, lx1 = W / 2 - 122, W / 2 + 122
    ly0, ly1 = (600, 880) if shape == "bordeaux" else (640, 900)
    lab = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lab)
    ld.rounded_rectangle((lx0, ly0, lx1, ly1), radius=5, fill=label_col + (255,))
    ink = (236, 222, 180) if dark_label else (40, 36, 34)
    gold = (184, 144, 47) if not dark_label else (212, 174, 84)
    ld.rectangle((lx0 + 10, ly0 + 10, lx1 - 10, ly1 - 10), outline=gold + (200,), width=2)

    f_prod = font(SANS, 15)
    f_name = font(SERIF, 27)
    f_vint = font(SERIF, 34)
    f_small = font(SANS, 12)
    y = ly0 + 34
    prod = spec["producer"].upper()
    # letter-spaced producer line
    tw = sum(ld.textlength(ch, font=f_prod) + 3 for ch in prod) - 3
    x = W / 2 - tw / 2
    for ch in prod:
        ld.text((x, y), ch, font=f_prod, fill=ink)
        x += ld.textlength(ch, font=f_prod) + 3
    y += 34
    ld.line((W / 2 - 40, y, W / 2 + 40, y), fill=gold, width=1)
    y += 20
    lines = wrap(ld, spec["name"], f_name, 210)
    if len(lines) > 2:
        f_name = font(SERIF, 22)
        lines = wrap(ld, spec["name"], f_name, 210)[:3]
    step = 33 if len(lines) <= 2 else 27
    for line in lines:
        ld.text((W / 2 - ld.textlength(line, font=f_name) / 2, y), line, font=f_name, fill=ink)
        y += step
    y += 8
    vint = str(spec["vintage"])
    ld.text((W / 2 - ld.textlength(vint, font=f_vint) / 2, y), vint, font=f_vint, fill=gold)
    # the two small lines sit anchored to the foot of the label
    reg = f"{spec['region'].upper()} · {spec['country'].upper()}"
    ld.text((W / 2 - ld.textlength(reg, font=f_small) / 2, ly1 - 52), reg, font=f_small, fill=ink)
    ab = f"{spec['abv']:.1f}% VOL · 750 ML".replace(".", ",")
    ld.text((W / 2 - ld.textlength(ab, font=f_small) / 2, ly1 - 34), ab, font=f_small, fill=ink)

    # cylinder shading over the label
    lsh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    lsd = ImageDraw.Draw(lsh)
    for i in range(int(lx1 - lx0)):
        t = i / (lx1 - lx0)
        a = int(90 * (abs(t - 0.42) / 0.58) ** 2)
        lsd.line((lx0 + i, ly0, lx0 + i, ly1), fill=(0, 0, 0, a))
    lsh.putalpha(Image.composite(lsh.getchannel("A"), Image.new("L", (W, H), 0), lab.getchannel("A")))
    lab = Image.alpha_composite(lab, lsh)
    bottle = Image.alpha_composite(bottle, lab)

    img = Image.alpha_composite(img, bottle)

    # vignette and grain
    vig = Image.new("L", (W, H), 0)
    ImageDraw.Draw(vig).ellipse((-200, -150, W + 200, H + 250), fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(220))
    dark = Image.new("RGBA", (W, H), (8, 5, 4, 255))
    img = Image.composite(img, dark, vig.point(lambda v: 90 + v * 165 // 255))
    noise = Image.effect_noise((W, H), 18).convert("RGBA")
    img = Image.blend(img, noise, 0.06)

    img.convert("RGB").save(path, "JPEG", quality=88, optimize=True)


# ---------------------------------------------------------------- tastings

def build_tasting(title, theme, description, host, when, code, bottles, status,
                  current_position, finished_at, ratings_for, note_offset):
    tid = uid()
    created = when - timedelta(days=9, hours=3)
    tasting = {
        "id": tid,
        "group_id": GROUP_ID,
        "host_id": host,
        "title": title,
        "theme": theme,
        "description": description,
        "category": "Vin",
        "status": status,
        "join_code": code,
        "current_position": current_position,
        "config": DEFAULT_CONFIG,
        "scheduled_for": iso(when),
        "finished_at": iso(finished_at) if finished_at else None,
        "created_at": iso(created),
    }
    items, ratings, participants = [], [], []
    for i, (pid, _, _, _) in enumerate(PEOPLE):
        participants.append({
            "id": uid(),
            "tasting_id": tid,
            "user_id": pid,
            "is_host": pid == host,
            "joined_at": iso(when - timedelta(minutes=(0 if pid == host else 14 - 2 * i))),
        })

    item_dir = os.path.join(ROOT, "tastings", tid, "items")
    os.makedirs(item_dir, exist_ok=True)

    for pos, b in enumerate(bottles, start=1):
        (name, producer, grape, country, region, vintage, abv, price,
         aromas, flavours, extra, notes, style) = b
        iid = uid()
        revealed = pos <= ratings_for["revealed"]
        spec = dict(name=name, producer=producer, vintage=vintage, region=region,
                    country=country, abv=abv, style=style)
        img_path = os.path.join(item_dir, f"{iid}.jpg")
        make_bottle(img_path, spec)
        raw = open(img_path, "rb").read()
        item = {
            "id": iid,
            "tasting_id": tid,
            "position": pos,
            "name": name,
            "producer": producer,
            "grape": grape,
            "country": country,
            "region": region,
            "vintage": vintage,
            "abv": abv,
            "price": float(price),
            "currency": "DKK",
            "product_type": "Rødvin",
            "extra": extra,
            "aromas": aromas,
            "flavours": flavours,
            "host_notes": notes,
            "image_path": "image.jpg",
            "image_sha256": hashlib.sha256(raw).hexdigest(),
            "image_bytes": len(raw),
            "revealed_at": iso(when + timedelta(minutes=25 * pos)) if revealed else None,
            "created_at": iso(created + timedelta(minutes=6 * pos)),
        }
        items.append(item)

        raters = PEOPLE if revealed else (
            ratings_for["pending"] if pos == ratings_for["pending_position"] else [])
        for (pid, pname, skill, bias) in raters:
            guess = make_guess(item, skill)
            row = {
                "id": uid(),
                "tasting_item_id": iid,
                "user_id": pid,
                "score": make_score(item, bias),
                "notes": (MY_NOTES[(note_offset + pos - 1) % len(MY_NOTES)] if pid == ME
                          else (rng.choice(["Kan lide den.", "For meget fad.", "Lang eftersmag.",
                                            "Mere syre end jeg havde ventet.", None, None]))),
                **guess,
                "submitted_at": iso(when + timedelta(minutes=25 * pos - rng.randint(3, 14))),
                "points": None,
                "points_total": None,
            }
            if revealed:
                rows, total = score_guess(item, guess, DEFAULT_CONFIG)
                row["points"] = rows
                row["points_total"] = total
            ratings.append(row)
    return tasting, items, participants, ratings


ALL = {"tastings": [], "tasting_items": [], "participants": [], "ratings": []}

def add(t):
    tasting, items, parts, rats = t
    ALL["tastings"].append(tasting)
    ALL["tasting_items"].extend(items)
    ALL["participants"].extend(parts)
    ALL["ratings"].extend(rats)


if os.path.isdir(ROOT):
    shutil.rmtree(ROOT)
os.makedirs(DATA, exist_ok=True)

add(build_tasting(
    "Vulkanvine", "Etna, Vulture og Vesuv",
    "Fire glas fra vulkansk jord. Jonas har hentet dem hjem fra Napoli.",
    IDS["Jonas"], local(2026, 4, 17), "VULK73", T_VULKAN, "finished",
    4, local(2026, 4, 17, 22, 40), {"revealed": 4, "pending": [], "pending_position": None}, 11))

add(build_tasting(
    "Toscana i glasset", "Sangiovese fra syd til nord",
    "Fem glas Toscana. Vi slutter med en Gran Selezione.",
    IDS["Marie"], local(2026, 6, 12), "TOSC88", T_TOSCANA, "finished",
    5, local(2026, 6, 12, 23, 5), {"revealed": 5, "pending": [], "pending_position": None}, 6))

add(build_tasting(
    "Piemonte-aften", "Nebbiolo og naboer",
    "Seks glas fra Langhe og Roero. Tag et ekstra glas med, hvis I vil sammenligne.",
    ME, local(2026, 8, 28), "PIEM42", T_PIEMONTE, "finished",
    6, local(2026, 8, 28, 23, 20), {"revealed": 6, "pending": [], "pending_position": None}, 0))

pending = [p for p in PEOPLE if p[1].split()[0] in ("Marie", "Jonas", "Sofie", "Anders")]
add(build_tasting(
    "Rundt om Italien", "Seks regioner, seks glas",
    "Fra Alperne til Vesuv. Glas 3 og 6 har noget særligt ved sig.",
    ME, local(2026, 9, 20), "ITAL23", T_ITALIEN, "live",
    3, None, {"revealed": 2, "pending": pending, "pending_position": 3}, 15))


# My own half-finished sheet for the glass on the table right now: scored and
# guessed, not yet sent — so the live screen shows a sheet in progress.
live = ALL["tastings"][-1]
glass3 = next(i for i in ALL["tasting_items"] if i["tasting_id"] == live["id"] and i["position"] == 3)
ALL["ratings"].append({
    "id": uid(),
    "tasting_item_id": glass3["id"],
    "user_id": ME,
    "score": 8.4,
    "notes": "Tjære, læder og mørke kirsebær. Stramme tanniner – sydpå, tror jeg.",
    "guess_aromas": ["Tjære", "Læder", "Kirsebær"],
    "guess_flavours": ["Stramme tanniner", "Mørk frugt", "Lakrids"],
    "guess_grape": "Aglianico",
    "guess_country": "Italien",
    "guess_region": "Campania",
    "guess_extra": "Vulkansk jord",
    "guess_price": 300.0,
    "guess_abv": 14.0,
    "guess_vintage": 2019,
    "submitted_at": None,
    "points": None,
    "points_total": None,
})


def dump(name, rows):
    with open(os.path.join(DATA, f"{name}.json"), "w") as f:
        json.dump(rows, f, ensure_ascii=False)


dump("profiles", profiles)
dump("session", [{"id": "current", "user_id": ME}])
dump("groups", [group])
dump("group_members", group_members)
for k, v in ALL.items():
    dump(k, v)

print("seeded", ME)
print("group", GROUP_ID)
for t in ALL["tastings"]:
    print(t["status"], t["title"], t["id"])
