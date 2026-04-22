#!/usr/bin/env python3
"""
prepare_video_for_analysis.py

Reusable helper for preparing a video for manual/AI analysis.

What it does
- extracts frames every N seconds
- optionally limits the time range
- creates a contact sheet
- optionally crops a fixed clock area from every extracted frame
- writes a manifest.json with timestamps and output paths

Dependencies
- Python 3.10+
- Pillow
- OpenCV (cv2)

Example
python prepare_video_for_analysis.py ^
  --video "C:\work\TestFlow.mp4" ^
  --out "C:\work\prepared" ^
  --every-seconds 1.0 ^
  --contact-cols 4 ^
  --clock-rect 1450,760,120,70
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable, Optional

import cv2
from PIL import Image, ImageOps, ImageDraw


@dataclass
class FrameInfo:
    index: int
    ms: int
    seconds: float
    frame_path: str
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


def safe_crop(img_bgr, rect: tuple[int, int, int, int]):
    x, y, w, h = rect
    h_img, w_img = img_bgr.shape[:2]
    x1 = max(0, x)
    y1 = max(0, y)
    x2 = min(w_img, x + w)
    y2 = min(h_img, y + h)
    if x1 >= x2 or y1 >= y2:
        raise ValueError(f"Crop rect {rect} is outside image bounds {w_img}x{h_img}")
    return img_bgr[y1:y2, x1:x2]


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def bgr_to_pil(img_bgr) -> Image.Image:
    rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    return Image.fromarray(rgb)


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
        raise ValueError("No images were provided for contact sheet")

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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--video", required=True, help="Path to input video")
    parser.add_argument("--out", required=True, help="Output folder")
    parser.add_argument("--every-seconds", type=float, default=1.0, help="Extract every N seconds")
    parser.add_argument("--start-seconds", type=float, default=0.0, help="Start at this second")
    parser.add_argument("--end-seconds", type=float, default=None, help="Optional end time")
    parser.add_argument("--contact-cols", type=int, default=4, help="Columns in contact sheet")
    parser.add_argument("--thumb-width", type=int, default=360, help="Thumb width in contact sheet")
    parser.add_argument("--clock-rect", type=parse_rect, default=None, help="Optional x,y,w,h crop for floating clock")
    args = parser.parse_args()

    video_path = Path(args.video)
    out_dir = Path(args.out)
    frames_dir = out_dir / "frames"
    clock_dir = out_dir / "clock_crops"

    ensure_dir(out_dir)
    ensure_dir(frames_dir)
    if args.clock_rect:
        ensure_dir(clock_dir)

    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        print(f"ERROR: cannot open video: {video_path}", file=sys.stderr)
        return 1

    fps = cap.get(cv2.CAP_PROP_FPS) or 0
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    duration_seconds = (total_frames / fps) if fps else None

    current_ms = int(args.start_seconds * 1000)
    step_ms = max(1, int(args.every_seconds * 1000))
    end_ms = int(args.end_seconds * 1000) if args.end_seconds is not None else None

    manifest: list[FrameInfo] = []
    frame_index = 0

    while True:
        if end_ms is not None and current_ms > end_ms:
            break

        cap.set(cv2.CAP_PROP_POS_MSEC, current_ms)
        ok, frame = cap.read()
        if not ok or frame is None:
            break

        label = f"{frame_index:04d}_{current_ms:08d}ms"
        frame_path = frames_dir / f"{label}.png"
        bgr_to_pil(frame).save(frame_path)

        clock_path_str = None
        if args.clock_rect:
            clock = safe_crop(frame, args.clock_rect)
            clock_path = clock_dir / f"{label}_clock.png"
            bgr_to_pil(clock).save(clock_path)
            clock_path_str = str(clock_path)

        manifest.append(
            FrameInfo(
                index=frame_index,
                ms=current_ms,
                seconds=round(current_ms / 1000.0, 3),
                frame_path=str(frame_path),
                clock_path=clock_path_str,
            )
        )

        frame_index += 1
        current_ms += step_ms

        if duration_seconds is not None and current_ms > int(duration_seconds * 1000):
            break

    cap.release()

    if manifest:
        create_contact_sheet(
            [Path(item.frame_path) for item in manifest],
            out_dir / "contact_sheet.png",
            cols=args.contact_cols,
            thumb_width=args.thumb_width,
        )

    metadata = {
        "video": str(video_path),
        "fps": fps,
        "total_frames": total_frames,
        "duration_seconds": duration_seconds,
        "every_seconds": args.every_seconds,
        "start_seconds": args.start_seconds,
        "end_seconds": args.end_seconds,
        "clock_rect": args.clock_rect,
        "frames": [asdict(item) for item in manifest],
    }
    (out_dir / "manifest.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")

    print(f"Prepared {len(manifest)} frames in: {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
