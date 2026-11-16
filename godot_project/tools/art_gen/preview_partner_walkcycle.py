#!/usr/bin/env python3
"""Build a labelled contact sheet for visually checking eight runtime walk frames."""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frames", required=True, type=Path)
    parser.add_argument("--prefix", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    sample = Image.open(args.frames / f"{args.prefix}_Walk0.png").convert("RGBA")
    w, h = sample.size
    scale = max(2, min(6, 512 // max(w, h)))
    sheet = Image.new("RGB", (4 * w * scale, 2 * h * scale), (34, 40, 48))
    draw = ImageDraw.Draw(sheet)
    for i in range(8):
        x, y = (i % 4) * w * scale, (i // 4) * h * scale
        bg = (220, 218, 207) if i % 2 == 0 else (42, 48, 57)
        sheet.paste(bg, (x, y, x + w * scale, y + h * scale))
        frame = Image.open(args.frames / f"{args.prefix}_Walk{i}.png").convert("RGBA")
        frame = frame.resize((w * scale, h * scale), Image.Resampling.NEAREST)
        sheet.paste(frame, (x, y), frame)
        draw.text((x + 4, y + 4), f"Walk{i}", fill=(220, 30, 30) if i % 2 else (30, 30, 30))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output)


if __name__ == "__main__":
    main()
