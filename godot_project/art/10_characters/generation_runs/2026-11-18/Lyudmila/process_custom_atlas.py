from pathlib import Path
import hashlib, json, sys
from PIL import Image
src = Path(sys.argv[1])
out = Path(sys.argv[2])
runtime = Path(sys.argv[3])
if out.exists():
    raise SystemExit(f"refusing to overwrite {out}")
out.mkdir(parents=True)
im = Image.open(src).convert("RGBA")
w, h = im.size
states = [("Fear", 0, 0), ("Determined", 0, 1), ("Hurt", 1, 0)]
files = {}
for state, row, col in states:
    box = (round(col*w/2), round(row*h/2), round((col+1)*w/2), round((row+1)*h/2))
    tile = im.crop(box).resize((512,512), Image.Resampling.LANCZOS)
    name = f"PRT_Lyudmila_{state}.png"
    tile.save(out/name, optimize=True)
    files[state] = {"path": name, "sha256": hashlib.sha256((out/name).read_bytes()).hexdigest()}
    target = runtime/name
    if target.exists():
        raise SystemExit(f"refusing to overwrite existing portrait: {target}")
    target.write_bytes((out/name).read_bytes())
data = {"schema":"winter-iron.custom-portrait-atlas.v1","source":src.name,"source_sha256":hashlib.sha256(src.read_bytes()).hexdigest(),"source_size":[w,h],"grid":[2,2],"tile_size":[512,512],"layout":{"top_left":"Fear","top_right":"Determined","bottom_left":"Hurt","bottom_right":"Wry (reference only; existing runtime file preserved)"},"files":files}
(out/"portrait-atlas.json").write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
(runtime/"PRT_Lyudmila_Fear.png").exists() or None
print(json.dumps({"source_size":[w,h],"exported":list(files),"runtime_dir":str(runtime)},ensure_ascii=False))

