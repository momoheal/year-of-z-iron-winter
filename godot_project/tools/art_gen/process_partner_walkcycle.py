#!/usr/bin/env python3
"""Crop an eight-pose transparent partner walk cycle into fixed game frames."""
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
FRAME_COUNT = 8


def bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.where(alpha > THRESHOLD)
    if xs.size < 40:
        raise ValueError("walk-cycle cell has no usable subject pixels")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def process(src: Path, target: Path, prefix: str, out_dir: Path,
            cols: int, rows: int, foot_y_override: int | None = None) -> dict:
    if cols * rows != FRAME_COUNT:
        raise ValueError("walk-cycle grid must contain exactly 8 cells")
    source, hygiene = forge_core.alpha_hygiene(Image.open(src).convert("RGBA"), mode="both")
    w, h = source.size
    target_image = Image.open(target).convert("RGBA")
    tw, th = target_image.size
    ground_y = bbox(target_image)[3] - 1 if foot_y_override is None else foot_y_override
    if not 0 <= ground_y < th:
        raise ValueError(f"foot baseline {ground_y} is outside target canvas height {th}")

    cells: list[Image.Image] = []
    boxes: list[tuple[int, int, int, int]] = []
    for index in range(FRAME_COUNT):
        row, col = divmod(index, cols)
        x0, x1 = round(col * w / cols), round((col + 1) * w / cols)
        y0, y1 = round(row * h / rows), round((row + 1) * h / rows)
        cell = source.crop((x0, y0, x1, y1))
        cells.append(cell)
        boxes.append(bbox(cell))

    max_w = max(b[2] - b[0] for b in boxes)
    max_h = max(b[3] - b[1] for b in boxes)
    scale = min((tw - 2 * PADDING) / max_w, (th - 2 * PADDING) / max_h)
    out_dir.mkdir(parents=True, exist_ok=True)
    files = {}
    body_sizes = []
    for index, (cell, (x0, y0, x1, y1)) in enumerate(zip(cells, boxes)):
        crop_box = (max(0, x0 - 2), max(0, y0 - 2),
                    min(cell.width, x1 + 2), min(cell.height, y1 + 2))
        body = cell.crop(crop_box)
        sw = max(1, round(body.width * scale))
        sh = max(1, round(body.height * scale))
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
            "path": name,
            "size": [tw, th],
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "subject_size": [sw, sh],
        }
        body_sizes.append([sw, sh])

    metadata = {
        "schema": "winter-iron.partner-walkcycle.v1",
        "source": src.name,
        "source_sha256": hashlib.sha256(src.read_bytes()).hexdigest(),
        "source_size": [w, h],
        "grid": [cols, rows],
        "frame_count": FRAME_COUNT,
        "target_size": [tw, th],
        "foot_y": ground_y,
        "layout": "row-major Walk0..Walk7; alternate left/right contact phases",
        "scale": round(scale, 6),
        "alpha_hygiene": hygiene,
        "subject_sizes": body_sizes,
        "files": files,
        "warnings": [],
    }
    (out_dir / "walkcycle-atlas.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--target", required=True, type=Path)
    parser.add_argument("--prefix", required=True)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--cols", required=True, type=int)
    parser.add_argument("--rows", required=True, type=int)
    parser.add_argument("--foot-y", type=int, default=None)
    args = parser.parse_args()
    print(json.dumps(process(args.input, args.target, args.prefix, args.output_dir,
                             args.cols, args.rows, args.foot_y), ensure_ascii=False))


if __name__ == "__main__":
    main()
