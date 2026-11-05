"""只重新生成 3 张锥形灯光贴图（手电 / OSK 缴获灯 / 探照灯）。

为什么单开一步：`gen_assets.py vfx` 会把所有 VFX 重出，而 PIL/numpy 版本差异
会让无关旧资产出现肉眼不可见、但字节不同的差异（见 build_weapons 的注释）。
灯光羽化修复只需要动这 3 张共享贴图，参数与 gen_assets.build_vfx 完全一致。

用法（在 godot_project/tools/art_gen 下）：
    python regen_lights.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import gen_vfx as V  # noqa: E402

ART = os.path.abspath(os.path.join(HERE, "..", "..", "art", "50_vfx"))
os.makedirs(ART, exist_ok=True)

# 与 gen_assets.build_vfx 中的参数一一对应
SPECS = [
    ("VFX_Light_Cone_Flashlight", V.light_cone(30, edge=0.25, power=1.3, seed=1)),
    ("VFX_Light_Cone_OSK", V.light_cone(22.5, edge=0.15, power=1.2, seed=2)),
    ("VFX_Searchlight_Cone", V.light_cone(11, power=0.7, spill=0.2, seed=3, hard=True)),
]

for name, img in SPECS:
    p = os.path.join(ART, name + ".png")
    img.save(p)
    print(f"wrote {p}  {img.size} {img.mode}", flush=True)
