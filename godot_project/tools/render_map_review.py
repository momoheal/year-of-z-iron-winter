"""Render the Godot tools/export_map_review.gd snapshot as a standalone atlas."""
import base64
import io
import json
import sys
from pathlib import Path

from PIL import Image

project = Path(__file__).resolve().parents[1]
maps = json.loads(Path(sys.argv[1]).read_text(encoding="utf8"))
for level in maps:
    for key in ("img", "night"):
        image = Image.open(project / level[key].removeprefix("res://")).convert("RGB")
        image.thumbnail((1400, 840))
        buf = io.BytesIO()
        image.save(buf, "WEBP", quality=76, method=4)
        level[key] = "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode()
    level["choices"] = [c["zh"] for c in level["choices"]]
template = Path(__file__).with_name("map_review.template.html").read_text(encoding="utf8")
Path(sys.argv[2]).write_text(template.replace("/*MAP_DATA*/", json.dumps(maps, ensure_ascii=False).replace("<", "\\u003c")), encoding="utf8")
