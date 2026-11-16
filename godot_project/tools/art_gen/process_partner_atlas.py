#!/usr/bin/env python3
"""Extract three transparent partner poses from a 2x2 generated atlas."""
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

POSES = (("Stand", 0, 0), ("Walk0", 0, 1), ("Walk1", 1, 0))
THRESHOLD = 16
PADDING = 4


def bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.where(alpha > THRESHOLD)
    if xs.size < 40:
        raise ValueError("pose cell has no usable subject pixels")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def process(src: Path, target: Path, prefix: str, out_dir: Path,
            foot_y_override: int | None = None) -> dict:
    source, hygiene = forge_core.alpha_hygiene(Image.open(src).convert("RGBA"), mode="both")
    w, h = source.size
    cells, boxes = [], []
    for row in range(2):
        row_cells, row_boxes = [], []
        y0, y1 = round(row * h / 2), round((row + 1) * h / 2)
        for col in range(2):
            x0, x1 = round(col * w / 2), round((col + 1) * w / 2)
            cell = source.crop((x0, y0, x1, y1))
            row_cells.append(cell)
            row_boxes.append(bbox(cell))
        cells.append(row_cells)
        boxes.append(row_boxes)

    target_image = Image.open(target).convert("RGBA")
    tw, th = target_image.size
    if foot_y_override is None:
        target_box = bbox(target_image)
        ground_y = target_box[3] - 1
    else:
        ground_y = foot_y_override
    if not 0 <= ground_y < th:
        raise ValueError(f"foot baseline {ground_y} is outside target canvas height {th}")
    selected = [(cells[r][c], boxes[r][c]) for _pose, r, c in POSES]
    max_w = max(b[2] - b[0] for _im, b in selected)
    max_h = max(b[3] - b[1] for _im, b in selected)
    scale = min((tw - 2 * PADDING) / max_w, (th - 2 * PADDING) / max_h)
    out_dir.mkdir(parents=True, exist_ok=True)
    files = {}
    for (pose, _row, _col), (cell, (x0, y0, x1, y1)) in zip(POSES, selected):
        margin = 2
        crop_box = (max(0, x0 - margin), max(0, y0 - margin),
                    min(cell.width, x1 + margin), min(cell.height, y1 + margin))
        body = cell.crop(crop_box)
        sw, sh = max(1, round(body.width * scale)), max(1, round(body.height * scale))
        body = body.resize((sw, sh), Image.Resampling.LANCZOS)
        frame = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
        px = (tw - sw) // 2
        body_alpha = np.asarray(body.getchannel("A"))
        body_ys = np.where(body_alpha > THRESHOLD)[0]
        body_bottom = int(body_ys.max())
        py = ground_y - body_bottom
        if py < 0 or py + sh > th:
            raise ValueError(f"{pose} exceeds target canvas when aligned to foot y={ground_y}")
        frame.alpha_composite(body, (px, py))
        path = out_dir / f"{prefix}_{pose}.png"
        frame.save(path, optimize=True)
        files[pose] = {"path": path.name, "size": [tw, th],
                       "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                       "subject_size": [sw, sh]}
    metadata = {
        "schema": "winter-iron.partner-atlas.v1",
        "source": src.name,
        "source_sha256": hashlib.sha256(src.read_bytes()).hexdigest(),
        "source_size": [w, h],
        "grid": [2, 2],
        "target_size": [tw, th],
        "foot_y": ground_y,
        "poses": {"top_left": "Stand", "top_right": "Walk0",
                  "bottom_left": "Walk1", "bottom_right": "unused"},
        "scale": round(scale, 6),
        "alpha_hygiene": hygiene,
        "files": files,
        "warnings": [],
    }
    (out_dir / "partner-atlas.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--target", required=True, type=Path,
                        help="existing in-game image used only to read the required dimensions")
    parser.add_argument("--prefix", required=True)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--foot-y", type=int, default=None,
                        help="override the target image's existing alpha bottom line")
    args = parser.parse_args()
    print(json.dumps(process(args.input, args.target, args.prefix, args.output_dir, args.foot_y),
                     ensure_ascii=False))


if __name__ == "__main__":
    main()
