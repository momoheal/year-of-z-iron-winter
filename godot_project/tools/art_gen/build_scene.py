"""从 layout.py + art/night_yard_manifest.json 生成 res://scenes/night_explore.tscn。

这是一次性「搭场景」脚本：生成后可以直接在 Godot 编辑器里拖动、调灯、改路线。
重新运行会覆盖 .tscn（编辑器里的手工修改会丢），所以改完布局后再跑，或从此在编辑器里维护。
"""
from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import layout as LY  # noqa: E402

PROJ = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(PROJ, "scenes", "night_explore.tscn")
PPM, SQ = 64.0, 0.62
GY = PPM * SQ

with open(os.path.join(PROJ, "art", "night_yard_manifest.json"), encoding="utf-8") as f:
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
S.node("NightExplore", "Node2D", None, texture_filter="2", script=SCRIPT("NightExplore"))
S.node("CanvasModulate", "CanvasModulate", ".", color=col(0.27, 0.32, 0.45))
S.node("Ground", "Sprite2D", ".", z_index="-1", light_mask="2", centered="false",
       texture=S.tex("TIL_Ground_NightYard_Baked"))
# 血迹等地面贴花（运行时往里加），画在地面之上、所有立起的精灵之下
S.node("Decals", "Node2D", ".", z_index="-1")
S.node("World", "Node2D", ".", y_sort_enabled="true")

# ---- 立面（北侧赫鲁晓夫楼）----
base_y = LY.FACADE_BASE_Y * GY
fac = S.node("Facade", "StaticBody2D", "World", position=v2((0, round(base_y, 2))), collision_layer="1",
             collision_mask="0")
S.node("Sprite", "Sprite2D", fac, texture=S.tex("TIL_Facade_Khrushchyovka_A"), centered="false",
       offset=v2((0, -600)))
S.node("Shape", "CollisionShape2D", fac, position=v2((LY.W * PPM / 2, -150)),
       shape=rect_shape(LY.W * PPM, 300))

# ---- 道具 ----
S.node("Props", "Node2D", "World", y_sort_enabled="true")
LAYER_BITS = {0: 0, 1: 1, 2: 2, 3: 4}
FADE = {"Boxcar03", "WaterTower", "Watchtower", "CarWreck"}
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
    if p["id"] in FADE:
        groups.append("night_fade")
    n = S.node(p["id"], "StaticBody2D", "World/Props", groups=groups or None, position=v2(px(*p["pos"])),
               collision_layer=str(LAYER_BITS[p["layer"]]), collision_mask="0", **meta)
    sprite(n, p["art"])
    fw, fd = p["fp"][0] * PPM, p["fp"][1] * GY
    if p["layer"]:
        S.node("Shape", "CollisionShape2D", n, position=v2((0, round(-fd / 2, 2))), shape=rect_shape(fw, fd))
    if p["layer"] in (1, 2) and p["id"] not in ("Brazier", "LampWest", "LampEast", "SignalPost", "Bench"):
        S.node("Occluder", "LightOccluder2D", n,
               occluder=occluder(round(-fw / 2, 1), round(-fd, 1), round(fw / 2, 1), 0))
    if p["id"] == "Brazier":
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
S.node("FacadeGlow", "PointLight2D", lights, texture=S.tex("VFX_Facade_WindowGlow"),
       position=v2((W_PX / 2, round(base_y - 600 + MAN["VFX_Facade_WindowGlow"]["size"][1] / 2, 2))),
       energy="1.15", range_item_cull_mask="3")

bx, by = px(*LY.LIGHTS["brazier"])
br = S.node("Brazier", "Node2D", lights, groups=["night_warm"], position=v2((bx, by - 6)),
            script=SCRIPT("NightFlicker"), mode='"fire"', metadata__radius="2.6")
light_pair(br, "VFX_Light_Radial", col(1, 0.62, 0.32), 1.55, 1.25, 1.5, shadow_mask=3, obj_scale=1.3)

for key, sd in (("lamp_west", 3), ("lamp_east", 7)):
    lx, ly = px(*LY.LIGHTS[key])
    lr = S.node(key.title().replace("_", ""), "Node2D", lights, position=v2((lx + 64, ly)),
                script=SCRIPT("NightFlicker"), mode='"sodium"', flicker_seed=str(sd))
    light_pair(lr, "VFX_Light_Radial", col(1, 0.7, 0.4), 1.2, 0.85, 1.35, shadow_mask=3)
    S.node("Head", "PointLight2D", lr, position=v2((6, -347)), texture=S.tex("VFX_Light_Radial"),
           texture_scale="0.22", color=col(1, 0.8, 0.5), energy="2.2", range_item_cull_mask="1")

tx = LY.FACADE_FEATURES["terminal_x"] * PPM
crt = S.node("Terminal", "Node2D", lights, position=v2((tx, round(base_y - 110, 2))),
             script=SCRIPT("NightFlicker"), mode='"crt"')
S.node("Light", "PointLight2D", crt, texture=S.tex("VFX_Light_Radial"), texture_scale="0.45",
       color=col(0.29, 0.87, 0.5), energy="1.1", range_item_cull_mask="3")
vx = LY.FACADE_FEATURES["vent_x"] * PPM
vent = S.node("BoilerVent", "Node2D", lights, position=v2((vx, round(base_y - 18, 2))),
              script=SCRIPT("NightFlicker"), mode='"fire"', strength="0.6")
S.node("Light", "PointLight2D", vent, texture=S.tex("VFX_Light_Radial"), texture_scale="0.5",
       color=col(1, 0.55, 0.25), energy="1.0", range_item_cull_mask="3")
sx, sy = px(*LY.LIGHTS["signal"])
sig = S.node("Signal", "Node2D", lights, position=v2((sx, sy)), script=SCRIPT("NightFlicker"), mode='"steady"')
S.node("Lens", "PointLight2D", sig, position=v2((0, -196)), texture=S.tex("VFX_Light_Radial"),
       texture_scale="0.14", color=col(1, 0.28, 0.2), energy="2.4", range_item_cull_mask="1")
S.node("Pool", "PointLight2D", sig, texture=S.tex("VFX_Light_Radial"), texture_scale="0.5",
       color=col(1, 0.25, 0.18), energy="0.6", range_item_cull_mask="2")

sl = LY.SEARCHLIGHT
slp = px(*sl["pos"])
srch = S.node("Searchlight", "Node2D", ".", groups=["night_searchlight"], position=v2(slp),
              script=SCRIPT("NightSearchlight"), sweep_min_deg=f'{sl["sweep"][0]:g}',
              sweep_max_deg=f'{sl["sweep"][1]:g}', period=f'{sl["period"]:g}', range_m=f'{sl["range"]:g}',
              half_deg=f'{sl["half"]:g}')
rig = S.node("Rig", "Node2D", srch, scale=v2((1, SQ)))
piv = S.node("Pivot", "Node2D", rig)
sl_sc = round(sl["range"] * PPM / 1024, 4)
light_pair(piv, "VFX_Searchlight_Cone", col(1, 0.94, 0.74), 1.9, 1.2, sl_sc, offset=(round(512 * sl_sc, 2), 0))
S.node("LampHead", "PointLight2D", srch, position=v2((-33, -399)), texture=S.tex("VFX_Light_Radial"),
       texture_scale="0.25", color=col(1, 0.95, 0.8), energy="2.5", range_item_cull_mask="1")

# ---- 蒸汽阀 ----
pipe = next(p for p in LY.PROPS if p["id"] == "SteamPipe")
valve = (pipe["pos"][0] - pipe["fp"][0] / 2 + 5.0) * PPM, pipe["pos"][1] * GY - 100
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
             limit_top=str(int(base_y - 600)), limit_right=str(int(W_PX)), limit_bottom=str(int(H_PX)),
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

# ---- 环境音 ----
def wav(key):
    return S.res(MAN[key]["path"], "AudioStream")


S.node("Wind", "AudioStreamPlayer", ".", stream=wav("AMB_Wind_Blizzard_Loop"), volume_db="-9.0")
S.node("FireAudio", "AudioStreamPlayer2D", ".", position=v2((bx, by)), stream=wav("AMB_Fire_Crackle_Loop"),
       max_distance="900.0", volume_db="-2.0")
S.node("SteamAudio", "AudioStreamPlayer2D", ".", position=v2((round(valve[0], 2), round(valve[1] + 80, 2))),
       stream=wav("AMB_Steam_Hiss_Loop"), max_distance="700.0", volume_db="-8.0")
lwx, lwy = px(*LY.LIGHTS["lamp_west"])
S.node("LampBuzz", "AudioStreamPlayer2D", ".", position=v2((lwx, lwy)), stream=wav("AMB_Sodium_Buzz_Loop"),
       max_distance="500.0", volume_db="-14.0")

S.write(OUT)
print("scene ->", OUT, f"({len(S.nodes)} nodes, {len(S.ext)} ext, {len(S.sub)} sub)")
