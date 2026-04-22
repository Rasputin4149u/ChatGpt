#!/usr/bin/env python3
"""
prepare_popup_assets.py

Reusable helper for extracting a fixed popup area from screenshots or prepared frames.

What it does
- crops the popup from one image or many images
- optionally crops a fixed clock area too
- can build popup-only and clock-only contact sheets
- writes a manifest.json

Dependencies
- Python 3.10+
- Pillow

Example
python prepare_popup_assets.py ^
  --input "C:\work\prepared\frames" ^
  --out "C:\work\popup_ready" ^
  --popup-rect 1040,345,470,260 ^
  --clock-rect 1450,760,120,70
"""

from __future__ import annotations

import argparse
import json
import math
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable, Optional

from PIL import Image, ImageOps, ImageDraw


@dataclass
class CropInfo:
    source: str
    popup_path: str
    clock_path: Optional[str] = None


def parse_rect(value: str) -> tuple[int, int, int, int]:
    parts = [p.strip() for p in value.split(",")]
    if len(parts) != 4:
        raise argparse.ArgumentTypeError("rect must be x,y,w,h")
    try:
        x, y, w, h = map(int, parts)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("rect values must be integers") from exc
    if w <= 0 or h <= 0:
        raise argparse.ArgumentTypeError("rect width/height must be > 0")
    return x, y, w, h


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def safe_crop(img: Image.Image, rect: tuple[int, int, int, int]) -> Image.Image:
    x, y, w, h = rect
    x1 = max(0, x)
    y1 = max(0, y)
    x2 = min(img.width, x + w)
    y2 = min(img.height, y + h)
    if x1 >= x2 or y1 >= y2:
        raise ValueError(f"Crop rect {rect} is outside image bounds {img.width}x{img.height}")
    return img.crop((x1, y1, x2, y2))


def put_label(image: Image.Image, label: str) -> Image.Image:
    pad = 24
    out = ImageOps.expand(image, border=(0, 0, 0, pad), fill="white")
    draw = ImageDraw.Draw(out)
    draw.text((6, image.height + 4), label, fill="black")
    return out


def create_contact_sheet(
    images: Iterable[Path],
    out_path: Path,
    cols: int = 4,
    thumb_width: int = 360,
) -> None:
    paths = list(images)
    if not paths:
        return

    thumbs: list[Image.Image] = []
    max_h = 0
    for path in paths:
        img = Image.open(path).convert("RGB")
        ratio = thumb_width / img.width
        thumb = img.resize((thumb_width, max(1, int(img.height * ratio))))
        thumb = put_label(thumb, path.stem)
        thumbs.append(thumb)
        max_h = max(max_h, thumb.height)

    rows = math.ceil(len(thumbs) / cols)
    sheet = Image.new("RGB", (cols * thumb_width, rows * max_h), "white")

    for idx, thumb in enumerate(thumbs):
        row = idx // cols
        col = idx % cols
        sheet.paste(thumb, (col * thumb_width, row * max_h))

    sheet.save(out_path)


def iter_input_images(path: Path) -> list[Path]:
    if path.is_file():
        return [path]
    exts = {".png", ".jpg", ".jpeg", ".bmp", ".webp"}
    return sorted(p for p in path.iterdir() if p.suffix.lower() in exts)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="Input image file or folder")
    parser.add_argument("--out", required=True, help="Output folder")
    parser.add_argument("--popup-rect", required=True, type=parse_rect, help="Popup crop rect x,y,w,h")
    parser.add_argument("--clock-rect", type=parse_rect, default=None, help="Optional clock crop rect x,y,w,h")
    parser.add_argument("--contact-cols", type=int, default=4)
    parser.add_argument("--thumb-width", type=int, default=360)
    args = parser.parse_args()

    input_path = Path(args.input)
    out_dir = Path(args.out)
    popup_dir = out_dir / "popup_crops"
    clock_dir = out_dir / "clock_crops"

    ensure_dir(out_dir)
    ensure_dir(popup_dir)
    if args.clock_rect:
        ensure_dir(clock_dir)

    images = iter_input_images(input_path)
    manifest: list[CropInfo] = []

    for idx, src in enumerate(images):
        img = Image.open(src).convert("RGB")
        popup = safe_crop(img, args.popup_rect)
        popup_path = popup_dir / f"{idx:04d}_{src.stem}_popup.png"
        popup.save(popup_path)

        clock_path_str = None
        if args.clock_rect:
            clock = safe_crop(img, args.clock_rect)
            clock_path = clock_dir / f"{idx:04d}_{src.stem}_clock.png"
            clock.save(clock_path)
            clock_path_str = str(clock_path)

        manifest.append(
            CropInfo(
                source=str(src),
                popup_path=str(popup_path),
                clock_path=clock_path_str,
            )
        )

    create_contact_sheet([Path(x.popup_path) for x in manifest], out_dir / "popup_contact_sheet.png", args.contact_cols, args.thumb_width)

    if args.clock_rect:
        create_contact_sheet([Path(x.clock_path) for x in manifest if x.clock_path], out_dir / "clock_contact_sheet.png", args.contact_cols, args.thumb_width)

    (out_dir / "manifest.json").write_text(
        json.dumps(
            {
                "input": str(input_path),
                "popup_rect": args.popup_rect,
                "clock_rect": args.clock_rect,
                "items": [asdict(x) for x in manifest],
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    print(f"Prepared {len(manifest)} popup crops in: {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
