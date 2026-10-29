"""从关卡规格（levels/<id>.py）+ art/night_<id>_manifest.json 生成 scenes/night_<id>.tscn。

    python build_scene.py                     # yard → res://scenes/night_explore.tscn
    python build_scene.py --level marshalling # → res://scenes/night_marshalling.tscn

这是一次性「搭场景」脚本：生成后可以直接在 Godot 编辑器里拖动、调灯、改路线。
重新运行会覆盖 .tscn（编辑器里的手工修改会丢），所以改完布局后再跑，或从此在编辑器里维护。
yard 的输出文件名沿用 night_explore.tscn（测试 / F2 / 文档都指着它），别的新关卡一律
night_<id>.tscn。场景根节点带 metadata（level_id / level_zh / …），NightExplore 读它。
"""
from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)


def _argv_level() -> str:
    for i, a in enumerate(sys.argv):
        if a == "--level" and i + 1 < len(sys.argv):
            return sys.argv[i + 1]
        if a.startswith("--level="):
            return a.split("=", 1)[1]
    return os.environ.get("NOVORSK_LEVEL") or "yard"


LEVEL = _argv_level()          # 必须在 import layout 之前定（layout 导入时就灌数据）
os.environ["NOVORSK_LEVEL"] = LEVEL
import layout as LY  # noqa: E402
import gen_env  # noqa: E402

PROJ = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(PROJ, "scenes", os.path.basename(LY.META["scene"]))
MANIFEST = os.path.join(PROJ, "art", LY.META["manifest"])
PPM, SQ = 64.0, 0.62
GY = PPM * SQ

with open(MANIFEST, encoding="utf-8") as f:
    MAN = json.load(f)


def px(x, y):
    return (round(x * PPM, 2), round(y * GY, 2))


def v2(p):
    return f"Vector2({p[0]:g}, {p[1]:g})"


def col(r, g, b, a=1.0):
    return f"Color({r:g}, {g:g}, {b:g}, {a:g})"


class Scene:
    def __init__(self):
        self.ext: list[str] = []
        self.ext_ids: dict[str, str] = {}
        self.sub: list[str] = []
        self.nodes: list[str] = []
        self.n_sub = 0

    def res(self, path, typ):
        if path not in self.ext_ids:
            i = f"{len(self.ext_ids) + 1}_{typ.lower()[:4]}"
            self.ext_ids[path] = i
            self.ext.append(f'[ext_resource type="{typ}" path="{path}" id="{i}"]')
        return f'ExtResource("{self.ext_ids[path]}")'

    def tex(self, key):
        return self.res(MAN[key]["path"], "Texture2D")

    def subres(self, typ, **props):
        self.n_sub += 1
        i = f"{typ}_{self.n_sub}"
        body = "\n".join(f"{k} = {v}" for k, v in props.items())
        self.sub.append(f'[sub_resource type="{typ}" id="{i}"]\n{body}'.rstrip())
        return f'SubResource("{i}")'

    def node(self, name, typ, parent=None, groups=None, **props):
        head = f'[node name="{name}" type="{typ}"'
        if parent is not None:
            head += f' parent="{parent}"'
        if groups:
            head += " groups=[" + ", ".join(f'"{g}"' for g in groups) + "]"
        head += "]"
        body = "\n".join(f"{k.replace('metadata__', 'metadata/')} = {v}" for k, v in props.items())
        self.nodes.append((head + "\n" + body).rstrip())
        return name if parent in (None, ".") else f"{parent}/{name}"

    def write(self, path):
        parts = ["[gd_scene format=3]", "\n".join(self.ext)] + self.sub + self.nodes
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n\n".join(p for p in parts if p) + "\n")


S = Scene()
SCRIPT = lambda n: S.res(f"res://scripts/night/{n}.gd", "Script")  # noqa: E731


def rect_shape(w, h):
    return S.subres("RectangleShape2D", size=v2((round(w, 2), round(h, 2))))


def occluder(x0, y0, x1, y1):
    return S.subres("OccluderPolygon2D",
                    polygon=f"PackedVector2Array({x0:g}, {y0:g}, {x1:g}, {y0:g}, {x1:g}, {y1:g}, {x0:g}, {y1:g})")


def light_pair(parent, tex_key, color, ground_e, obj_e, scale, shadow=True, offset=None, obj_scale=None,
               shadow_mask=1):
    common = dict(texture=S.tex(tex_key), color=color, texture_scale=f"{scale:g}")
    if offset:
        common["offset"] = v2(offset)
    g = dict(common, energy=f"{ground_e:g}", range_item_cull_mask="2")
    if shadow:
        g.update(shadow_enabled="true", shadow_filter="1", shadow_filter_smooth="1.5",
                 shadow_item_cull_mask=str(shadow_mask))
    S.node("Ground", "PointLight2D", parent, **g)
    o = dict(common, energy=f"{obj_e:g}", range_item_cull_mask="1")
    if obj_scale:
        o["texture_scale"] = f"{obj_scale:g}"
    S.node("Objects", "PointLight2D", parent, **o)


def cone_rig(parent, tex_key, color, ground_e, obj_e, range_m, name="Flashlight"):
    rig = S.node(name, "Node2D", parent, scale=v2((1, SQ)))
    piv = S.node("Pivot", "Node2D", rig)
    sc = round(range_m * PPM / 1024.0, 4)
    light_pair(piv, tex_key, color, ground_e, obj_e, sc, offset=(round(512 * sc, 2), 0))
    return rig


def sprite(parent, key, name="Sprite", **extra):
    piv = MAN[key]["pivot"]
    return S.node(name, "Sprite2D", parent, texture=S.tex(key), centered="false",
                  offset=v2((-piv[0], -piv[1])), **extra)


def character(parent, name, sheet_key, script, layer, mask, groups=None, **extra):
    n = S.node(name, "CharacterBody2D", parent, groups=groups, collision_layer=str(layer),
               collision_mask=str(mask), motion_mode="1", script=SCRIPT(script), **extra)
    shadow = "PackedVector2Array(" + ", ".join(
        f"{16 * __import__('math').cos(a * 0.3927):.2f}, {6 * __import__('math').sin(a * 0.3927):.2f}"
        for a in range(16)) + ")"
    S.node("Shadow", "Polygon2D", n, color=col(0, 0, 0, 0.42), polygon=shadow)
    S.node("Sprite", "Sprite2D", n, texture=S.tex(sheet_key), hframes="8", vframes="3",
           offset=v2((0, -52)))
    S.node("Shape", "CollisionShape2D", n, position=v2((0, -2)),
           shape=S.subres("CircleShape2D", radius="11.0"))
    return n


# ===========================================================================
# 根 + 夜色
# ===========================================================================
S.node("NightExplore", "Node2D", None, texture_filter="2", script=SCRIPT("NightExplore"),
       metadata__level_id=f'"{LY.META["id"]}"', metadata__level_zh=f'"{LY.META["zh"]}"',
       metadata__level_en=f'"{LY.META["en"]}"', metadata__objective_zh=f'"{LY.META["objective_zh"]}"',
       metadata__extract_zh=f'"{LY.META["extract_zh"]}"', metadata__prize=f'"{LY.META["prize"]}"',
       metadata__rail_y=f'"{",".join(str(v) for v in LY.TRACKS)}"')
S.node("CanvasModulate", "CanvasModulate", ".", color=col(0.27, 0.32, 0.45))
S.node("Ground", "Sprite2D", ".", z_index="-1", light_mask="2", centered="false",
       texture=S.tex(gen_env.ground_key()))
# 血迹等地面贴花（运行时往里加），画在地面之上、所有立起的精灵之下
S.node("Decals", "Node2D", ".", z_index="-1")
S.node("World", "Node2D", ".", y_sort_enabled="true")

# ---- 立面（北侧那堵墙：khrushchyovka 赫鲁晓夫楼 / depot 机车库+调度塔）----
base_y = LY.FACADE_BASE_Y * GY
FH = gen_env.facade_h()
FAC_KEY, GLOW_KEY = gen_env.facade_keys()
fac = S.node("Facade", "StaticBody2D", "World", position=v2((0, round(base_y, 2))), collision_layer="1",
             collision_mask="0")
S.node("Sprite", "Sprite2D", fac, texture=S.tex(FAC_KEY), centered="false",
       offset=v2((0, -FH)))
S.node("Shape", "CollisionShape2D", fac, position=v2((LY.W * PPM / 2, -150)),
       shape=rect_shape(LY.W * PPM, 300))

# ---- 道具 ----
S.node("Props", "Node2D", "World", y_sort_enabled="true")
LAYER_BITS = {0: 0, 1: 1, 2: 2, 3: 4}
for p in LY.PROPS:
    groups = []
    meta = {}
    if p.get("cont"):
        groups.append("night_container")
        meta["metadata/container"] = f'"{p["cont"]}"'
        if p.get("guaranteed"):
            meta["metadata/guaranteed"] = f'"{p["guaranteed"]}"'
        if p.get("reach"):
            meta["metadata/interact_offset"] = v2((p["reach"][0] * PPM, round(p["reach"][1] * GY, 2)))
    if p.get("fade"):
        groups.append("night_fade")
    n = S.node(p["id"], "StaticBody2D", "World/Props", groups=groups or None, position=v2(px(*p["pos"])),
               collision_layer=str(LAYER_BITS[p["layer"]]), collision_mask="0", **meta)
    sprite(n, p["art"])
    fw, fd = p["fp"][0] * PPM, p["fp"][1] * GY
    if p["layer"]:
        S.node("Shape", "CollisionShape2D", n, position=v2((0, round(-fd / 2, 2))), shape=rect_shape(fw, fd))
    if p["layer"] in (1, 2) and p.get("occlude", True):
        S.node("Occluder", "LightOccluder2D", n,
               occluder=occluder(round(-fw / 2, 1), round(-fd, 1), round(fw / 2, 1), 0))
    if p.get("fire"):
        S.node("Flame", "Sprite2D", n, texture=S.tex("VFX_Fire_Brazier_Sheet"), hframes="6",
               centered="false", offset=v2((-28, -80)), position=v2((0, -50)), script=SCRIPT("NightAnim"))
        S.node("Embers", "GPUParticles2D", n, position=v2((0, -64)), amount="26", lifetime="1.6",
               preprocess="2.0", texture=S.tex("VFX_Ember"),
               material=S.subres("CanvasItemMaterial", blend_mode="1"),
               visibility_rect="Rect2(-200, -400, 400, 420)",
               process_material=S.subres(
                   "ParticleProcessMaterial", particle_flag_disable_z="true", emission_shape="1",
                   emission_sphere_radius="9.0", direction="Vector3(0, -1, 0)", spread="28.0",
                   initial_velocity_min="30.0", initial_velocity_max="75.0",
                   gravity="Vector3(10, -25, 0)", scale_min="0.6", scale_max="1.3",
                   color=col(1, 0.78, 0.45, 0.95)))

# ---- 铁丝网 ----
fence = S.node("Fence", "Node2D", "World", y_sort_enabled="true")
for x0, kind in LY.FENCE_SEGMENTS:
    key = {"a": "PRP_Fence_ChainLink_A", "b": "PRP_Fence_ChainLink_B", "torn": "PRP_Fence_ChainLink_Torn",
           "torn_l": "PRP_Fence_ChainLink_TornL"}[kind]
    seg = S.node(f"Seg_{x0:g}".replace(".", "_"), "Node2D", fence, position=v2(px(x0, LY.FENCE_Y)))
    sprite(seg, key)
fl = S.node("FenceLine", "StaticBody2D", "World", position=v2((0, round(LY.FENCE_Y * GY, 2))),
            collision_layer="4", collision_mask="0")
g0, g1 = LY.FENCE_GAP
for nm, a, b in (("West", 0.0, g0), ("East", g1, LY.W)):
    S.node(nm, "CollisionShape2D", fl, position=v2(((a + b) / 2 * PPM, -5)),
           shape=rect_shape((b - a) * PPM, 10))

# ---- 场景边界 ----
bd = S.node("Bounds", "StaticBody2D", ".", collision_layer="1", collision_mask="0")
W_PX, H_PX = LY.W * PPM, LY.H * GY
for nm, c, sz in (("Left", (-40, H_PX / 2), (80, H_PX + 800)), ("Right", (W_PX + 40, H_PX / 2), (80, H_PX + 800)),
                  ("Bottom", (W_PX / 2, H_PX + 40), (W_PX + 200, 80))):
    S.node(nm, "CollisionShape2D", bd, position=v2((round(c[0], 2), round(c[1], 2))), shape=rect_shape(*sz))

# ---- 角色 ----
pl = character("World", "Player", "CHR_01_Aleksei_Sheet", "NightPlayer", 8, 7, position=v2(px(*LY.SPAWN)))
cone_rig(pl, "VFX_Light_Cone_Flashlight", col(1, 0.95, 0.84), 1.25, 0.85, 12.5)
S.node("Aura", "PointLight2D", pl, texture=S.tex("VFX_Light_Radial_Soft"), texture_scale="0.42",
       color=col(0.7, 0.8, 1.0), energy="0.42", range_item_cull_mask="3")
for pat in LY.PATROLS:
    pts = ", ".join(f"{x * PPM:g}, {round(y * GY, 2):g}" for x, y in pat["pts"])
    so = character("World", pat["id"], "CHR_05_OSK_Sheet", "NightSoldier", 64, 7, groups=["night_osk"],
                   position=v2(px(*pat["pts"][0])), route=f"PackedVector2Array({pts})",
                   mode=f'"{pat["mode"]}"', pause_time=f'{pat["pause"]:g}')
    cone_rig(so, "VFX_Light_Cone_OSK", col(0.78, 0.9, 1.0), 1.35, 0.95, 14.0)
    # 枪口闪光：NightSoldier 用 $Muzzle 播放开火闪光（初始 energy=0，开火时设 3.2）。
    S.node("Muzzle", "PointLight2D", so, texture=S.tex("VFX_Light_Radial"),
           color=col(1, 0.82, 0.55), position=v2((0, -6)), texture_scale="0.18",
           energy="0.0", range_item_cull_mask="3")
for rb in LY.RABIDS:
    character("World", rb["id"], "CHR_03_Rabid_Sheet", "NightRabid", 32, 7, groups=["night_rabid"],
              position=v2(px(*rb["home"])), brute="true" if rb["brute"] else "false",
              home_radius=f'{rb["radius"]:g}')

for hf in LY.HALFS:
    character("World", hf["id"], "CHR_04_HalfHuman_Sheet", "NightHalf", 32, 7, groups=["night_half"],
              position=v2(px(*hf["pos"])), tag=f'"{hf["tag"]}"')

# ===========================================================================
# 灯光
# ===========================================================================
lights = S.node("Lights", "Node2D", ".")
FIRE_POS = [None]        # 第一个火堆的世界像素（火苗环境音要用）
STEAM_PIPE = next((q for q in LY.PROPS if q["id"] == "SteamPipe"), None)
VALVE = None if STEAM_PIPE is None else (
    (STEAM_PIPE["pos"][0] - STEAM_PIPE["fp"][0] / 2 + 5.0) * PPM, STEAM_PIPE["pos"][1] * GY - 100)


def _rig_glow():
    S.node("FacadeGlow", "PointLight2D", lights, texture=S.tex(GLOW_KEY),
           position=v2((W_PX / 2, round(base_y - FH + MAN[GLOW_KEY]["size"][1] / 2, 2))),
           energy="1.15", range_item_cull_mask="3")


def _rig_brazier(key):
    if key not in LY.LIGHTS:
        return
    bx, by = px(*LY.LIGHTS[key])
    if FIRE_POS[0] is None:
        FIRE_POS[0] = (bx, by)
    br = S.node(key.title().replace("_", ""), "Node2D", lights, groups=["night_warm"],
                position=v2((bx, by - 6)), script=SCRIPT("NightFlicker"), mode='"fire"',
                metadata__radius="2.6")
    light_pair(br, "VFX_Light_Radial", col(1, 0.62, 0.32), 1.55, 1.25, 1.5, shadow_mask=3, obj_scale=1.3)


def _rig_lamp(key):
    if key not in LY.LIGHTS:
        return
    lx, ly = px(*LY.LIGHTS[key])
    lr = S.node(key.title().replace("_", ""), "Node2D", lights, position=v2((lx + 64, ly)),
                script=SCRIPT("NightFlicker"), mode='"sodium"',
                flicker_seed=str(LY.LIGHT_SEEDS.get(key, 3)))
    light_pair(lr, "VFX_Light_Radial", col(1, 0.7, 0.4), 1.2, 0.85, 1.35, shadow_mask=3)
    S.node("Head", "PointLight2D", lr, position=v2((6, -347)), texture=S.tex("VFX_Light_Radial"),
           texture_scale="0.22", color=col(1, 0.8, 0.5), energy="2.2", range_item_cull_mask="1")


def _rig_terminal():
    if "terminal_x" not in LY.FACADE_FEATURES:
        return
    tx = LY.FACADE_FEATURES["terminal_x"] * PPM
    crt = S.node("Terminal", "Node2D", lights, position=v2((tx, round(base_y - 110, 2))),
                 script=SCRIPT("NightFlicker"), mode='"crt"')
    S.node("Light", "PointLight2D", crt, texture=S.tex("VFX_Light_Radial"), texture_scale="0.45",
           color=col(0.29, 0.87, 0.5), energy="1.1", range_item_cull_mask="3")


def _rig_vent():
    if "vent_x" not in LY.FACADE_FEATURES:
        return
    vx = LY.FACADE_FEATURES["vent_x"] * PPM
    vent = S.node("BoilerVent", "Node2D", lights, position=v2((vx, round(base_y - 18, 2))),
                  script=SCRIPT("NightFlicker"), mode='"fire"', strength="0.6")
    S.node("Light", "PointLight2D", vent, texture=S.tex("VFX_Light_Radial"), texture_scale="0.5",
           color=col(1, 0.55, 0.25), energy="1.0", range_item_cull_mask="3")


def _rig_signal():
    if "signal" not in LY.LIGHTS:
        return
    sx, sy = px(*LY.LIGHTS["signal"])
    sig = S.node("Signal", "Node2D", lights, position=v2((sx, sy)), script=SCRIPT("NightFlicker"),
                 mode='"steady"')
    S.node("Lens", "PointLight2D", sig, position=v2((0, -196)), texture=S.tex("VFX_Light_Radial"),
           texture_scale="0.14", color=col(1, 0.28, 0.2), energy="2.4", range_item_cull_mask="1")
    S.node("Pool", "PointLight2D", sig, texture=S.tex("VFX_Light_Radial"), texture_scale="0.5",
           color=col(1, 0.25, 0.18), energy="0.6", range_item_cull_mask="2")


def _rig_tower():
    """调度塔的玻璃调度室：CRT 绿光 + 值班台灯，从机车库屋顶后面透出来。"""
    if "tower_x" not in LY.FACADE_FEATURES:
        return
    txp = LY.FACADE_FEATURES["tower_x"] * PPM
    tw = S.node("Tower", "Node2D", lights, position=v2((txp, round(base_y - 430, 2))),
                script=SCRIPT("NightFlicker"), mode='"crt"')
    S.node("CRT", "PointLight2D", tw, texture=S.tex("VFX_Light_Radial"), texture_scale="0.6",
           color=col(0.29, 0.87, 0.5), energy="1.1", range_item_cull_mask="3")
    S.node("Desk", "PointLight2D", tw, position=v2((40, 8)), texture=S.tex("VFX_Light_Radial"),
           texture_scale="0.4", color=col(1, 0.78, 0.48), energy="0.8", range_item_cull_mask="3")


def _rig_searchlight():
    sl = LY.has("SEARCHLIGHT", None)
    if not sl:
        return
    slp = px(*sl["pos"])
    srch = S.node("Searchlight", "Node2D", ".", groups=["night_searchlight"], position=v2(slp),
                  script=SCRIPT("NightSearchlight"), sweep_min_deg=f'{sl["sweep"][0]:g}',
                  sweep_max_deg=f'{sl["sweep"][1]:g}', period=f'{sl["period"]:g}',
                  range_m=f'{sl["range"]:g}', half_deg=f'{sl["half"]:g}')
    rg = S.node("Rig", "Node2D", srch, scale=v2((1, SQ)))
    piv = S.node("Pivot", "Node2D", rg)
    sl_sc = round(sl["range"] * PPM / 1024, 4)
    light_pair(piv, "VFX_Searchlight_Cone", col(1, 0.94, 0.74), 1.9, 1.2, sl_sc,
               offset=(round(512 * sl_sc, 2), 0))
    S.node("LampHead", "PointLight2D", srch, position=v2((-33, -399)), texture=S.tex("VFX_Light_Radial"),
           texture_scale="0.25", color=col(1, 0.95, 0.8), energy="2.5", range_item_cull_mask="1")


def _emit_rig(entry):
    if entry == "facade_glow":
        _rig_glow()
    elif entry.startswith("brazier"):
        _rig_brazier(entry)
    elif entry.startswith("lamp_"):
        _rig_lamp(entry)
    elif entry == "terminal":
        _rig_terminal()
    elif entry == "vent":
        _rig_vent()
    elif entry == "signal":
        _rig_signal()
    elif entry == "tower":
        _rig_tower()
    elif entry == "searchlight":
        _rig_searchlight()
    else:
        raise SystemExit(f"LIGHT_RIG 里不认识的灯位 '{entry}'")


# 灯光节点的生成顺序由关卡的 LIGHT_RIG 决定（yard 保持第一版的顺序 → .tscn 逐字节不变）
for _entry in LY.has("LIGHT_RIG", ["facade_glow", "brazier", "terminal", "vent", "signal",
                                   "searchlight"]):
    _emit_rig(_entry)

# ---- 蒸汽阀（有 SteamPipe 才有）----
if VALVE is not None:
    valve = VALVE
    S.node("Steam", "GPUParticles2D", ".", position=v2((round(valve[0], 2), round(valve[1], 2))), amount="22",
           lifetime="2.6", preprocess="3.0", texture=S.tex("VFX_Steam_Puff"),
           visibility_rect="Rect2(-300, -400, 600, 500)",
           process_material=S.subres(
               "ParticleProcessMaterial", particle_flag_disable_z="true", direction="Vector3(0.35, -1, 0)",
               spread="18.0", initial_velocity_min="24.0", initial_velocity_max="48.0",
               gravity="Vector3(16, -10, 0)", scale_min="0.5", scale_max="1.6", color=col(0.92, 0.95, 1, 0.32)))

# ---- 标记点 / 冻雪泥 ----
mk = S.node("Markers", "Node2D", ".")
S.node("Spawn", "Marker2D", mk, position=v2(px(*LY.SPAWN)))
S.node("Exit", "Marker2D", mk, position=v2(px(*LY.EXIT)))
for i, (cx, cy, rx, ry) in enumerate(LY.SLUSH):
    S.node(f"Slush{i}", "Marker2D", mk, groups=["night_slush"], position=v2(px(cx, cy)),
           metadata__rx=f"{rx:g}", metadata__ry=f"{ry:g}")

# ---- 镜头 + 雪 ----
cam = S.node("Camera2D", "Camera2D", ".", position=v2(px(*LY.SPAWN)), limit_left="0",
             limit_top=str(int(base_y - FH)), limit_right=str(int(W_PX)), limit_bottom=str(int(H_PX)),
             position_smoothing_enabled="true", position_smoothing_speed="6.0")
S.node("Snow", "GPUParticles2D", cam, amount="900", lifetime="8.0", preprocess="8.0",
       texture=S.tex("VFX_Snow_Particle"), local_coords="false",
       visibility_rect="Rect2(-1300, -900, 2600, 1800)",
       process_material=S.subres(
           "ParticleProcessMaterial", particle_flag_disable_z="true", emission_shape="3",
           emission_box_extents="Vector3(1200, 760, 1)", direction="Vector3(0.3, 1, 0)", spread="14.0",
           initial_velocity_min="30.0", initial_velocity_max="70.0", gravity="Vector3(22, 34, 0)",
           scale_min="0.22", scale_max="0.85", color=col(0.92, 0.96, 1, 0.9), turbulence_enabled="true",
           turbulence_noise_strength="2.0", turbulence_noise_scale="5.0",
           turbulence_influence_min="0.04", turbulence_influence_max="0.12"))

fs = S.node("FrontSnow", "CanvasLayer", ".", layer="3")
S.node("Flakes", "GPUParticles2D", fs, position=v2((960, 540)), amount="110", lifetime="3.0",
       preprocess="3.0", texture=S.tex("VFX_Snow_Particle"), visibility_rect="Rect2(-1200, -800, 2400, 1600)",
       process_material=S.subres(
           "ParticleProcessMaterial", particle_flag_disable_z="true", emission_shape="3",
           emission_box_extents="Vector3(1150, 640, 1)", direction="Vector3(0.38, 1, 0)", spread="8.0",
           initial_velocity_min="220.0", initial_velocity_max="340.0", gravity="Vector3(0, 0, 0)",
           scale_min="1.2", scale_max="2.6", color=col(0.85, 0.9, 1, 0.3)))

# ---- 后处理 / 叠加 / HUD ----
post = S.node("Post", "CanvasLayer", ".", layer="5")
S.node("Grade", "ColorRect", post, anchors_preset="15", anchor_right="1.0", anchor_bottom="1.0",
       grow_horizontal="2", grow_vertical="2", mouse_filter="2",
       material=S.subres("ShaderMaterial", shader=S.res("res://shaders/night_post.gdshader", "Shader"),
                         **{"shader_parameter/fog_tex": S.tex("VFX_FogNoise")}))
ol = S.node("OverlayLayer", "CanvasLayer", ".", layer="6", follow_viewport_enabled="true")
S.node("Overlay", "Node2D", ol, texture_filter="2", script=SCRIPT("NightOverlay"))
hud = S.node("HUD", "CanvasLayer", ".", layer="10")
S.node("Root", "Control", hud, anchors_preset="15", anchor_right="1.0", anchor_bottom="1.0",
       grow_horizontal="2", grow_vertical="2", mouse_filter="2")

# ---- 环境音（关卡的 AMBIENCE 决定有哪几路、什么顺序）----
def wav(key):
    return S.res(MAN[key]["path"], "AudioStream")


for role in LY.has("AMBIENCE", ["wind", "fire", "steam", "buzz"]):
    if role == "wind":
        S.node("Wind", "AudioStreamPlayer", ".", stream=wav("AMB_Wind_Blizzard_Loop"), volume_db="-9.0")
    elif role == "fire" and FIRE_POS[0] is not None:
        S.node("FireAudio", "AudioStreamPlayer2D", ".", position=v2(FIRE_POS[0]),
               stream=wav("AMB_Fire_Crackle_Loop"), max_distance="900.0", volume_db="-2.0")
    elif role == "steam" and VALVE is not None:
        S.node("SteamAudio", "AudioStreamPlayer2D", ".",
               position=v2((round(VALVE[0], 2), round(VALVE[1] + 80, 2))),
               stream=wav("AMB_Steam_Hiss_Loop"), max_distance="700.0", volume_db="-8.0")
    elif role == "buzz":
        _lk = next((k for k in LY.LIGHTS if k.startswith("lamp_")), None)
        if _lk:
            lwx, lwy = px(*LY.LIGHTS[_lk])
            S.node("LampBuzz", "AudioStreamPlayer2D", ".", position=v2((lwx, lwy)),
                   stream=wav("AMB_Sodium_Buzz_Loop"), max_distance="500.0", volume_db="-14.0")

S.write(OUT)
print("scene ->", OUT, f"({len(S.nodes)} nodes, {len(S.ext)} ext, {len(S.sub)} sub)")
