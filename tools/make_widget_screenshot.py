#!/usr/bin/env python3
"""
Compose App Store widget screenshots from the real user-provided iPhone 13
widget/lock-screen composite captures.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


OUT_DIR = Path("fastlane/screenshots_final")
FONT_PATH = "/System/Library/Fonts/Supplemental/Songti.ttc"

BG = (250, 246, 234)
INK = (45, 40, 35)
SUB = (92, 80, 65)

RAW_IMAGE = {
    "zh-Hans": Path("fastlane/screenshots_raw/zh-Hans/IMG_2572.PNG"),
    "zh-Hant": Path("fastlane/screenshots_raw/zh-Hant/IMG_2575.PNG"),
}

COPY = {
    "zh-Hans": {
        "title": "每日经文 · 常驻桌面",
        "subtitle": "桌面小组件 · 锁屏配件",
    },
    "zh-Hant": {
        "title": "每日經文 · 常駐桌面",
        "subtitle": "桌面小元件 · 鎖屏配件",
    },
}


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_PATH, size, index=6 if bold else 3)


def centered_text(draw: ImageDraw.ImageDraw, text: str, text_font, fill, center_x: int, y: int) -> None:
    box = draw.textbbox((0, 0), text, font=text_font)
    draw.text((center_x - (box[2] - box[0]) / 2, y), text, font=text_font, fill=fill)


def paste_scaled(canvas: Image.Image, source: Image.Image, target_width: int, top_y: int) -> None:
    scale = target_width / source.width
    target_height = int(source.height * scale)
    resized = source.resize((target_width, target_height), Image.LANCZOS)
    canvas.paste(resized, ((canvas.width - target_width) // 2, top_y))


def build_iphone(lang: str) -> Image.Image:
    copy = COPY[lang]
    source = Image.open(RAW_IMAGE[lang]).convert("RGB")
    canvas = Image.new("RGB", (1320, 2868), BG)
    draw = ImageDraw.Draw(canvas)

    centered_text(draw, copy["title"], font(78, True), INK, canvas.width // 2, 310)
    centered_text(draw, copy["subtitle"], font(42), SUB, canvas.width // 2, 435)
    paste_scaled(canvas, source, target_width=1080, top_y=530)

    return canvas


def build_ipad(lang: str) -> Image.Image:
    copy = COPY[lang]
    source = Image.open(RAW_IMAGE[lang]).convert("RGB")
    canvas = Image.new("RGB", (2064, 2752), BG)
    draw = ImageDraw.Draw(canvas)

    centered_text(draw, copy["title"], font(104, True), INK, canvas.width // 2, 210)
    centered_text(draw, copy["subtitle"], font(58), SUB, canvas.width // 2, 365)
    paste_scaled(canvas, source, target_width=1660, top_y=560)

    return canvas


def save(lang: str, device: str, image: Image.Image) -> None:
    out_dir = OUT_DIR / lang
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{device}-06_Widgets.png"
    image.save(path, "PNG", optimize=True)
    print(f"wrote {path} ({image.width}x{image.height})")


def main() -> None:
    for lang in ("zh-Hans", "zh-Hant"):
        save(lang, "iPhone 17 Pro Max", build_iphone(lang))
        save(lang, "iPad Pro 13-inch (M5)", build_ipad(lang))


if __name__ == "__main__":
    main()
