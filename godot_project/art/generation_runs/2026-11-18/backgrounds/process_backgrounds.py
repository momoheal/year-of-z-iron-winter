from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageOps


RUN_DIR = Path(__file__).resolve().parent
ROOT = RUN_DIR.parents[4]
SOURCE_DIR = RUN_DIR
DEST_DIR = ROOT / "godot_project" / "art" / "60_ui" / "backgrounds"
TARGET_SIZE = (1920, 1080)
ASSETS = [
    "BG_Title_602_Stairwell_Night",
    "BG_Event_Telegraph_Desk",
]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


DEST_DIR.mkdir(parents=True, exist_ok=True)
records = []
for asset in ASSETS:
    raw = SOURCE_DIR / f"{asset}_raw.png"
    prompt_source = SOURCE_DIR / f"{asset}.prompt.txt"
    image_out = DEST_DIR / f"{asset}.jpg"
    prompt_out = DEST_DIR / f"{asset}.prompt.txt"
    with Image.open(raw) as source:
        original_size = source.size
        rgb = ImageOps.fit(
            source.convert("RGB"),
            TARGET_SIZE,
            method=Image.Resampling.LANCZOS,
            centering=(0.5, 0.5),
        )
        rgb.save(image_out, format="JPEG", quality=94, optimize=True, progressive=True)
    shutil.copyfile(prompt_source, prompt_out)
    with Image.open(image_out) as final:
        assert final.size == TARGET_SIZE, (asset, final.size)
        assert final.format == "JPEG", (asset, final.format)
    records.append(
        {
            "asset": asset,
            "raw_source": raw.relative_to(ROOT).as_posix(),
            "raw_size": list(original_size),
            "output": image_out.relative_to(ROOT).as_posix(),
            "output_size": list(TARGET_SIZE),
            "prompt": prompt_out.relative_to(ROOT).as_posix(),
            "resampling": "Pillow ImageOps.fit, Lanczos, centered, RGB JPEG quality 94",
            "raw_sha256": sha256(raw),
            "output_sha256": sha256(image_out),
        }
    )

manifest = {
    "date": "2026-11-18",
    "group": 3,
    "generator": "Codex image_gen (host_image)",
    "purpose": "art-only UI background plates; no scene hookup",
    "target_size": list(TARGET_SIZE),
    "assets": records,
}
(RUN_DIR / "run_manifest.json").write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
print(json.dumps(manifest, ensure_ascii=False, indent=2))
