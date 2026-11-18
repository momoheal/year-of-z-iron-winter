from __future__ import annotations

import json
from pathlib import Path
import re

from PIL import Image


ROOT = Path(__file__).resolve().parents[4]
ART = ROOT / "godot_project" / "art"
CG_DIR = ART / "60_ui" / "cg"
BG_DIR = ART / "60_ui" / "backgrounds"
ACTION_DIR = ART / "10_characters" / "CHR_01_Aleksei"
MANIFEST = json.loads((ART / "asset_manifest.json").read_text(encoding="utf-8"))
CUTSCENES = (ROOT / "godot_project" / "scripts" / "data" / "CutsceneData.gd").read_text(encoding="utf-8")


def check_image(path: Path, size: tuple[int, int], image_format: str) -> None:
    with Image.open(path) as image:
        assert image.size == size, (path.name, image.size, size)
        assert image.format == image_format, (path.name, image.format, image_format)
    assert path.with_name(path.stem + ".prompt.txt").is_file(), f"missing prompt: {path.name}"


def manifest_entry(path: Path) -> dict:
    key = path.relative_to(ART).as_posix()
    assert key in MANIFEST["assets"], f"not registered: {key}"
    return MANIFEST["assets"][key]


aftermath_names = {
    "ENDING_A_RETURN_HOME": "cg_aftermath_a_602.jpg",
    "ENDING_B_FLAWED_LIBERATION": "cg_aftermath_b_release.jpg",
    "ENDING_C_NUMBNESS": "cg_aftermath_c_numb.jpg",
    "TRUE_ALPHA_HELLO_LANA": "cg_aftermath_true_alpha.jpg",
    "TRUE_BETA_OUTLAND_FIRE": "cg_aftermath_true_beta.jpg",
}
ending_block = CUTSCENES.split("const ENDING_SCENES := {", 1)[1].split("\n}\n\nconst PROLOGUE", 1)[0]
for ending, filename in aftermath_names.items():
    start = ending_block.index(f'\t"{ending}": {{')
    end = ending_block.find("\n\t},", start)
    section = ending_block[start:end]
    assert section.count("cg_aftermath_") == 1, (ending, section.count("cg_aftermath_"))
    assert section.count(filename) == 1, (ending, filename)
    assert "cg_aftermath_pasha_crag_mercy.jpg" not in section, ending
    path = CG_DIR / filename
    check_image(path, (1376, 768), "JPEG")
    entry = manifest_entry(path)
    assert entry["real_size"] == [1376, 768], (filename, entry)
    assert entry["ref"] == "code", (filename, entry["ref"])

for filename in ["BG_Title_602_Stairwell_Night.jpg", "BG_Event_Telegraph_Desk.jpg"]:
    path = BG_DIR / filename
    check_image(path, (1920, 1080), "JPEG")
    entry = manifest_entry(path)
    assert entry["real_size"] == [1920, 1080], (filename, entry)
    assert entry["family"] == "ui", (filename, entry["family"])
    assert entry["ref"] == "none", (filename, entry["ref"])

for filename in ["CHR_01_Aleksei_Sheet_Expanded.png"]:
    path = ACTION_DIR / filename
    with Image.open(path) as image:
        assert image.size == (864, 1008), (filename, image.size)
        assert image.mode == "RGBA", (filename, image.mode)
    entry = manifest_entry(path)
    assert entry["real_size"] == [864, 1008], (filename, entry)
    assert entry["family"] == "character_sheet", (filename, entry["family"])
    assert entry["ref"] == "none", (filename, entry["ref"])

cgre = (CG_DIR / "README.md").read_text(encoding="utf-8")
for filename in aftermath_names.values():
    assert filename in cgre, f"CG README omits {filename}"
assert "1376×768" in cgre and "不再共用" in cgre

report = {
    "date": "2026-11-18",
    "result": "PASS",
    "asset_count": MANIFEST["_meta"]["asset_count"],
    "asset_audit_note": "The global scan warns about the intended 864x336 runtime sheet versus the separate 864x1008 art-only expanded sheet.",
    "group_1": {"unique_endings": len(aftermath_names), "images_checked": len(aftermath_names), "code_mapping": "one-to-one"},
    "group_2": {"sheet_checked": "12x9", "runtime_wiring": "not_done", "qa_frames": 108},
    "group_3": {"backgrounds_checked": 2, "scene_hookup": "not_done"},
}
(ROOT / "godot_project" / "art" / "generation_runs" / "2026-11-18" / "batch3_verification.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
print(json.dumps(report, ensure_ascii=False, indent=2))
