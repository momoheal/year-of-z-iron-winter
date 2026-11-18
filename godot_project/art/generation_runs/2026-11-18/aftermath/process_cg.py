from pathlib import Path
import hashlib,json,sys
from PIL import Image,ImageOps
src=Path(sys.argv[1]); dst=Path(sys.argv[2]); report=Path(sys.argv[3])
if dst.exists(): raise SystemExit(f"refusing to overwrite {dst}")
im=Image.open(src).convert("RGB")
raw_size=list(im.size)
fitted=ImageOps.fit(im,(1376,768),method=Image.Resampling.LANCZOS,centering=(0.5,0.5))
fitted.save(dst,"JPEG",quality=94,subsampling=0,optimize=True,progressive=True)
data={"source":src.name,"source_size":raw_size,"output":dst.name,"output_size":[1376,768],"format":"JPEG","quality":94,"source_sha256":hashlib.sha256(src.read_bytes()).hexdigest(),"output_sha256":hashlib.sha256(dst.read_bytes()).hexdigest(),"route":"Codex image_gen (host_image)"}
report.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps(data,ensure_ascii=False))

