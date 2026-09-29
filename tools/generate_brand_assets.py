#!/usr/bin/env python3
"""Generates every Android launcher and store image from one description.

The app icon is drawn rather than hand-exported so it stays consistent across
the five Android densities, the adaptive-icon layers, the splash logo and the
store graphics — and so a change of brand colour is one edit here instead of
eleven binary files.

Usage (the only dependency is Pillow):

    python3 -m venv /tmp/imgen
    /tmp/imgen/bin/pip install Pillow
    /tmp/imgen/bin/python tools/generate_brand_assets.py

Outputs:

    android/app/src/main/res/mipmap-*/ic_launcher.png
    android/app/src/main/res/mipmap-*/ic_launcher_round.png
    android/app/src/main/res/mipmap-*/ic_launcher_foreground.png
    android/app/src/main/res/drawable-nodpi/splash_logo.png
    docs/store/icon-512.png
    docs/store/feature-graphic.png
"""

from __future__ import annotations

import os
from PIL import Image, ImageDraw

# ── Brand ────────────────────────────────────────────────────────────────────
BRAND = (0x4F, 0x46, 0xE5, 255)      # indigo, the app's colour seed
BRAND_DEEP = (0x37, 0x2F, 0xC7, 255)  # for the subtle vertical shade
ACCENT = (0x0E, 0xA5, 0xE9, 255)      # sky, the app's accent
PAPER = (0xFF, 0xFF, 0xFF, 255)
PAPER_FOLD = (0xC7, 0xD2, 0xFE, 255)
INK = (0x94, 0xA3, 0xB8, 255)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
STORE = os.path.join(ROOT, "docs", "store")

SS = 4  # supersampling factor: everything is drawn 4x and scaled down

DENSITIES = {
    "mdpi": 1,
    "hdpi": 1.5,
    "xhdpi": 2,
    "xxhdpi": 3,
    "xxxhdpi": 4,
}


def _canvas(size: int, colour=None) -> Image.Image:
    image = Image.new("RGBA", (size * SS, size * SS), colour or (0, 0, 0, 0))
    return image


def _document(draw: ImageDraw.ImageDraw, box, scale: float) -> None:
    """Draws the sheet glyph: a page with a folded corner and text lines.

    `box` is the (x, y, w, h) of the page in output pixels and `scale` is the
    supersampling factor, so every measurement below is in output pixels.
    """
    x, y, w, h = [value * scale for value in box]
    fold = 16 * scale

    # The page: a rectangle with the top-right corner cut away. The cut is
    # drawn as a polygon so the fold can be a separate, lighter triangle.
    draw.polygon(
        [
            (x, y),
            (x + w - fold, y),
            (x + w, y + fold),
            (x + w, y + h),
            (x, y + h),
        ],
        fill=PAPER,
    )
    draw.polygon(
        [
            (x + w - fold, y),
            (x + w - fold, y + fold),
            (x + w, y + fold),
        ],
        fill=PAPER_FOLD,
    )

    # Two text lines and one accent line: enough to read as "a document" at
    # 48 px, which is the only size that really matters.
    line_height = 5 * scale
    radius = line_height / 2
    left = x + 9 * scale
    widths = (w - 20 * scale, w - 20 * scale, w * 0.42)
    colours = (ACCENT, INK, INK)
    top = y + h * 0.40
    for index, (width, colour) in enumerate(zip(widths, colours)):
        line_top = top + index * h * 0.155
        draw.rounded_rectangle(
            [left, line_top, left + width, line_top + line_height],
            radius=radius,
            fill=colour,
        )


def icon_square(size: int) -> Image.Image:
    """The legacy icon: brand background, page glyph centred."""
    image = _canvas(size)
    draw = ImageDraw.Draw(image)
    radius = size * 0.22 * SS
    draw.rounded_rectangle(
        [0, 0, size * SS - 1, size * SS - 1],
        radius=radius,
        fill=BRAND,
    )
    glyph = size * 0.46
    _document(draw, ((size - glyph) / 2, (size - glyph * 1.28) / 2, glyph, glyph * 1.28), SS)
    return image.resize((size, size), Image.LANCZOS)


def icon_round(size: int) -> Image.Image:
    """The legacy round icon: same glyph inside a circle."""
    image = _canvas(size)
    draw = ImageDraw.Draw(image)
    draw.ellipse([0, 0, size * SS - 1, size * SS - 1], fill=BRAND)
    glyph = size * 0.42
    _document(draw, ((size - glyph) / 2, (size - glyph * 1.28) / 2, glyph, glyph * 1.28), SS)
    return image.resize((size, size), Image.LANCZOS)


def icon_foreground(size: int) -> Image.Image:
    """The adaptive-icon foreground.

    The canvas is 108 dp and launchers may crop to the inner 72 dp, so the
    glyph is kept well inside that circle: a mark that touches the edge of the
    safe zone gets its corners cut off on a round-masked launcher.
    """
    image = _canvas(size)
    draw = ImageDraw.Draw(image)
    glyph = size * 0.40
    _document(draw, ((size - glyph) / 2, (size - glyph * 1.28) / 2, glyph, glyph * 1.28), SS)
    return image.resize((size, size), Image.LANCZOS)


def splash_logo(size: int = 512) -> Image.Image:
    """A white page mark for the launch screen, on transparency."""
    image = _canvas(size)
    draw = ImageDraw.Draw(image)
    # Android 12 masks the splash icon into a circle, so the page keeps a
    # generous margin: a mark that fills the canvas loses its corners.
    glyph = size * 0.52
    _document(draw, ((size - glyph) / 2, (size - glyph * 1.28) / 2, glyph, glyph * 1.28), SS)
    return image.resize((size, size), Image.LANCZOS)


def feature_graphic(width: int = 1024, height: int = 500) -> Image.Image:
    """The Google Play feature graphic: brand field, mark and wordmark."""
    image = Image.new("RGBA", (width, height), BRAND)
    draw = ImageDraw.Draw(image)
    # A soft diagonal band keeps the flat field from looking like a placeholder.
    draw.polygon(
        [(width * 0.58, height), (width, height), (width, height * 0.05)],
        fill=(0x43, 0x3A, 0xDB, 255),
    )

    glyph = height * 0.42
    glyph_x = width * 0.085
    _document(draw, (glyph_x, (height - glyph * 1.28) / 2, glyph, glyph * 1.28), 1)

    text_left = glyph_x + glyph + width * 0.045
    available = width - text_left - width * 0.09
    # Two lines so the letters can stay large; the unit is derived from the
    # long line, which is what decides whether the text fits at all.
    _wordmark(draw, text_left, height, available)
    return image


def _wordmark(
    draw: ImageDraw.ImageDraw,
    left: float,
    height: float,
    available: float,
) -> None:
    """Draws "Wonder" / "CV Builder" / strapline, sized to fit `available`.

    A font file would be nicer, but the only fonts guaranteed present here are
    the app's own TTFs, and depending on them would make the store graphics
    fail on a machine without the Flutter asset tree. Block letters keep the
    generator dependency-free — and they are measured, so they never overflow.
    """
    line_one = "WONDER"
    line_two = "CV BUILDER"
    strapline = "OFFLINE CV"

    unit = available / (_text_width(line_two))
    unit = min(unit, height * 0.030)

    top = height * 0.28
    _block_text(draw, left, top, line_one, unit, PAPER)
    _block_text(draw, left, top + unit * 9, line_two, unit, ACCENT)

    rule_y = top + unit * 17.5
    draw.rectangle(
        [left, rule_y, left + unit * 12, rule_y + unit * 0.7],
        fill=(0xC7, 0xD2, 0xFE, 255),
    )
    _block_text(draw, left, rule_y + unit * 2.6, strapline, unit * 0.62, (0xC7, 0xD2, 0xFE, 255))


def _text_width(text: str, unit: float = 1.0) -> float:
    """Width of a block-text string in units of the letter unit."""
    return len(text) * 6 * unit


_GLYPHS = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
    " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
}


def _block_text(draw, x: float, y: float, text: str, unit: float, colour) -> float:
    for character in text:
        glyph = _GLYPHS.get(character, _GLYPHS[" "])
        for row, line in enumerate(glyph):
            for column, cell in enumerate(line):
                if cell == "1":
                    left = x + column * unit
                    top = y + row * unit
                    draw.rectangle([left, top, left + unit * 0.92, top + unit * 0.92], fill=colour)
        x += unit * 6
    return x


def main() -> None:
    for density, factor in DENSITIES.items():
        folder = os.path.join(RES, f"mipmap-{density}")
        os.makedirs(folder, exist_ok=True)
        icon_square(int(48 * factor)).save(os.path.join(folder, "ic_launcher.png"))
        icon_round(int(48 * factor)).save(os.path.join(folder, "ic_launcher_round.png"))
        icon_foreground(int(108 * factor)).save(
            os.path.join(folder, "ic_launcher_foreground.png")
        )
        print(f"launcher images written for {density}")

    drawable = os.path.join(RES, "drawable-nodpi")
    os.makedirs(drawable, exist_ok=True)
    splash_logo().save(os.path.join(drawable, "splash_logo.png"))

    os.makedirs(STORE, exist_ok=True)
    icon_square(512).save(os.path.join(STORE, "icon-512.png"))
    feature_graphic().save(os.path.join(STORE, "feature-graphic.png"))
    print("store graphics written to docs/store/")


if __name__ == "__main__":
    main()
