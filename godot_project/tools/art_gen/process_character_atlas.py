#!/usr/bin/env python3
"""Slice and register a generated 12x3 character atlas to the game's frame contract."""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SKILL_SCRIPTS = Path.home() / ".codex" / "skills" / "generate2dsprite" / "scripts"
if SKILL_SCRIPTS.is_dir():
    sys.path.insert(0, str(SKILL_SCRIPTS))
try:
    import forge_core
except ImportError as exc:
    raise RuntimeError("Install/use the generate2dsprite skill to apply its native-alpha hygiene step") from exc

COLS, ROWS = 12, 3
FRAME_W, FRAME_H = 72, 112
PIVOT_X, PIVOT_Y = 36, 108
TARGET_STAND_H = 100
MAX_BODY_W = 64
ALPHA_THRESHOLD = 16


def alpha_bbox(cell: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(cell.getchannel("A"))
    ys, xs = np.where(alpha > ALPHA_THRESHOLD)
    if xs.size < 40:
        raise ValueError("atlas cell has no usable character pixels")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def process(src: Path, dst: Path) -> dict:
    source = Image.open(src).convert("RGBA")
    source, hygiene = forge_core.alpha_hygiene(source, mode="both")
    w, h = source.size
    boxes: list[list[tuple[int, int, int, int]]] = []
    cells: list[list[Image.Image]] = []
    for row in range(ROWS):
        row_cells, row_boxes = [], []
        y0, y1 = round(row * h / ROWS), round((row + 1) * h / ROWS)
        for col in range(COLS):
            x0, x1 = round(col * w / COLS), round((col + 1) * w / COLS)
            cell = source.crop((x0, y0, x1, y1))
            box = alpha_bbox(cell)
            row_cells.append(cell)
            row_boxes.append(box)
        cells.append(row_cells)
        boxes.append(row_boxes)

    standing_heights = [boxes[row][0][3] - boxes[row][0][1] for row in range(ROWS)]
    median_standing_h = float(np.median(standing_heights))
    widest = max(box[2] - box[0] for row in boxes for box in row)
    scale = min(TARGET_STAND_H / median_standing_h, MAX_BODY_W / widest)

    out = Image.new("RGBA", (FRAME_W * COLS, FRAME_H * ROWS), (0, 0, 0, 0))
    frame_sizes: list[list[list[int]]] = []
    frame_widths: list[list[int]] = []
    for row in range(ROWS):
        size_row, width_row = [], []
        for col in range(COLS):
            cell = cells[row][col]
            x0, y0, x1, y1 = boxes[row][col]
            margin = 2
            crop_box = (max(0, x0 - margin), max(0, y0 - margin),
                        min(cell.width, x1 + margin), min(cell.height, y1 + margin))
            body = cell.crop(crop_box)
            scaled_size = (max(1, round(body.width * scale)), max(1, round(body.height * scale)))
            body = body.resize(scaled_size, Image.Resampling.LANCZOS)

            # Place the measured opaque foot line on the common ground anchor.
            body_base = round((y1 - crop_box[1]) * scale)
            body_center = round(((x0 + x1) * 0.5 - crop_box[0]) * scale)
            px, py = PIVOT_X - body_center, PIVOT_Y - body_base
            if px < 0 or py < 0 or px + body.width > FRAME_W or py + body.height > FRAME_H:
                raise ValueError(f"frame r{row}c{col} exceeds {FRAME_W}x{FRAME_H} at ({px},{py})")
            out.alpha_composite(body, (col * FRAME_W + px, row * FRAME_H + py))
            size_row.append([body.width, body.height])
            width_row.append(x1 - x0)
        frame_sizes.append(size_row)
        frame_widths.append(width_row)

    # Crouch frames are direction-neutral in NightPlayer and must not pop on turns.
    for col in range(9, 12):
        for row in (1, 2):
            region = out.crop((col * FRAME_W, 0, (col + 1) * FRAME_W, FRAME_H))
            out.paste(region, (col * FRAME_W, row * FRAME_H))

    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst, optimize=True)
    frame_dir = dst.with_name(f"{dst.stem}_frames")
    frame_dir.mkdir(parents=True, exist_ok=True)
    for row in range(ROWS):
        for col in range(COLS):
            frame = out.crop((col * FRAME_W, row * FRAME_H,
                              (col + 1) * FRAME_W, (row + 1) * FRAME_H))
            frame.save(frame_dir / f"r{row:02d}_c{col:02d}.png", optimize=True)
    data = {
        "schema": "winter-iron.character-atlas.v1",
        "source": src.name,
        "source_sha256": hashlib.sha256(src.read_bytes()).hexdigest(),
        "output": dst.name,
        "frames_dir": frame_dir.name,
        "output_sha256": hashlib.sha256(dst.read_bytes()).hexdigest(),
        "source_size": [w, h],
        "output_size": [out.width, out.height],
        "grid": [COLS, ROWS],
        "frame_size": [FRAME_W, FRAME_H],
        "pivot": [PIVOT_X, PIVOT_Y],
        "alpha_threshold": ALPHA_THRESHOLD,
        "scale": round(scale, 6),
        "median_idle_source_height": median_standing_h,
        "max_source_body_width": widest,
        "alpha_hygiene": hygiene,
        "frame_body_sizes": frame_sizes,
        "special_frames_unified_across_rows": list(range(9, 12)),
        "warnings": [],
    }
    dst.with_suffix(".json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return data


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(process(args.input, args.output), ensure_ascii=False))


if __name__ == "__main__":
    main()
