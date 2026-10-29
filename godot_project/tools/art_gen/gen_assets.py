"""一键生成「夜间广轨货场」场景的全部美术 / 音频资产。

用法（在 godot_project/tools/art_gen 下）：
    python gen_assets.py            # 全部
    python gen_assets.py props vfx  # 只重出某几类：ground facade props chars vfx audio

输出到 res://art/（目录与命名遵循《美术资源生成 Prompt 规格书》§3.3），
并写出 art/night_yard_manifest.json（每张精灵的尺寸与 pivot，供 build_scene.py 使用）。
以后用 AI 出图替换时：保持文件名、尺寸比例与 pivot 不变，直接覆盖 PNG 即可。
"""
from __future__ import annotations

import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import gen_chars  # noqa: E402
import gen_env  # noqa: E402
import gen_props  # noqa: E402
import gen_rabid  # noqa: E402
import gen_vfx  # noqa: E402

PROJ = os.path.abspath(os.path.join(HERE, "..", ".."))
ART = os.path.join(PROJ, "art")
MANIFEST = os.path.join(ART, "night_yard_manifest.json")


def _path(*parts):
    p = os.path.join(ART, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def _res(p):
    return "res://" + os.path.relpath(p, PROJ).replace("\\", "/")


def _load_manifest():
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as f:
            return json.load(f)
    return {}


def _put(man, key, path, img, pivot=None, **extra):
    img.save(path)
    man[key] = dict(path=_res(path), size=list(img.size),
                    pivot=list(pivot) if pivot is not None else None, **extra)
    print(f"  {key:34s} {img.size[0]:5d}x{img.size[1]:<5d} -> {_res(path)}", flush=True)


def build_ground(man):
    _put(man, "TIL_Ground_NightYard_Baked", _path("20_tileset", "TIL_Ground_NightYard_Baked.png"),
         gen_env.bake_ground(), (0, 0))


def build_facade(man):
    fac, glow = gen_env.bake_facade()
    _put(man, "TIL_Facade_Khrushchyovka_A", _path("20_tileset", "TIL_Facade_Khrushchyovka_A.png"),
         fac, (0, fac.height))
    _put(man, "VFX_Facade_WindowGlow", _path("50_vfx", "VFX_Facade_WindowGlow.png"), glow,
         (0, gen_env.FACADE_H))


def build_props(man):
    for name, fn in gen_props.ALL.items():
        img, piv = fn()
        _put(man, name, _path("30_props", name + ".png"), img, piv)
    for kind, name in gen_props.FENCES.items():
        img, piv = gen_props.fence_segment(kind)
        _put(man, name, _path("30_props", name + ".png"), img, piv)
    sheet, piv = gen_props.flame_sheet()
    _put(man, "VFX_Fire_Brazier_Sheet", _path("50_vfx", "VFX_Fire_Brazier_Sheet.png"), sheet, piv, hframes=6)


def build_chars(man):
    for key, folder, P in (("CHR_01_Aleksei_Sheet", "CHR_01_Aleksei", gen_chars.ALEKSEI),
                           ("CHR_05_OSK_Sheet", "CHR_05_OSK", gen_chars.OSK)):
        _put(man, key, _path("10_characters", folder, key + ".png"), gen_chars.sheet(P),
             (gen_chars.CX, gen_chars.GY_), hframes=8, vframes=3)
    _put(man, "CHR_04_HalfHuman_Sheet", _path("10_characters", "CHR_04_HalfHuman", "CHR_04_HalfHuman_Sheet.png"),
         gen_chars.half_sheet(), (gen_chars.CX, gen_chars.GY_), hframes=8, vframes=3)
    _put(man, "CHR_03_Rabid_Sheet", _path("10_characters", "CHR_03_Rabid", "CHR_03_Rabid_Sheet.png"),
         gen_rabid.sheet(), (gen_chars.CX, gen_chars.GY_), hframes=8, vframes=3)


def build_vfx(man):
    V = gen_vfx
    _put(man, "VFX_Light_Radial", _path("50_vfx", "VFX_Light_Radial.png"), V.light_radial(512, 2.0))
    _put(man, "VFX_Light_Radial_Soft", _path("50_vfx", "VFX_Light_Radial_Soft.png"), V.light_radial(512, 1.3))
    _put(man, "VFX_Light_Cone_Flashlight", _path("50_vfx", "VFX_Light_Cone_Flashlight.png"),
         V.light_cone(30, edge=0.25, power=1.3, seed=1))
    _put(man, "VFX_Light_Cone_OSK", _path("50_vfx", "VFX_Light_Cone_OSK.png"),
         V.light_cone(22.5, edge=0.15, power=1.2, seed=2))
    _put(man, "VFX_Searchlight_Cone", _path("50_vfx", "VFX_Searchlight_Cone.png"),
         V.light_cone(11, power=0.7, spill=0.2, seed=3, hard=True))
    _put(man, "VFX_Snow_Particle", _path("50_vfx", "VFX_Snow_Particle.png"), V.soft_dot(16, "#ffffff", 1.4))
    _put(man, "VFX_Ember", _path("50_vfx", "VFX_Ember.png"), V.soft_dot(8, "#ffb35a", 1.2))
    _put(man, "VFX_Glow_Halo", _path("50_vfx", "VFX_Glow_Halo.png"), V.soft_dot(128, "#ffd9a0", 2.2))
    _put(man, "VFX_Steam_Puff", _path("50_vfx", "VFX_Steam_Puff.png"), V.steam_puff(64, 7))
    _put(man, "VFX_Blood_Splat", _path("50_vfx", "VFX_Blood_Splat.png"), gen_rabid.blood_splat(96, 5))
    _put(man, "VFX_FogNoise", _path("50_vfx", "VFX_FogNoise.png"), V.fog_noise(512))


def build_audio(man):
    V = gen_vfx
    for key, fn in (("AMB_Wind_Blizzard_Loop", V.amb_wind), ("AMB_Fire_Crackle_Loop", V.amb_fire),
                    ("AMB_Steam_Hiss_Loop", V.amb_steam), ("AMB_Sodium_Buzz_Loop", V.amb_buzz)):
        p = _path("70_audio", key + ".wav")
        fn(p)
        man[key] = dict(path=_res(p))
        print(f"  {key:34s} -> {_res(p)}", flush=True)


STEPS = dict(ground=build_ground, facade=build_facade, props=build_props, chars=build_chars,
             vfx=build_vfx, audio=build_audio)


def main(argv):
    which = argv or list(STEPS)
    man = _load_manifest()
    for k in which:
        t = time.time()
        print(f"[{k}]", flush=True)
        STEPS[k](man)
        print(f"  ({time.time() - t:.1f}s)", flush=True)
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(man, f, indent=1, ensure_ascii=False)
    print("manifest ->", _res(MANIFEST))


if __name__ == "__main__":
    main(sys.argv[1:])
