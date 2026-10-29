"""check_levels — 多关卡管线的静态体检（P4.1 / P4.3 的自动化测试，沙箱里就能跑）。

    python check_levels.py            # 检查全部已登记关卡
    python check_levels.py marshalling

每一关检查四层：
    1. 规格（levels/<id>.py）：字段齐不齐、坐标出不出界、道具 id 重不重、
       容器类型 / 必出物资在不在 CampaignData 的表里（表从 CampaignData.gd 直接读，不抄一份）；
    2. manifest（art/night_<id>_manifest.json）：键齐不齐、PNG/WAV 在不在、pivot 在画布内；
    3. 场景（scenes/night_<id>.tscn）：ext_resource 指向的文件在不在、
       各组节点数量（清杀队 / 狂暴者 / 半人 / 容器 / 冻雪泥 / 火堆）和规格对得上、
       metadata 与规格一致、Camera2D 的四条边界和 W/H 对得上；
    4. 战役接线：CampaignData.LOCS[id].scene == META.scene。

注意：本脚本不渲染、不跑 Godot；像素级回归请用
    python gen_assets.py --level yard ground facade && git diff godot_project/art
（yard 的地面 / 立面必须与仓库里那一版逐像素一致）。
"""
from __future__ import annotations

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import layout as LY  # noqa: E402
import levels  # noqa: E402
import gen_env  # noqa: E402

PROJ = os.path.abspath(os.path.join(HERE, "..", ".."))
PPM, SQ = 64.0, 0.62
GY = PPM * SQ

FAILS: list[str] = []
WARNS: list[str] = []


def ok(cond: bool, msg: str) -> bool:
    if not cond:
        FAILS.append(msg)
    return cond


def warn(cond: bool, msg: str) -> None:
    if not cond:
        WARNS.append(msg)


# ---------------------------------------------------------------------------
# 从 CampaignData.gd 读表（唯一数据源，绝不抄第二份）
# ---------------------------------------------------------------------------
def _campaign_tables() -> tuple[set, set, dict]:
    src = open(os.path.join(PROJ, "scripts", "CampaignData.gd"), encoding="utf-8").read()
    items = set(re.findall(r'^\t"([a-z_0-9]+)": \{"ic"', src, re.M))
    cats = set(re.findall(r'^\t"([a-z_0-9]+)": \[', src, re.M))
    locs = {}
    for m in re.finditer(r'\{"id": "([a-z_0-9]+)"', src):
        i = m.start()
        depth, j = 0, i
        while j < len(src):                      # 找到这个 dict 的右括号
            if src[j] == "{":
                depth += 1
            elif src[j] == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        blob = src[i:j + 1]
        sm = re.search(r'"scene":\s*"([^"]+)"', blob)
        tm = re.search(r'"time":\s*(\d+)', blob)
        locs[m.group(1)] = {"scene": sm.group(1) if sm else "",
                            "night": max(90.0, float(tm.group(1)) * 2.4) if tm else 90.0}
    return items, cats, locs


ITEMS, CATS, LOCS_INFO = _campaign_tables()
CONT_TYPES = CATS | {"corpse"}          # corpse 走 CORPSE_CATS 兜底（冻尸）


def check_spec(name: str) -> dict:
    spec = levels.load(name)
    M = spec.META
    for k in ("id", "zh", "en", "scene", "manifest", "facade", "objective_zh", "extract_zh", "prize"):
        ok(k in M, f"{name}: META 缺字段 {k}")
    ok(M["id"] == name, f"{name}: META.id != 文件名")
    ok(M["prize"] in ITEMS, f"{name}: prize '{M['prize']}' 不在 CampaignData.ITEMS")
    ok(M["facade"] in ("khrushchyovka", "depot"), f"{name}: 未知立面种类 {M['facade']}")
    W, H = spec.W, spec.H
    fy = spec.FENCE_Y

    def inside(pt, what):
        ok(0.0 <= pt[0] <= W and 0.0 <= pt[1] <= H, f"{name}: {what} {pt} 出界")

    inside(spec.SPAWN, "SPAWN")
    inside(spec.EXIT, "EXIT")
    ids = [p["id"] for p in spec.PROPS]
    ok(len(ids) == len(set(ids)), f"{name}: 道具 id 重复")
    for p in spec.PROPS:
        inside(p["pos"], f"道具 {p['id']}")
        ok(p["pos"][1] > spec.FACADE_BASE_Y, f"{name}: 道具 {p['id']} 压进立面墙脚以北")
        ok(p["fp"][0] > 0 and p["fp"][1] > 0, f"{name}: 道具 {p['id']} 脚印尺寸非法")
        if p.get("cont"):
            ok(p["cont"] in CONT_TYPES, f"{name}: 道具 {p['id']} 的容器类型 {p['cont']} 不在表里")
        if p.get("guaranteed"):
            ok(p["guaranteed"] in ITEMS, f"{name}: 道具 {p['id']} 必出物资 {p['guaranteed']} 不在 ITEMS")
    for pat in spec.PATROLS:
        for pt in pat["pts"]:
            inside(pt, f"巡逻 {pat['id']}")
    for rb in spec.RABIDS:
        inside(rb["home"], f"狂暴者 {rb['id']}")
    for hf in spec.HALFS:
        inside(hf["pos"], f"半人 {hf['id']}")
    for i, (cx, cy, rx, ry) in enumerate(spec.SLUSH):
        inside((cx, cy), f"冻雪泥 {i}")
    if fy is not None:
        g0, g1 = spec.FENCE_GAP
        ok(0.0 <= g0 < g1 <= W, f"{name}: 铁丝网豁口 {spec.FENCE_GAP} 不合法")
        xs = [x for x, _ in spec.FENCE_SEGMENTS]
        ok(xs == sorted(xs), f"{name}: FENCE_SEGMENTS 没按 x 排序")
        ok(xs[-1] + 4.0 >= W - 1.0, f"{name}: 铁丝网没铺到地图东边（最后一段 x={xs[-1]}）")
    for k, v in spec.LIGHTS.items():
        inside(v, f"灯位 {k}")
    for entry in spec.LIGHT_RIG:
        if entry == "facade_glow":
            continue
        if entry.startswith("brazier") or entry.startswith("lamp_"):
            ok(entry in spec.LIGHTS, f"{name}: LIGHT_RIG 的 {entry} 在 LIGHTS 里没有位置")
    sl = spec.SEARCHLIGHT
    if sl:
        inside(sl["pos"], "SEARCHLIGHT")
        tower = next((p for p in spec.PROPS if p["id"] == "Watchtower"), None)
        ok(tower is not None and abs(tower["pos"][0] - sl["pos"][0]) < 0.5
           and abs(tower["pos"][1] - sl["pos"][1]) < 0.5,
           f"{name}: 探照灯位置和 Watchtower 道具对不上")
    # 回温点够不够：夜越长需要的火堆越多（体温 100，WARMTH_DECAY = 100/240 / 秒 × cold）
    night_s = LOCS_INFO.get(name, {}).get("night", 90.0)
    cold = float(re.search(rf'"id": "{name}"[^}}]*?"cold":\s*([0-9.]+)',
                           open(os.path.join(PROJ, "scripts", "CampaignData.gd"),
                                encoding="utf-8").read(), re.S).group(1))         if name in LOCS_INFO else 1.0
    need = 2 if night_s * cold >= 230.0 else 1
    warm = [k for k in spec.LIGHTS if k.startswith("brazier")]
    ok(len(warm) >= need, f"{name}: 夜长 {night_s:.0f}s × cold {cold} 只有 {len(warm)} 个火堆（要 ≥{need}）")
    return spec


def check_manifest(name: str, spec) -> dict:
    path = os.path.join(PROJ, "art", spec.META["manifest"])
    ok(os.path.exists(path), f"{name}: manifest 不存在 {path}")
    if not os.path.exists(path):
        return {}
    man = json.load(open(path, encoding="utf-8"))
    LY.activate_level(name)
    gk = gen_env.ground_key()
    fk, gwk = gen_env.facade_keys()
    for k in [gk, fk, gwk, "CHR_01_Aleksei_Sheet", "CHR_03_Rabid_Sheet", "CHR_04_HalfHuman_Sheet",
              "CHR_05_OSK_Sheet", "VFX_FogNoise", "VFX_Snow_Particle", "VFX_Light_Radial",
              "VFX_Light_Cone_Flashlight", "VFX_Light_Cone_OSK", "VFX_Searchlight_Cone",
              "AMB_Wind_Blizzard_Loop"]:
        ok(k in man, f"{name}: manifest 缺键 {k}")
    for p in spec.PROPS:
        ok(p["art"] in man, f"{name}: manifest 缺道具资产 {p['art']}")
    for k, v in man.items():
        fp = os.path.join(PROJ, v["path"].replace("res://", ""))
        ok(os.path.exists(fp), f"{name}: manifest 键 {k} 指向的文件不存在 {v['path']}")
        if "size" in v:
            w, h = v["size"]
            if v.get("pivot"):
                px, py = v["pivot"]
                ok(0 <= px <= w and 0 <= py <= h, f"{name}: {k} 的 pivot 出画布")
    return man


def _nodes(path: str):
    txt = open(path, encoding="utf-8").read()
    nodes = re.findall(r'\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]*)")?(?: groups=\[([^\]]*)\])?\]',
                       txt)
    return txt, nodes


def check_scene(name: str, spec, man) -> None:
    LY.activate_level(name)
    path = os.path.join(PROJ, spec.META["scene"].replace("res://", ""))
    ok(os.path.exists(path), f"{name}: 场景不存在 {path}")
    if not os.path.exists(path):
        return
    txt, nodes = _nodes(path)
    # ext_resource 都指向真实文件
    for m in re.finditer(r'\[ext_resource type="([^"]+)" path="([^"]+)"', txt):
        fp = os.path.join(PROJ, m.group(2).replace("res://", ""))
        ok(os.path.exists(fp), f"{name}: 场景引用的资源不存在 {m.group(2)}")
    groups = {}
    for nm, typ, parent, gr in nodes:
        for g in (gr.split(", ") if gr else []):
            groups.setdefault(g.strip('"'), []).append(nm)
    ok(len(groups.get("night_osk", [])) == len(spec.PATROLS),
       f"{name}: 清杀队 {len(groups.get('night_osk', []))} != 规格 {len(spec.PATROLS)}")
    ok(len(groups.get("night_rabid", [])) == len(spec.RABIDS),
       f"{name}: 狂暴者 {len(groups.get('night_rabid', []))} != 规格 {len(spec.RABIDS)}")
    ok(len(groups.get("night_half", [])) == len(spec.HALFS),
       f"{name}: 半人 {len(groups.get('night_half', []))} != 规格 {len(spec.HALFS)}")
    n_cont = len(groups.get("night_container", []))
    want_cont = len([p for p in spec.PROPS if p.get("cont")])
    ok(n_cont == want_cont, f"{name}: 容器 {n_cont} != 规格 {want_cont}")
    ok(len(groups.get("night_slush", [])) == len(spec.SLUSH),
       f"{name}: 冻雪泥 {len(groups.get('night_slush', []))} != 规格 {len(spec.SLUSH)}")
    warm = len([k for k in spec.LIGHTS if k.startswith("brazier")])
    ok(len(groups.get("night_warm", [])) == warm, f"{name}: 火堆灯 {len(groups.get('night_warm', []))} != {warm}")
    ok(len(groups.get("night_searchlight", [])) == (1 if spec.SEARCHLIGHT else 0),
       f"{name}: 探照灯数量不对")
    # metadata
    for key, want in (("level_id", spec.META["id"]), ("level_zh", spec.META["zh"]),
                      ("level_en", spec.META["en"]), ("objective_zh", spec.META["objective_zh"]),
                      ("extract_zh", spec.META["extract_zh"]), ("prize", spec.META["prize"]),
                      ("rail_y", ",".join(str(v) for v in spec.TRACKS))):
        m = re.search(rf'metadata/{key} = "([^"]*)"', txt)
        ok(m is not None and m.group(1) == want, f"{name}: metadata/{key} 与规格不一致")
    # 镜头边界
    base_y = spec.FACADE_BASE_Y * GY
    fh = float(gen_env.facade_h())
    m = re.search(r'\[node name="Camera2D".*?limit_left = (-?\d+)\s*\nlimit_top = (-?\d+)\s*\n'
                  r'limit_right = (-?\d+)\s*\nlimit_bottom = (-?\d+)', txt, re.S)
    ok(m is not None, f"{name}: 找不到 Camera2D 边界")
    if m:
        l, t, r, b = (int(x) for x in m.groups())
        ok((l, t, r, b) == (0, int(base_y - fh), int(spec.W * PPM), int(spec.H * GY)),
           f"{name}: 镜头边界 {(l, t, r, b)} != 期望 {(0, int(base_y - fh), int(spec.W * PPM), int(spec.H * GY))}")
    # 地面 / 立面精灵指向本关 manifest 的资产
    gk = gen_env.ground_key()
    fk, gwk = gen_env.facade_keys()
    ok(man.get(gk, {}).get("path", "") in txt, f"{name}: 场景没用本关地面大图 {gk}")
    ok(man.get(fk, {}).get("path", "") in txt, f"{name}: 场景没用本关立面 {fk}")
    ok(man.get(gwk, {}).get("path", "") in txt, f"{name}: 场景没用本关窗光贴图 {gwk}")
    # 环境音路数
    n_amb = len(re.findall(r'\[node name="(Wind|FireAudio|SteamAudio|LampBuzz)" type="AudioStreamPlayer', txt))
    ok(n_amb == len(spec.AMBIENCE), f"{name}: 环境音 {n_amb} 路 != AMBIENCE {len(spec.AMBIENCE)} 路")
    # 撤离 / 出生标记
    ok('name="Spawn" type="Marker2D"' in txt and 'name="Exit" type="Marker2D"' in txt,
       f"{name}: 缺 Spawn / Exit 标记")


def main(argv):
    which = argv or levels.LEVELS
    for name in which:
        spec = check_spec(name)
        man = check_manifest(name, spec)
        check_scene(name, spec, man)
        sc = LOCS_INFO.get(name, {}).get("scene", "")
        ok(sc == spec.META["scene"],
           f"{name}: CampaignData.LOCS 的 scene 字段与 META.scene 不一致（{sc or '<无>'} vs {spec.META['scene']}）")
    for w in WARNS:
        print("  warn:", w)
    if FAILS:
        print(f"CHECK_LEVELS FAIL（{len(FAILS)} 项）")
        for f in FAILS:
            print("  -", f)
        return 1
    print(f"CHECK_LEVELS PASS（{len(which)} 关：{', '.join(which)}）")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
