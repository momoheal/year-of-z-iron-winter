"""render_preview — 把生成出来的 .tscn 直接「拍」成 PNG（不需要 Godot 引擎）。

用途：在没有引擎的机器上做美术 / 摆位验收。原理很土但很准：
读 `scenes/night_<id>.tscn` 里的节点（position / offset / texture / z_index），
按 y-sort 规则把真实 PNG 贴回去，再叠 CanvasModulate 的夜色与 PointLight2D 的补光，
最后加暗角与雪噪点 —— 所以图里的位置就是游戏里的位置。

用法（在 godot_project/tools/art_gen 下）：
    python render_preview.py                     # 全部关卡 × 中性光 / 夜色 两版
    python render_preview.py --level manor       # 只拍一张图
    python render_preview.py --crops             # 只出哨位特写
输出到 docs/ui/verify/。
"""
from __future__ import annotations

import math
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.abspath(os.path.join(HERE, "..", ".."))
REPO = os.path.abspath(os.path.join(PROJ, ".."))
OUT = os.path.join(REPO, "docs", "ui", "verify")

PPM, SQ = 64.0, 0.62
GY = PPM * SQ
PAD = 300          # 画布上方留出的「天空 / 立面」高度（引擎里由相机取景，预览图里补出来）
BAND = 44          # 顶部标题条高度：第一行关卡名，第二行场景文件 + 说明

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

SCENES = {
    "yard": dict(path="res://scenes/night_explore.tscn", title="L03 · ШИРОКАЯ КОЛЕЯ · FREIGHT YARD"),
    "marshalling": dict(path="res://scenes/night_marshalling.tscn", title="L04 · ЗАПАДНЫЙ СОРТИРОВОЧНЫЙ ПАРК"),
    "manor": dict(path="res://scenes/night_manor.tscn", title="L05 · СОСНОВАЯ УСАДЬБА · MANOR"),
    "mine": dict(path="res://scenes/night_mine.tscn", title="L07M · ШАХТА №3 · MINE SHAFT No.3"),
}


# ---------------------------------------------------------------------------
# .tscn 解析
# ---------------------------------------------------------------------------
def res_path(rid: str) -> str:
    return os.path.join(PROJ, rid.replace("res://", "").replace("/", os.sep))


def v2(txt: str) -> tuple[float, float]:
    m = re.search(r"Vector2\(([-\d.e]+), ([-\d.e]+)\)", txt)
    return (float(m.group(1)), float(m.group(2))) if m else (0.0, 0.0)


def v4(txt: str) -> tuple[float, float, float, float]:
    m = re.search(r"Color\(([-\d.e]+), ([-\d.e]+), ([-\d.e]+), ([-\d.e]+)\)", txt)
    return tuple(float(m.group(i)) for i in (1, 2, 3, 4)) if m else (1.0, 1.0, 1.0, 1.0)


def parse_tscn(path: str):
    src = open(path, encoding="utf-8").read()
    ext = dict(re.findall(r'\[ext_resource type="[^"]+" path="([^"]+)" id="([^"]+)"\]', src))
    ext = {v: k for k, v in ext.items()}
    # 场景根标题行
    nodes: dict[str, dict] = {}
    order: list[str] = []
    cur = None
    for line in src.split("\n"):
        if line.startswith("[node "):
            head = line
            name = re.search(r'name="([^"]*)"', head).group(1)
            typ = re.search(r'type="([^"]*)"', head).group(1)
            parent = re.search(r'parent="([^"]*)"', head)
            parent = parent.group(1) if parent else ""
            key = name if parent in ("", ".") else parent + "/" + name
            nodes[key] = dict(type=typ, parent=parent, props={})
            order.append(key)
            cur = nodes[key]
        elif line.startswith("[") or line.strip() == "":
            cur = None if line.startswith("[") else cur
        elif cur is not None and "=" in line:
            k, v = line.split("=", 1)
            cur["props"][k.strip()] = v.strip()
    return nodes, order, ext


def gpos(nodes: dict, key: str) -> tuple[float, float]:
    x = y = 0.0
    p = key
    while p and p in nodes:
        pos = nodes[p]["props"].get("position")
        if pos:
            dx, dy = v2(pos)
            x += dx
            y += dy
        parent = nodes[p]["parent"]
        p = None if parent in ("", ".") else parent
    return x, y


def owner_base(nodes: dict, key: str) -> float:
    """y-sort 用的基准：World/Props 下那层「道具本体」的 y。"""
    p = key
    while p and p in nodes:
        parent = nodes[p]["parent"]
        # 取「最靠下」的那层容器：World/Props/WeaponRack/Sprite → 用 WeaponRack 的 y 排序
        if parent in ("World/Props", "World", "World/Actors", "World/Items", "", "."):
            return gpos(nodes, p)[1]
        p = parent
    return gpos(nodes, key)[1]


def collect_sprites(nodes, order, ext):
    out = []
    for key in order:
        n = nodes[key]
        if n["type"] != "Sprite2D":
            continue
        tex = n["props"].get("texture", "")
        m = re.search(r'ExtResource\("([^"]+)"\)', tex)
        if not m or m.group(1) not in ext:
            continue
        path = res_path(ext[m.group(1)])
        if not os.path.exists(path):
            continue
        centered = n["props"].get("centered", "true") != "false"
        ox, oy = v2(n["props"].get("offset", "Vector2(0, 0)"))
        sc = v2(n["props"].get("scale", "Vector2(1, 1)"))
        gx, gy = gpos(nodes, key)
        z = int(float(n["props"].get("z_index", "0")))
        out.append(dict(key=key, path=path, gx=gx + ox * sc[0], gy=gy + oy * sc[1],
                        scale=sc, centered=centered,
                        z=z, sort_y=owner_base(nodes, key),
                        flip_h=n["props"].get("flip_h", "false") == "true",
                        hframes=int(float(n["props"].get("hframes", "1"))),
                        vframes=int(float(n["props"].get("vframes", "1"))),
                        frame=int(float(n["props"].get("frame", "0")))))
    return out


def collect_lights(nodes, order, ext):
    out = []
    for key in order:
        n = nodes[key]
        if n["type"] not in ("PointLight2D",):
            continue
        tex = n["props"].get("texture", "")
        m = re.search(r'ExtResource\("([^"]+)"\)', tex)
        path = res_path(ext[m.group(1)]) if (m and ext.get(m.group(1))) else ""
        if not path or not os.path.exists(path):
            continue
        gx, gy = gpos(nodes, key)
        energy = float(n["props"].get("energy", "1.0"))
        tscale = float(n["props"].get("texture_scale", "1.0"))
        col = v4(n["props"].get("color", "Color(1, 1, 1, 1)"))
        out.append(dict(path=path, pos=(gx, gy), energy=energy, scale=tscale, color=col,
                        key=key))
    return out


# ---------------------------------------------------------------------------
# 渲染
# ---------------------------------------------------------------------------
def to_np(img: Image.Image) -> np.ndarray:
    return np.asarray(img.convert("RGBA"), np.float32) / 255.0


def over(dst: np.ndarray, src: np.ndarray, x: int, y: int) -> None:
    """alpha 合成 src 到 dst 的 (x,y)（自动裁边）。"""
    H, W = dst.shape[:2]
    h, w = src.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + w), min(H, y + h)
    if x1 <= x0 or y1 <= y0:
        return
    s = src[y0 - y:y1 - y, x0 - x:x1 - x]
    d = dst[y0:y1, x0:x1]
    a = s[..., 3:4]
    d[..., :3] = d[..., :3] * (1 - a) + s[..., :3] * a
    d[..., 3:4] = np.clip(d[..., 3:4] + a, 0, 1)


def add_glow(dst: np.ndarray, glow: np.ndarray, pos, color, k: float) -> None:
    H, W = dst.shape[:2]
    h, w = glow.shape[:2]
    x = int(pos[0] - w / 2)
    y = int(pos[1] - h / 2)
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + w), min(H, y + h)
    if x1 <= x0 or y1 <= y0:
        return
    g = glow[y0 - y:y1 - y, x0 - x:x1 - x]
    a = g[..., 3:4] * k
    col = np.array(color[:3], np.float32)[None, None, :]
    dst[y0:y1, x0:x1, :3] = np.clip(dst[y0:y1, x0:x1, :3] + g[..., :3] * a * col * 1.6, 0, 1)


# 三区样式（与 scripts/night/NightZones.gd 的 INFO 保持一致）
ZONE_STYLE = {
    "white": ((0.62, 0.78, 0.88), 0.075, "ZONE A · SAFE"),
    "red": ((0.78, 0.28, 0.23), 0.115, "ZONE B · CURFEW"),
    "black": ((0.23, 0.63, 0.71), 0.165, "ZONE C · SUNKEN"),
}


def scene_zones(scene_path: str) -> str:
    txt = open(scene_path, encoding="utf-8").read()
    m = re.search(r'metadata/zones = "([^"]*)"', txt)
    return m.group(1) if m else ""


def zone_layer(W: int, H: int, src: str):
    """地面上的三区色带（和游戏里 NightZoneField 画的一致）：淡染 + 上沿虚线 + 标签。"""
    if not src:
        return None
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT_B, 26)
    for chunk in src.split("|"):
        if ":" not in chunk:
            continue
        zid, rs = chunk.split(":", 1)
        style = ZONE_STYLE.get(zid.strip())
        if style is None:
            continue
        (r, g, b), a, tag = style
        col = (int(r * 255), int(g * 255), int(b * 255))
        for rect in rs.split(";"):
            n = [float(v) for v in rect.split(",")]
            if len(n) != 4:
                continue
            x0 = int(n[0] * PPM)
            x1 = int(n[2] * PPM)
            y0 = int(n[1] * GY) + PAD
            y1 = int(n[3] * GY) + PAD
            d.rectangle([x0, y0, x1, y1], fill=(*col, int(a * 255)))
            x = x0
            while x < x1:                      # 上沿虚线
                d.line([x, y0, min(x + 26, x1), y0], fill=(*col, 205), width=5)
                x += 42
            d.line([x0, y1, x1, y1], fill=(*col, 60), width=2)
            for tx in (x0 + 40, int(x0 + (x1 - x0) * 0.62)):
                d.text((tx, y0 + 52), tag, font=f, fill=(*col, 115))
    return img


def render(level: str, night: bool, scale: float = 0.62, actors: bool = True) -> Image.Image:
    spec = SCENES[level]
    scene = res_path(spec["path"])
    nodes, order, ext = parse_tscn(scene)
    zsrc = scene_zones(scene)
    sprites = collect_sprites(nodes, order, ext)
    if not actors:
        # 特写图里把角色藏起来：验收的是道具本身，别被路过的清杀兵挡住
        sprites = [s for s in sprites if "CHR_" not in os.path.basename(s["path"])]
    lights = collect_lights(nodes, order, ext)

    # 画布尺寸 = 关卡 W/H（从地面图的尺寸反推）
    ground = None
    for s in sprites:
        if "Ground" in os.path.basename(s["path"]):
            ground = s
            break
    if ground is None:
        raise SystemExit("找不到地面图：" + scene)
    gimg = Image.open(ground["path"]).convert("RGBA")
    W, H0 = gimg.size
    H = H0 + PAD
    canvas = np.zeros((H, W, 4), np.float32)
    canvas[..., :3] = np.array([0.045, 0.05, 0.055], np.float32)
    canvas[..., 3] = 1.0

    # 1) 地面 / 立面 / 道具：按 z_index → y-sort 排序
    draws = sorted(sprites, key=lambda s: (s["z"], s["sort_y"] if s["z"] >= 0 else -1e9))
    for s in draws:
        img = Image.open(s["path"]).convert("RGBA")
        # 精灵表：只取当前帧（角色 8×3 / 火苗 6×1），否则整张表会被当成一张图贴上去
        hf, vf = s["hframes"], s["vframes"]
        if hf > 1 or vf > 1:
            fw, fh = img.width // hf, img.height // vf
            f = s["frame"] % (hf * vf)
            img = img.crop(((f % hf) * fw, (f // hf) * fh, (f % hf) * fw + fw, (f // hf) * fh + fh))
        if s["flip_h"]:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        sx, sy = s.get("scale", (1.0, 1.0))
        if abs(sx - 1.0) > 1e-3 or abs(sy - 1.0) > 1e-3:
            img = img.resize((max(1, int(img.width * sx)), max(1, int(img.height * sy))), Image.LANCZOS)
        arr = to_np(img)
        x = int(round(s["gx"] - (arr.shape[1] / 2 if s["centered"] else 0)))
        y = int(round(s["gy"] + PAD - (arr.shape[0] / 2 if s["centered"] else 0)))
        over(canvas, arr, x, y)
        if "Ground" in os.path.basename(s["path"]):
            zl = zone_layer(W, H, zsrc)
            if zl is not None:
                over(canvas, to_np(zl), 0, 0)

    # 2) 夜色：把 CanvasModulate 的颜色乘上去（灯再补回来）
    mod = nodes.get("CanvasModulate", {}).get("props", {}).get("color")
    modc = v4(mod) if mod else (0.27, 0.32, 0.45, 1.0)
    if night:
        # 夜色：CanvasModulate 压暗成冷调；灯只取径向光斑（锥体 / 立面窗光的贴图是给 Light2D 用的，
        # 直接当精灵贴会变成大片白多边形，预览里一律跳过）
        m = np.array([modc[0] * 0.58 + 0.07, modc[1] * 0.58 + 0.08, modc[2] * 0.62 + 0.10], np.float32)
        canvas[..., :3] *= m[None, None, :]
        for li in lights:
            if li["energy"] <= 0.01:
                continue
            base = os.path.basename(li["path"])
            if not ("Radial" in base or "Halo" in base):
                continue
            g = Image.open(li["path"]).convert("RGBA")
            tw = max(8, int(g.width * li["scale"]))
            g = g.resize((tw, max(8, int(g.height * li["scale"]))), Image.BILINEAR)
            px, py = li["pos"]
            add_glow(canvas, to_np(g), (px, py + PAD), li["color"], min(1.1, li["energy"] * 0.30))

    # 3) 暗角 + 雪噪点（游戏里由 post shader 与粒子给）
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    nx = (xx / W - 0.5) * 2.0
    ny = (yy / H - 0.5) * 2.0
    vig = np.clip(1.0 - 0.26 * (nx ** 2 + ny ** 2), 0.6, 1.0)
    canvas[..., :3] *= vig[..., None]
    rng = np.random.default_rng(7)
    grain = rng.normal(0.0, 0.012, (H, W, 1)).astype(np.float32)
    canvas[..., :3] = np.clip(canvas[..., :3] + grain, 0, 1)

    img = Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8), "RGBA").convert("RGB")

    # 4) 标题条（拉丁 / 西里尔，避免缺中文字体）
    band = Image.new("RGB", (img.width, BAND), (9, 11, 12))
    img = Image.vstack([band, img]) if hasattr(Image, "vstack") else _vstack(band, img)
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT_B, 17)
    fs = ImageFont.truetype(FONT, 13)
    d.text((14, 5), spec["title"], font=f, fill=(216, 209, 191))
    tag = "NIGHT GRADE" if night else "NEUTRAL LIGHT"
    d.text((img.width - 14 - d.textlength(tag, font=fs), 6), tag, font=fs,
           fill=(200, 162, 87) if night else (146, 140, 124))
    sub = f"scene {spec['path']}  ·  mock composite of the .tscn (engine not required)"
    d.text((14, 26), sub, font=ImageFont.truetype(FONT, 12), fill=(132, 128, 116))

    if scale != 1.0:
        img = img.resize((int(img.width * scale), int(img.height * scale)), Image.LANCZOS)
    return img


def _vstack(a: Image.Image, b: Image.Image) -> Image.Image:
    out = Image.new("RGB", (max(a.width, b.width), a.height + b.height))
    out.paste(a, (0, 0))
    out.paste(b, (0, a.height))
    return out


# ---------------------------------------------------------------------------
# 哨位特写（新道具 + 编号标注）
# ---------------------------------------------------------------------------
CROPS = {
    "marshalling": dict(level="L04 WEST SORTING PARK", items=[
        dict(m=(33.0, 9.2), art="PRP_Sandbag_Line.png", title="1 · SANDBAGS",
             note="low cover (layer 2)", win=(3.4, 2.6, 1.8)),
        dict(m=(24.2, 5.6), art="PRP_Ammo_Box_Open.png", title="2 · AMMO BOX",
             note="guaranteed rifle rounds", win=(2.2, 2.2, 1.4)),
        dict(m=(12.4, 4.1), art="PRP_WeaponRack.png", title="3 · WEAPON RACK",
             note="one crowbar left on the hooks", win=(2.0, 2.4, 1.4)),
    ]),
    "manor": dict(level="L05 PINE MANOR", items=[
        dict(m=(27.0, 12.6), art="PRP_Sandbag_Line.png", title="1 · SANDBAGS",
             note="pairs with the forklift", win=(3.4, 2.6, 1.8)),
        dict(m=(21.0, 6.2), art="PRP_Ammo_Box_Open.png", title="2 · AMMO BOX",
             note="guaranteed rifle rounds", win=(2.2, 2.2, 1.4)),
        dict(m=(9.2, 4.2), art="PRP_WeaponRack.png", title="3 · WEAPON RACK",
             note="beside the Batch-409 pallet", win=(2.0, 2.4, 1.4)),
    ]),
    "mine": dict(level="L07M SHAFT No.3 · BLAST FACE", items=[
        dict(m=(38.5, 13.4), art="PRP_DummyTower_Mannequin.png", title="1 · DUMMY TOWER",
             note="mannequin + pig-snout respirator, no light", win=(2.8, 8.8, 2.4)),
        dict(m=(36.5, 28.4), art="PRP_SporeFace.png", title="2 · SPORE FACE",
             note="permafrost strata + the grey spore band", win=(3.8, 5.0, 1.6)),
        dict(m=(29.5, 26.8), art="PRP_Detonator_Rig.png", title="3 · DETONATOR RIG",
             note="guaranteed intel: core + blast ledger", win=(1.9, 1.9, 1.3)),
    ]),
}


def dashed(d, box, col, dash=9, gap=6, width=2):
    x0, y0, x1, y1 = box
    for (ax, ay, bx, by) in ((x0, y0, x1, y0), (x1, y0, x1, y1),
                             (x1, y1, x0, y1), (x0, y1, x0, y0)):
        n = max(1, int(math.hypot(bx - ax, by - ay) // (dash + gap)))
        for i in range(n + 1):
            t0 = i * (dash + gap) / max(1e-6, math.hypot(bx - ax, by - ay))
            t1 = min(1.0, (i * (dash + gap) + dash) / max(1e-6, math.hypot(bx - ax, by - ay)))
            d.line([ax + (bx - ax) * t0, ay + (by - ay) * t0,
                    ax + (bx - ax) * t1, ay + (by - ay) * t1], fill=col, width=width)


def sprite_rect(level: str, art: str, near) -> tuple[float, float, float, float] | None:
    """在关卡里找到这件道具的精灵，算出它在画布上的外框（画布不含标题条）。"""
    nodes, order, ext = R_parse(level)
    best, bd = None, 1e18
    for s in collect_sprites(nodes, order, ext):
        if os.path.basename(s["path"]) != art:
            continue
        d = (s["gx"] - near[0]) ** 2 + (s["gy"] - near[1]) ** 2
        if d < bd:
            best, bd = s, d
    if best is None:
        return None
    img = Image.open(best["path"])
    hf, vf = best["hframes"], best["vframes"]
    w, h = img.width / hf, img.height / vf
    x0 = best["gx"] - w / 2 if best["centered"] else best["gx"]
    y0 = best["gy"] - h / 2 if best["centered"] else best["gy"]
    return (x0, y0 + PAD, w, h)   # base 已经去掉标题条，这里不再补/减


def R_parse(level: str):
    scene = res_path(SCENES[level]["path"])
    return parse_tscn(scene)


def crop_mark(level: str, out_path: str) -> None:
    """三联特写：把新哨位的三件道具各放大，标上编号 / 坐标 / 用途。

    每件道具给独立的取景窗口（半宽 / 上 / 下，单位米），统一装进同尺寸面板，
    再用虚线框把道具本体的外框圈出来 —— 深色铁架贴在深色砖墙上，只靠准星点认不出来。
    """
    spec = CROPS[level]
    base = render(level, night=False, scale=1.0, actors=False)
    base = base.crop((0, BAND, base.width, base.height))        # 去掉标题条
    PW, PH = 520, 400
    cap, gap, head = 66, 10, 42
    W = PW * 3 + gap * 4
    H = head + PH + gap + cap
    sheet = Image.new("RGBA", (W, H), (14, 18, 19, 255))
    d = ImageDraw.Draw(sheet)
    ft = ImageFont.truetype(FONT_B, 17)
    fb = ImageFont.truetype(FONT_B, 15)
    fs = ImageFont.truetype(FONT, 12)
    d.text((14, 13), f"{spec['level']} · NEW OUTPOST PROPS", font=ft, fill=(216, 209, 191))

    for i, it in enumerate(spec["items"]):
        mx, my = it["m"]
        half_w, up, down = it["win"]
        ox_, oy_ = ZONE_CROP.get(level, (0.0, 0.0))
        cx, cy = (mx + ox_) * PPM, (my + oy_) * GY + PAD
        box = (int(cx - half_w * PPM), int(cy - up * GY),
               int(cx + half_w * PPM), int(cy + down * GY))
        img = base.crop(box)
        # 特写提亮一档：深色铁架贴在深色砖墙上，不提亮在验收图里几乎看不见
        img = ImageEnhance.Brightness(img).enhance(1.16)
        img = ImageEnhance.Contrast(img).enhance(1.07)
        k = min(PW / img.width, PH / img.height)
        img = img.resize((max(1, int(img.width * k)), max(1, int(img.height * k))), Image.LANCZOS)
        x = gap + i * (PW + gap)
        y = head
        pane = Image.new("RGBA", (PW, PH), (14, 18, 19, 255))
        ox, oy = (PW - img.width) // 2, (PH - img.height) // 2
        pane.alpha_composite(img.convert("RGBA"), (ox, oy))
        sheet.alpha_composite(pane, (x, y))
        d.rectangle([x, y, x + PW - 1, y + PH - 1], outline=(74, 84, 87, 255))

        # 道具外框（虚线）—— 只圈本体，不圈阴影
        r = sprite_rect(level, it["art"], (mx * PPM, my * GY))
        if r:
            rx, ry, rw, rh = r
            bx0 = x + ox + (rx - box[0]) * k
            by0 = y + oy + (ry - box[1]) * k
            dashed(d, (bx0 - 3, by0 - 3, bx0 + rw * k + 3, by0 + rh * k + 3),
                   (217, 163, 38, 235))

        # 准心：道具落地点
        ccx = x + ox + img.width / 2
        ccy = y + oy + (up * GY) * k
        rr = 18
        d.ellipse([ccx - rr, ccy - rr, ccx + rr, ccy + rr], outline=(200, 162, 87), width=3)
        d.line([ccx - rr - 10, ccy, ccx - rr - 2, ccy], fill=(200, 162, 87), width=1)
        d.line([ccx + rr + 2, ccy, ccx + rr + 10, ccy], fill=(200, 162, 87), width=1)

        d.rectangle([x, y + PH, x + PW - 1, y + PH + cap - 1], fill=(9, 11, 12, 255))
        d.text((x + 8, y + PH + 6), it["title"], font=fb, fill=(217, 163, 38))
        d.text((x + 8, y + PH + 26), f"({mx:.1f}, {my:.1f} m) · {it['note']}", font=fs,
               fill=(160, 154, 140))
        d.text((x + 8, y + PH + 44), f"zoom {k:.1f}x · art: res://art/30_props/{it['art']}",
               font=fs, fill=(110, 108, 100))
    sheet.convert("RGB").save(out_path)
    print("  ->", out_path, sheet.size)


def combat_diagram(out_path: str) -> None:
    """战斗读数示意：撬棍扇形 / 四支武器的噪声圈 / 命中半径 / 数值表。俯视，1m = 14px。"""
    K = 14.0
    W = H = 1344
    img = Image.new("RGB", (W, H), (12, 15, 16))
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = W // 2, 690
    f11 = ImageFont.truetype(FONT, 11)
    f12 = ImageFont.truetype(FONT, 12)
    f13 = ImageFont.truetype(FONT_B, 13)
    f16 = ImageFont.truetype(FONT_B, 16)

    # 网格：每 5m
    for g in range(-24, 25, 5):
        x = cx + g * K
        y = cy + g * K
        d.line([x, 34, x, H], fill=(31, 37, 40, 255))
        d.line([0, y, W, y], fill=(31, 37, 40, 255))
        if g != 0 and 34 < y < H - 12:
            d.text((6, y + 2), f"{g}", font=ImageFont.truetype(FONT, 9), fill=(70, 78, 82))

    rings = [
        ("CROWBAR 4.5 m", 4.5, (200, 162, 87), 2.30),
        ("TT-33 26 m", 26.0, (143, 180, 196), -1.05),
        ("SAWN-OFF 38 m", 38.0, (184, 98, 44), -0.62),
        ("MOSIN 44 m", 44.0, (184, 40, 28), -0.30),
    ]
    for (name, r, col, ang) in rings:
        rr = r * K
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=(*col, 200), width=2)
        tx = cx + math.cos(ang) * rr
        ty = cy + math.sin(ang) * rr
        tw = d.textlength(name, font=f13)
        d.rectangle([tx - tw / 2 - 6, ty - 11, tx + tw / 2 + 6, ty + 11], fill=(12, 15, 16, 220))
        d.text((tx - tw / 2, ty - 8), name, font=f13, fill=col)

    # 撬棍扇形（朝上）
    reach = 1.9 * K
    half = 0.85
    a0, a1 = -math.pi / 2 - half, -math.pi / 2 + half
    pts = [(cx, cy)]
    for i in range(21):
        a = a0 + (a1 - a0) * i / 20
        pts.append((cx + math.cos(a) * reach, cy + math.sin(a) * reach))
    d.polygon(pts, fill=(140, 28, 20, 150), outline=(220, 90, 70))
    label = "MELEE CONE 1.9 m · ±49° · 34 dmg"
    tw = d.textlength(label, font=f13)
    d.rectangle([cx - tw / 2 - 6, cy - reach - 34, cx + tw / 2 + 6, cy - reach - 10],
                fill=(12, 15, 16, 200))
    d.text((cx - tw / 2, cy - reach - 30), label, font=f13, fill=(230, 140, 120))

    # 玩家
    d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=(216, 209, 191))
    d.text((cx + 10, cy - 7), "YOU", font=f12, fill=(216, 209, 191))

    # ---- 面板 A：武器数值 ----
    px, py, pw, ph = 14, H - 252, 430, 212
    d.rectangle([px, py, px + pw, py + ph], fill=(9, 11, 12, 235), outline=(74, 84, 87, 255))
    d.text((px + 12, py + 10), "ARSENAL", font=f16, fill=(217, 163, 38))
    cols = ("dmg", "cd (s)", "range (m)", "noise (m)", "ammo")
    rows = [
        ("CROWBAR", "34", "1.45", "1.9", "4.5", "-"),
        ("TT-33", "42", "3.6", "16", "26", "8+16"),
        ("MOSIN", "96", "1.05", "28", "44", "5+10"),
        ("SAWN-OFF", "15x6", "1.15", "9.5", "38", "2+8"),
    ]
    x0 = px + 12
    xs = (x0, x0 + 100, x0 + 150, x0 + 214, x0 + 300, x0 + 372)
    for i, c in enumerate(cols):
        d.text((xs[i], py + 40), c, font=f11, fill=(140, 136, 124))
    for j, row in enumerate(rows):
        y = py + 60 + j * 26
        for i, cell in enumerate(row):
            d.text((xs[i], y), cell, font=f12,
                   fill=(217, 163, 38) if i == 0 else (196, 190, 176))
    d.text((px + 12, py + ph - 34), "kill: conscience -0.5  ·  mercy kill: tally +1, conscience -10",
           font=f11, fill=(146, 140, 124))
    d.text((px + 12, py + ph - 18), "bullets stop on layer 1 only; sandbags (layer 2) hide you, not them",
           font=f11, fill=(146, 140, 124))

    # ---- 面板 B：命中半径 ----
    px, py, pw, ph = W - 414, H - 252, 400, 212
    d.rectangle([px, py, px + pw, py + ph], fill=(9, 11, 12, 235), outline=(74, 84, 87, 255))
    d.text((px + 12, py + 10), "HIT RADIUS (5x)", font=f16, fill=(217, 163, 38))
    for i, (r, name, col) in enumerate(((0.52, "RABID", (184, 40, 28)),
                                       (0.46, "OSK / SOLDIER", (143, 180, 196)),
                                       (0.40, "HALF-TURNED", (217, 163, 38)))):
        ccx = px + 60 + i * 122
        ccy = py + 110
        rr = r * 5 * K
        d.ellipse([ccx - rr, ccy - rr, ccx + rr, ccy + rr], outline=(*col, 230), width=2)
        d.line([ccx - 4, ccy, ccx + 4, ccy], fill=(216, 209, 191), width=1)
        d.line([ccx, ccy - 4, ccx, ccy + 4], fill=(216, 209, 191), width=1)
        tw = d.textlength(name, font=f11)
        d.text((ccx - tw / 2, py + 150), name, font=f11, fill=col)
        tw = d.textlength(f"{r:.2f} m", font=f12)
        d.text((ccx - tw / 2, py + 166), f"{r:.2f} m", font=f12, fill=(196, 190, 176))
    d.text((px + 12, py + ph - 22), "chest offset +40 px up · cone ±49° · reach 1.9 m",
           font=f11, fill=(146, 140, 124))

    # 标题条 / 脚注
    d.rectangle([0, 0, W - 1, 34], fill=(9, 11, 12))
    d.text((14, 10), "COMBAT READOUT · NOISE RADII vs RANGE (top-down, 1 m = 14 px)",
           font=f16, fill=(216, 209, 191))
    d.text((W - 300, 11), "L03-L07M · NIGHT SCENES", font=f12, fill=(110, 108, 100))
    d.text((14, H - 16), "gunfire alerts every OSK inside 80% of the ring radius · "
                         "crowbar is quiet but must touch 1.9 m",
           font=f12, fill=(146, 140, 124))
    img.save(out_path)
    print("  ->", out_path, img.size)



# ---------------------------------------------------------------------------
# 三区与黑市（每个区一条色带 + 每张图的摊子）
# ---------------------------------------------------------------------------
ZONE_SPLIT = [
    "yard 0-12  ·  marshalling 0-9  ·  manor 0-10",
    "yard 12-21.5  ·  marshalling 9-20  ·  manor 10-22",
    "yard 21.5-40  ·  marshalling 20-36  ·  manor 22-38",
]

ZONE_CROP = {  # 取景偏移（米）：调车场的摊子紧挨着油桶火，往西挪一点避开火心
    "yard": (0.0, 0.0),
    "marshalling": (-2.0, -0.4),
    "manor": (0.0, 0.0),
}

ZONE_ROWS = [
    ("#9fc6e0", "A · WHITE  /  SAFE",   "no infected  ·  patrols never enter  ·  the only place you can stand still"),
    ("#c8483a", "B · RED  /  CURFEW",   "0-3 infected  ·  3.5 s warning, 7 s challenge  ·  residents forbidden"),
    ("#3aa0b4", "C · BLACK  /  SUNKEN", "7-8 infected  ·  +1 loot roll per container  ·  market & survivors"),
]


def zone_sheet(out_path: str) -> None:
    """三区验收图：三关各一格黑市特写（2×），下面一条三区色标。

    每格都能同时看到：地面本色带 / 区标签 / 摊位 + 摊主 + 幸存者。
    """
    import levels

    PW, PH = 520, 258
    gap, head, cap, leg = 10, 50, 58, 168
    W = PW * 3 + gap * 4
    H = head + PH + gap + cap + leg
    sheet = Image.new("RGBA", (W, H), (14, 18, 19, 255))
    d = ImageDraw.Draw(sheet)
    ft = ImageFont.truetype(FONT_B, 18)
    fb = ImageFont.truetype(FONT_B, 14)
    fs = ImageFont.truetype(FONT, 12)
    d.text((16, 14), "THREE ZONES  ·  WHITE / RED / BLACK  ·  BLACK MARKET", font=ft,
           fill=(216, 209, 191))
    d.text((16, 34), "each panel: ground band + zone stencil + stall, trader and survivors",
           font=fs, fill=(132, 128, 116))

    for i, lv in enumerate(("yard", "marshalling", "manor")):
        sp = levels.load(lv)
        mkt = sp.MARKET
        mx, my = mkt["pos"]
        base = render(lv, night=True, scale=1.0, actors=True)
        base = base.crop((0, BAND, base.width, base.height))
        ox_, oy_ = ZONE_CROP.get(lv, (0.0, 0.0))
        cx, cy = (mx + ox_) * PPM, (my + oy_) * GY + PAD
        box = (int(cx - 6.0 * PPM), int(cy - 6.0 * GY), int(cx + 6.0 * PPM), int(cy + 3.6 * GY))
        img = base.crop(box)
        img = ImageEnhance.Brightness(img).enhance(1.14)
        # 油桶火 + 摊子马灯两个补光叠在一起会把中间烧成白块：压一下高光肩部
        a = np.asarray(img).astype(np.float32) / 255.0
        hi = a > 0.72
        a[hi] = 0.72 + 0.23 * np.tanh((a[hi] - 0.72) / 0.23)
        img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
        k = min(PW / img.width, PH / img.height)
        img = img.resize((max(1, int(img.width * k)), max(1, int(img.height * k))), Image.LANCZOS)
        x = gap + i * (PW + gap)
        pane = Image.new("RGBA", (PW, PH), (10, 13, 14, 255))
        pane.alpha_composite(img.convert("RGBA"), ((PW - img.width) // 2, (PH - img.height) // 2))
        sheet.alpha_composite(pane, (x, head))
        d.rectangle([x, head, x + PW - 1, head + PH - 1], outline=(74, 84, 87, 255))
        # 摊位后的那圈暖光：在图上钉一个点，方便对位
        px_ = x + (PW / 2)
        d.line([px_ - 14, head + PH - 9, px_ + 14, head + PH - 9], fill=(217, 163, 38), width=2)
        d.text((x + 8, head + PH + 6), f"{SCENES[lv]['title']}  ·  BLACK MARKET", font=fb,
               fill=(216, 209, 191))
        n = 1 + len(mkt["survivors"])
        d.text((x + 8, head + PH + 24),
               f"({mx:.1f}, {my:.1f}) m  ·  {n} people  ·  {mkt['cans']} can -> {mkt['ammo']} rounds",
               font=fs, fill=(143, 180, 196))
        d.text((x + 8, head + PH + 39),
               "bands: " + "  /  ".join(
                   f"{z['id']} {z['rects'][0][1]:g}-{z['rects'][-1][3]:g}" for z in sp.ZONES),
               font=fs, fill=(132, 128, 116))

    # 三区色标
    y0 = head + PH + gap + cap
    d.line([16, y0 - 12, W - 16, y0 - 12], fill=(52, 60, 63), width=1)
    for j, (col, name, note) in enumerate(ZONE_ROWS):
        y = y0 + j * 52
        c = tuple(int(col[k:k + 2], 16) for k in (1, 3, 5))
        d.rectangle([18, y + 8, 58, y + 36], fill=c + (255,))
        d.rectangle([18, y + 8, 58, y + 36], outline=(120, 130, 132))
        d.text((70, y + 10), name, font=fb, fill=(216, 209, 191))
        d.text((70, y + 28), note, font=fs, fill=(150, 146, 136))
        d.text((W - 380, y + 18), ZONE_SPLIT[j], font=fs, fill=(132, 128, 116))
    d.text((W - 380, y0 + 3 * 52 - 4),
           "brazier flame top 91 px on a 54 px drum", font=fs, fill=(217, 163, 38))

    sheet.convert("RGB").save(out_path)
    print("  ->", out_path, sheet.size)


def main(argv):
    os.makedirs(OUT, exist_ok=True)
    only = None
    for i, a in enumerate(argv):
        if a == "--level" and i + 1 < len(argv):
            only = argv[i + 1]
    levels = [only] if only else list(SCENES)
    for lv in levels:
        for night in (False, True):
            img = render(lv, night=night)
            suffix = "night" if night else "grey"
            p = os.path.join(OUT, f"{lv}_{suffix}.png")
            img.save(p)
            print("  ->", p, img.size)
    if only is None or only in CROPS:
        for lv in ([only] if only else list(CROPS)):
            crop_mark(lv, os.path.join(OUT, f"outpost_{lv}.png"))
    if only is None:
        combat_diagram(os.path.join(OUT, "combat_readout.png"))
        zone_sheet(os.path.join(OUT, "zones_market.png"))


if __name__ == "__main__":
    main(sys.argv[1:])
