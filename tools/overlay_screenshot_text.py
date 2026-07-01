#!/usr/bin/env python3
"""
为 App Store 截图叠加营销文案层。

最终输出匹配 App Store 当前接受的 iPhone / iPad 截图规格。
方案: 固定画布, 顶部文案区 (宣纸米黄底 + 宋体) + 下方 app 截图缩放居中。
"""
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

# === 配置 ===
SRC_DIR = Path("fastlane/screenshots")
OUT_DIR = Path("fastlane/screenshots_final")
OUT_DIR.mkdir(parents=True, exist_ok=True)

# 苹果官方规格 (由 process_device 按设备设置)
CANVAS_W, CANVAS_H = 1290, 2796
HEADER_HEIGHT = 390

# 字体: 宋体 (经文气质)
FONT_PATH = "/System/Library/Fonts/Supplemental/Songti.ttc"

# 浅宣纸底色 + 墨色文字。外层广告背景比古籍截图更浅, 让真实截图更突出。
BG_COLOR = (250, 246, 234)       # 浅宣纸 #FAF6EA
TITLE_COLOR = (45, 40, 35)       # 墨色
SUBTITLE_COLOR = (92, 80, 65)    # 深淡墨, 提高浅宣纸背景上的可读性

TITLE_FONT_SIZE = 76
SUBTITLE_FONT_SIZE = 42
TITLE_TO_SUBTITLE_GAP = 26

# 营销文案
COPY = {
    "zh-Hans": {
        "01_Home":       ("经文科判 · 一览分明", "十卷经文 · 读听随宜"),
        "05_Reading":    ("沉浸阅读 · 经文疏朗", "字号可调 · 排版清净"),
        "02_Listening":  ("读诵听闻 · 随时聆听", "后台播放 · 锁屏控制"),
        "03_Favorites":  ("书签收藏 · 反复参究", "常读之处 · 随取随在"),
        "04_Settings":   ("每日经文 · 清净设置", "提醒 · 小组件 · 字号"),
    },
    "zh-Hant": {
        "01_Home":       ("經文科判 · 一覽分明", "十卷經文 · 讀聽隨宜"),
        "05_Reading":    ("沉浸閱讀 · 經文疏朗", "字級可調 · 排版清淨"),
        "02_Listening":  ("讀誦聽聞 · 隨時聆聽", "背景播放 · 鎖屏控制"),
        "03_Favorites":  ("書籤收藏 · 反覆參究", "常讀之處 · 隨取隨在"),
        "04_Settings":   ("每日經文 · 清淨設定", "提醒 · 小元件 · 字級"),
    },
}

# 发布顺序 (转化力排序)
PUBLISH_ORDER = ["01_Home", "05_Reading", "02_Listening", "03_Favorites", "04_Settings"]


def load_font(path, size, bold=True):
    try:
        index = 6 if bold else 3   # Songti.ttc: 6=Black, 3=Regular
        return ImageFont.truetype(path, size, index=index)
    except Exception:
        return ImageFont.truetype(path, size)


def render_centered(draw, text, font, color, center_x, top_y):
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    x = center_x - text_w // 2 - bbox[0]
    draw.text((x, top_y), text, font=font, fill=color)
    return top_y + text_h


def clean_ipad_window(src):
    """Remove iPad simulator wallpaper around the floating app window."""
    if src.size != (2064, 2752):
        return src

    # The iPad snapshots are captured as floating windows. Keep the real app
    # window pixels, but replace the surrounding system wallpaper with the same
    # App Store canvas background used by the rest of the ad image.
    window_box = (116, 334, 1914, 2752)
    radius = 86
    cleaned = Image.new("RGB", src.size, BG_COLOR)
    mask = Image.new("L", src.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(window_box, radius=radius, fill=255)
    cleaned.paste(src, (0, 0), mask)
    return cleaned.crop(window_box)


def process_one(src_path, out_path, title, subtitle, clean_ipad_background=False):
    src = Image.open(src_path).convert("RGB")
    if clean_ipad_background:
        src = clean_ipad_window(src)

    # 创建固定画布
    canvas = Image.new("RGB", (CANVAS_W, CANVAS_H), BG_COLOR)

    # 缩放 app 截图到文案区下方的可用区域,保持宽比
    avail_w = CANVAS_W
    avail_h = CANVAS_H - HEADER_HEIGHT
    src_w, src_h = src.size
    scale = min(avail_w / src_w, avail_h / src_h)
    new_w = int(src_w * scale)
    new_h = int(src_h * scale)
    resized = src.resize((new_w, new_h), Image.LANCZOS)
    # 水平居中, 垂直从文案区下方开始
    paste_x = (CANVAS_W - new_w) // 2
    paste_y = HEADER_HEIGHT + (avail_h - new_h) // 2
    canvas.paste(resized, (paste_x, paste_y))

    # 绘制文案
    draw = ImageDraw.Draw(canvas)
    title_font = load_font(FONT_PATH, TITLE_FONT_SIZE, bold=True)
    sub_font = load_font(FONT_PATH, SUBTITLE_FONT_SIZE, bold=False)

    title_bbox = draw.textbbox((0, 0), title, font=title_font)
    title_h = title_bbox[3] - title_bbox[1]
    sub_bbox = draw.textbbox((0, 0), subtitle, font=sub_font)
    sub_h = sub_bbox[3] - sub_bbox[1]

    total_h = title_h + TITLE_TO_SUBTITLE_GAP + sub_h
    start_y = (HEADER_HEIGHT - total_h) // 2 - 8
    center_x = CANVAS_W // 2

    title_bottom = render_centered(draw, title, title_font, TITLE_COLOR, center_x, start_y)
    render_centered(draw, subtitle, sub_font, SUBTITLE_COLOR,
                    center_x, title_bottom + TITLE_TO_SUBTITLE_GAP)

    canvas.save(out_path, "PNG", optimize=True)


def main():
    # === iPhone 17 Pro Max output, composed from iPhone 13 Pro Max raw captures ===
    process_device(
        device_prefix="iPhone 17 Pro Max",
        canvas=(1320, 2868),
        header_height=390,
        title_size=76,
        subtitle_size=42,
        gap=26,
        source_device_prefix="iPhone 13 Pro Max",
    )

    # === iPad Pro 13" (M5): 官方规格 2064×2752 ===
    process_device(
        device_prefix="iPad Pro 13-inch (M5)",
        canvas=(2064, 2752),
        header_height=520,
        title_size=118,
        subtitle_size=66,
        gap=40,
    )

    print(f"\n✅ 输出: {OUT_DIR}/")


def process_device(
    device_prefix,
    canvas,
    header_height,
    title_size,
    subtitle_size,
    gap,
    source_device_prefix=None,
):
    """处理某设备的全部截图。"""
    global CANVAS_W, CANVAS_H, HEADER_HEIGHT, TITLE_FONT_SIZE, SUBTITLE_FONT_SIZE, TITLE_TO_SUBTITLE_GAP
    CANVAS_W, CANVAS_H = canvas
    HEADER_HEIGHT = header_height
    TITLE_FONT_SIZE = title_size
    SUBTITLE_FONT_SIZE = subtitle_size
    TITLE_TO_SUBTITLE_GAP = gap
    source_device_prefix = source_device_prefix or device_prefix

    for lang in ["zh-Hans", "zh-Hant"]:
        lang_out = OUT_DIR / lang
        lang_out.mkdir(parents=True, exist_ok=True)
        src_lang_dir = SRC_DIR / lang
        print(f"\n=== {device_prefix} / {lang} ===")
        for new_idx, page_key in enumerate(PUBLISH_ORDER, start=1):
            src = src_lang_dir / f"{source_device_prefix}-{page_key}.png"
            if not src.exists():
                print(f"  ✗ 缺失: {src}")
                continue
            title, subtitle = COPY[lang][page_key]
            page_name = page_key.split("_", 1)[1]
            out = lang_out / f"{device_prefix}-{new_idx:02d}_{page_name}.png"
            process_one(
                src,
                out,
                title,
                subtitle,
                clean_ipad_background=device_prefix.startswith("iPad"),
            )
            print(f"  ✓ {out.name}  ({CANVAS_W}×{CANVAS_H})")


if __name__ == "__main__":
    main()
