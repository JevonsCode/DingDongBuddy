#!/usr/bin/env python3
"""Build unread Windows tray icons that remain visible on any taskbar."""

from pathlib import Path

try:
    from PIL import Image, ImageFilter
except ImportError as error:
    raise SystemExit("Pillow is required: python3 -m pip install Pillow") from error


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "Assets" / "DingDongIP"
OUTPUT_DIR = ROOT / "windows" / "runner" / "resources"
CANVAS_SIZE = 256
OUTLINE_WIDTH = 14
ICON_SIZES = [
    (16, 16),
    (20, 20),
    (24, 24),
    (32, 32),
    (40, 40),
    (48, 48),
    (64, 64),
    (256, 256),
]


def outlined_art(source_path: Path) -> Image.Image:
    source = Image.open(source_path).convert("RGBA")
    bounds = source.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError(f"Source has no visible pixels: {source_path}")
    source = source.crop(bounds)

    margin = OUTLINE_WIDTH + 4
    scale = min(
        (CANVAS_SIZE - 2 * margin) / source.width,
        (CANVAS_SIZE - 2 * margin) / source.height,
    )
    art = source.resize(
        (round(source.width * scale), round(source.height * scale)),
        Image.Resampling.LANCZOS,
    )
    left = (CANVAS_SIZE - art.width) // 2
    top = (CANVAS_SIZE - art.height) // 2

    alpha = Image.new("L", (CANVAS_SIZE, CANVAS_SIZE))
    alpha.paste(art.getchannel("A"), (left, top))
    outline_alpha = alpha.filter(
        ImageFilter.MaxFilter(OUTLINE_WIDTH * 2 + 1),
    )
    outline = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (248, 248, 248, 0))
    outline.putalpha(outline_alpha)

    result = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE))
    result.alpha_composite(outline)
    result.alpha_composite(art, (left, top))
    return result


def main() -> None:
    for frame_suffix in ("", "2"):
        source_path = SOURCE_DIR / f"ding{frame_suffix}.png"
        output_path = OUTPUT_DIR / f"tray_icon_adaptive_unread{frame_suffix}.ico"
        outlined_art(source_path).save(
            output_path,
            format="ICO",
            sizes=ICON_SIZES,
            bitmap_format="png",
        )
        print(output_path.relative_to(ROOT))


if __name__ == "__main__":
    main()
