#!/usr/bin/env python3
"""Crop a 2x2 generated expression board into the game's square character portraits."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

STATES = (("Calm", 0, 0), ("Sad", 0, 1), ("Intense", 1, 0), ("Wry", 1, 1))
SIZE = 512


def process(src: Path, name: str, out_dir: Path) -> dict:
    if out_dir.exists():
        raise FileExistsError(f"output directory already exists: {out_dir}")
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    out_dir.mkdir(parents=True)
    files = {}
    for state, row, col in STATES:
        x0, x1 = round(col * w / 2), round((col + 1) * w / 2)
        y0, y1 = round(row * h / 2), round((row + 1) * h / 2)
        tile = im.crop((x0, y0, x1, y1)).resize((SIZE, SIZE), Image.Resampling.LANCZOS)
        path = out_dir / f"PRT_{name}_{state}.png"
        tile.save(path, optimize=True)
        files[state] = {"path": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    calm = out_dir / files["Calm"]["path"]
    base = out_dir / f"PRT_{name}.png"
    Image.open(calm).save(base, optimize=True)
    files["Base"] = {"path": base.name, "sha256": hashlib.sha256(base.read_bytes()).hexdigest()}
    data = {
        "schema": "winter-iron.character-portrait-atlas.v1",
        "source": src.name,
        "source_sha256": hashlib.sha256(src.read_bytes()).hexdigest(),
        "source_size": [w, h],
        "grid": [2, 2],
        "tile_size": [SIZE, SIZE],
        "layout": {"top_left": "Calm", "top_right": "Sad", "bottom_left": "Intense", "bottom_right": "Wry"},
        "files": files,
        "warnings": [],
    }
    (out_dir / "portrait-atlas.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return data


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--name", required=True)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(process(args.input, args.name, args.output_dir), ensure_ascii=False))


if __name__ == "__main__":
    main()
