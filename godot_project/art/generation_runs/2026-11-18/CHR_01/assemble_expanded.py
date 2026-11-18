from __future__ import annotations

from pathlib import Path

from PIL import Image


RUN = Path(__file__).resolve().parent
ROOT = RUN.parents[4]
ART = ROOT / "godot_project" / "art" / "10_characters" / "CHR_01_Aleksei"
BASE = ART / "CHR_01_Aleksei_Sheet.png"
ARMED = ART / "CHR_01_Aleksei_Armed_Sheet.png"
SWING = ART / "CHR_01_Aleksei_Swing_Sheet.png"
OUTPUT = ART / "CHR_01_Aleksei_Sheet_Expanded.png"
ROW_HEIGHT = 336
SHEET_SIZE = (864, ROW_HEIGHT * 3)

expanded = Image.new("RGBA", SHEET_SIZE, (0, 0, 0, 0))
for y, path in [(0, BASE), (ROW_HEIGHT, ARMED), (ROW_HEIGHT * 2, SWING)]:
    with Image.open(path) as source:
        frame = source.convert("RGBA")
        assert frame.size == (864, ROW_HEIGHT), (path.name, frame.size)
        expanded.paste(frame, (0, y))
expanded.save(OUTPUT, format="PNG", optimize=True)

# Ensure the existing three rows remain byte-for-pixel identical in the expanded art.
with Image.open(BASE) as base, Image.open(OUTPUT) as result:
    base_rgba = base.convert("RGBA")
    first_rows = result.convert("RGBA").crop((0, 0, 864, ROW_HEIGHT))
    assert base_rgba.tobytes() == first_rows.tobytes()

print(f"assembled {OUTPUT} {SHEET_SIZE}: base S/E/N + armed S/E/N + swing S/E/N")
