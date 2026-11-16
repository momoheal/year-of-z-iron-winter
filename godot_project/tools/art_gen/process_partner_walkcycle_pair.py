#!/usr/bin/env python3
"""Combine two transparent 2x2 pose boards into one eight-frame walk cycle."""
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
    raise RuntimeError("Install/use generate2dsprite skill for native alpha hygiene") from exc

THRESHOLD = 16
PADDING = 4


def bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.where(alpha > THRESHOLD)
    if xs.size < 40:
        raise ValueError("walk-cycle cell has no usable subject pixels")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def crop_board(src: Path):
    board, hygiene = forge_core.alpha_hygiene(Image.open(src).convert("RGBA"), mode="both")
    w, h = board.size
    cells, boxes = [], []
    for row in range(2):
        for col in range(2):
            x0, x1 = round(col * w / 2), round((col + 1) * w / 2)
            y0, y1 = round(row * h / 2), round((row + 1) * h / 2)
            cell = board.crop((x0, y0, x1, y1))
            cells.append(cell)
            boxes.append(bbox(cell))
    return cells, boxes, hygiene, board.size


def process(src_a: Path, src_b: Path, target: Path, prefix: str,
            out_dir: Path, foot_y_override: int | None = None) -> dict:
    cells_a, boxes_a, hygiene_a, size_a = crop_board(src_a)
    cells_b, boxes_b, hygiene_b, size_b = crop_board(src_b)
    cells, boxes = cells_a + cells_b, boxes_a + boxes_b

    target_image = Image.open(target).convert("RGBA")
    tw, th = target_image.size
    ground_y = bbox(target_image)[3] - 1 if foot_y_override is None else foot_y_override
    if not 0 <= ground_y < th:
        raise ValueError(f"foot baseline {ground_y} is outside target canvas height {th}")

    max_w = max(b[2] - b[0] for b in boxes)
    max_h = max(b[3] - b[1] for b in boxes)
    scale = min((tw - 2 * PADDING) / max_w, (th - 2 * PADDING) / max_h)
    out_dir.mkdir(parents=True, exist_ok=True)
    files = {}
    subject_sizes = []
    for index, (cell, (x0, y0, x1, y1)) in enumerate(zip(cells, boxes)):
        crop_box = (max(0, x0 - 2), max(0, y0 - 2),
                    min(cell.width, x1 + 2), min(cell.height, y1 + 2))
        body = cell.crop(crop_box)
        sw, sh = max(1, round(body.width * scale)), max(1, round(body.height * scale))
        body = body.resize((sw, sh), Image.Resampling.LANCZOS)
        alpha = np.asarray(body.getchannel("A"))
        ys, xs = np.where(alpha > THRESHOLD)
        if xs.size == 0:
            raise ValueError(f"Walk{index} became empty after resizing")
        px = (tw - sw) // 2
        py = ground_y - int(ys.max())
        if py < 0 or py + sh > th:
            raise ValueError(f"Walk{index} exceeds target canvas at foot y={ground_y}")
        frame = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
        frame.alpha_composite(body, (px, py))
        name = f"{prefix}_Walk{index}.png"
        path = out_dir / name
        frame.save(path, optimize=True)
        files[f"Walk{index}"] = {
            "path": name, "size": [tw, th],
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "subject_size": [sw, sh],
        }
        subject_sizes.append([sw, sh])

    metadata = {
        "schema": "winter-iron.partner-walkcycle.v1",
        "sources": [
            {"path": src_a.name, "sha256": hashlib.sha256(src_a.read_bytes()).hexdigest(),
             "size": list(size_a), "alpha_hygiene": hygiene_a},
            {"path": src_b.name, "sha256": hashlib.sha256(src_b.read_bytes()).hexdigest(),
             "size": list(size_b), "alpha_hygiene": hygiene_b},
        ],
        "grid_per_source": [2, 2],
        "frame_count": 8,
        "target_size": [tw, th],
        "foot_y": ground_y,
        "layout": "first board Walk0..Walk3, second board Walk4..Walk7",
        "scale": round(scale, 6),
        "subject_sizes": subject_sizes,
        "files": files,
        "warnings": [],
    }
    (out_dir / "walkcycle-atlas.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-a", required=True, type=Path)
    parser.add_argument("--input-b", required=True, type=Path)
    parser.add_argument("--target", required=True, type=Path)
    parser.add_argument("--prefix", required=True)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--foot-y", type=int, default=None)
    args = parser.parse_args()
    result = process(args.input_a, args.input_b, args.target, args.prefix,
                     args.output_dir, args.foot_y)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
