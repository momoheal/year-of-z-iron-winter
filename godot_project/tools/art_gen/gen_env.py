"""环境大图：地面烘焙（TIL_01~03 合成）、北侧立面（TIL_04）、立面窗光灯光贴图。

多关卡（P4.1）：所有尺寸 / 配方都从当前关卡（layout.LY）里取，不在本文件里写死。
    地面   bake_ground()          ← LY.PATHS/TRACKS/SLUSH/TAR_STAINS/ASPHALT/GRAVEL/PROPS…
    立面   bake_facade()          ← LY.META["facade"] 决定画哪一种墙：
                                     "khrushchyovka" 赫鲁晓夫楼（yard）
                                     "depot"         机车库砖墙 + 调度塔（marshalling）
两种立面都返回 (精灵, 窗光灯光贴图)，窗光贴图共用 _facade_glow()。
"""
from __future__ import annotations

import math
import numpy as np
from PIL import Image, ImageDraw

from artlib import (GY, PPM, Layer, blur, blur_rgb, fbm, hexc, lerp, norm01, smooth, to_img,
                    vnoise)
import layout as LY

FACADE_H = 600                     # 立面精灵高度的默认值（关卡可用 LY.FACADE_H 覆盖）
GLOW_SPILL = 170                   # 窗光贴图在墙脚以下额外延伸的像素（照到雪地上）


def _gw() -> int:
    """当前关卡的地面像素宽。"""
    return int(LY.W * PPM)


def _gh() -> int:
    """当前关卡的地面像素高（y 压缩 0.62）。"""
    return int(round(LY.H * GY))


def facade_h() -> int:
    return int(getattr(LY, "FACADE_H", FACADE_H))


def facade_kind() -> str:
    return LY.META.get("facade", "khrushchyovka")


def facade_keys() -> tuple[str, str]:
    """(立面精灵 manifest key, 窗光贴图 manifest key) —— yard 的那两个名字不许改。"""
    return {
        "khrushchyovka": ("TIL_Facade_Khrushchyovka_A", "VFX_Facade_WindowGlow"),
        "depot": ("TIL_Facade_Depot_A", "VFX_Facade_WindowGlow_Depot"),
        "manor": ("TIL_Facade_Manor_A", "VFX_Facade_WindowGlow_Manor"),
    }[facade_kind()]


def ground_key() -> str:
    """地面大图的 manifest key：TIL_Ground_Night<Level>_Baked（yard = NightYard，历史名）。"""
    return "TIL_Ground_Night%s_Baked" % LY.META["id"].capitalize()


def _mix(col, m, c):
    m = np.clip(m, 0, 1)[..., None]
    return col * (1 - m) + np.asarray(c, np.float32) * m


def _px(x, y):
    return x * PPM, y * GY


def _line_mask(w, h, polylines, width, blur_r):
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    for pl in polylines:
        pts = [_px(x, y) for x, y in pl]
        d.line(pts, fill=255, width=int(width), joint="curve")
        for p in pts:
            d.ellipse([p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2], fill=255)
    return blur(np.asarray(im, np.float32) / 255.0, blur_r)


# ===========================================================================
# 地面
# ===========================================================================
def bake_ground() -> Image.Image:
    w, h = _gw(), _gh()
    xs = (np.arange(w, dtype=np.float32) + 0.5) / PPM
    ys = (np.arange(h, dtype=np.float32) + 0.5) / GY
    X, Y = np.meshgrid(xs, ys)
    Ypx = np.arange(h, dtype=np.float32)[:, None] + np.zeros((1, w), np.float32)
    fence_y = LY.has("FENCE_Y", None)   # None = 本关没有铁丝网

    nb = norm01(fbm(h, w, 4.2 * PPM, 4.2 * GY, 4, 11))
    nm = norm01(fbm(h, w, 1.1 * PPM, 1.1 * GY, 4, 12))
    nf = vnoise(h, w, 2.0, 1.4, 13)
    rip = norm01(fbm(h, w, 30, 3.2, 2, 14))

    # ---- 雪底 ----
    col = lerp(hexc("#95a4b6"), hexc("#d8e1ea"), smooth(0.05, 0.95, nb * 0.55 + nm * 0.45))
    col = col * (0.965 + 0.07 * rip)[..., None]
    col = col * (0.985 + 0.03 * nf)[..., None]

    # ---- 雪径（踩实的灰雪 + 脚印）----
    pathm = _line_mask(w, h, LY.PATHS, 64, 16)
    pathm = smooth(0.25, 0.75, pathm * (0.65 + 0.7 * nm))
    # 「院子」= 立面墙脚到铁丝网之间那一段：这里雪下面露出混凝土预制板。
    # 关卡可以用 SLAB_BAND=(y0, y1) 覆盖（没有铁丝网时默认一直到地图南边）。
    y0, y1 = LY.has("SLAB_BAND", (LY.FACADE_BASE_Y, (fence_y if fence_y is not None else LY.H) - 0.15))
    slab = ((Y > y0) & (Y < y1)).astype(np.float32)

    # ---- 院子：混凝土预制板从雪下露出来 ----
    expose = smooth(0.66, 0.82, nm * 0.72 + nb * 0.28 + pathm * 0.18) * slab * 0.8
    conc = hexc("#7f858e")[None, None, :] * (0.88 + 0.2 * nf)[..., None]
    conc = conc * (0.94 + 0.12 * vnoise(h, w, 22, 14, 15))[..., None]
    row = np.floor(Y / 1.5)
    sx = X + (row % 2) * 1.0
    seam = ((sx % 2.0) < 0.045) | ((Y % 1.5) < 0.05)
    conc = conc * np.where(seam, 0.6, 1.0)[..., None]
    # 发丝裂缝
    crack = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(crack)
    r = np.random.default_rng(16)
    for _ in range(260):
        x, y = r.uniform(0, w), r.uniform(LY.FACADE_BASE_Y * GY, LY.FENCE_Y * GY)
        ang = r.uniform(0, math.tau)
        pts = [(x, y)]
        for _k in range(r.integers(4, 10)):
            ang += r.normal(0, 0.6)
            x += math.cos(ang) * r.uniform(4, 12)
            y += math.sin(ang) * r.uniform(2, 7)
            pts.append((x, y))
        d.line(pts, fill=255, width=1)
    crk = np.asarray(crack, np.float32) / 255.0
    conc = conc * (1 - 0.45 * crk)[..., None]
    col = _mix(col, expose, conc)
    col = _mix(col, pathm * 0.72 * slab, hexc("#87909b") * 1.0)
    col = _mix(col, pathm * 0.62 * (1 - slab), hexc("#8b939d"))

    # ---- 沥青便道（可选层：检修通道，雪被扫到两边）----
    for i, road in enumerate(LY.has("ASPHALT", [])):
        rm = smooth(0.35, 0.7, _line_mask(w, h, [road["pts"]], road["w"] * PPM, 6))
        asp = hexc("#2e3339")[None, None, :] * (0.9 + 0.2 * nf)[..., None]
        fiss = smooth(0.6, 0.86, vnoise(h, w, 2.2, 1.5, 120 + i))
        asp = asp * (1 - 0.4 * fiss)[..., None]
        col = _mix(col, rm, asp)
        # 路面上没扫干净的残雪（中间薄、两边厚）+ 融雪剂的黑浆 + 车辙
        drift_edge = smooth(0.34, 0.52, rm) * (1 - smooth(0.52, 0.72, rm))
        col = _mix(col, rm * smooth(0.56, 0.8, nm * 0.75 + nb * 0.25) * 0.34, hexc("#c8d3de"))
        col = _mix(col, drift_edge * 0.42, hexc("#dde6ee"))
        col = _mix(col, rm * smooth(0.72, 0.92, vnoise(h, w, 9, 4, 124 + i)) * 0.35, hexc("#22262b"))
        for k in (-0.62, 0.62):
            ty = np.mean([p[1] for p in road["pts"]]) + k * road["w"] * 0.28
            rut = smooth(0.1, 0.0, np.abs(Y - ty)) * rm
            col = col * (1 - 0.22 * rut)[..., None]

    # ---- 道砟 / 煤渣堆（可选层：驼峰肩、备用枕木堆）----
    sn = vnoise(h, w, 2.4, 1.7, 21)
    sn2 = vnoise(h, w, 1.2, 0.9, 22)
    stones = hexc("#5a5e65")[None, None, :] * (0.62 + 0.55 * sn + 0.25 * (sn2 - 0.5))[..., None]
    for i, (cx, cy, rx, ry) in enumerate(LY.has("GRAVEL", [])):
        dd = ((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2 + (nm - 0.5) * 0.7
        gm = smooth(1.05, 0.8, dd)
        patch = smooth(0.5, 0.76, nm * 0.8 + nb * 0.2 + vnoise(h, w, 5, 3, 130 + i) * 0.25)
        col = _mix(col, gm * (1 - patch * 0.8), stones)
        col = _mix(col, gm * smooth(1.25, 1.0, dd) * (1 - smooth(1.0, 0.8, dd)) * 0.3,
                   hexc("#4a4e54"))

    # ---- 货场：道砟、枕木、钢轨 ----（stones 已在上面算好，沥青 / 道砟堆也用同一批石子）
    bw0, bw1 = LY.has("BALLAST_W", (2.25, 1.75))
    for ti, c in enumerate(LY.TRACKS):
        bal = smooth(bw0, bw1, np.abs(Y - c) + (nm - 0.5) * 0.7)
        snow_on = smooth(0.52, 0.74, nm * 0.8 + nb * 0.2)
        col = _mix(col, bal * (1 - snow_on * 0.85), stones)
        # 枕木（每 0.72m 一根，沿 y 方向长 2.7m）
        idx = np.floor(X / 0.72)
        fx = X - idx * 0.72
        jit = (np.sin(idx * 12.9898 + ti * 78.233) * 43758.5453) % 1.0
        half = 1.35 + (jit - 0.5) * 0.12
        sm = ((fx > 0.22) & (fx < 0.47) & (np.abs(Y - c) < half)).astype(np.float32)
        grain = vnoise(h, w, 1.3, 9, 23 + ti)
        wood = hexc("#4c3e32")[None, None, :] * (0.72 + 0.32 * grain + 0.25 * (jit - 0.5))[..., None]
        wood = wood * np.where(np.abs(Y - c) > half - 0.12, 0.8, 1.0)[..., None]
        sl_snow = smooth(0.48, 0.66, nm + (jit - 0.5) * 0.35)
        col = _mix(col, sm * (1 - sl_snow * 0.78), wood)
        # 钢轨：顶面亮线 + 侧面 + 投影
        for rr in (c - 0.76, c + 0.76):
            yr = rr * GY
            top = ((Ypx >= yr - 3) & (Ypx < yr)).astype(np.float32)
            side = ((Ypx >= yr) & (Ypx < yr + 7)).astype(np.float32)
            shad = ((Ypx >= yr + 7) & (Ypx < yr + 12)).astype(np.float32)
            plate = (sm > 0) & (np.abs(Ypx - yr - 3) < 6)
            col = col * (1 - 0.5 * shad * smooth(yr + 12, yr + 7, Ypx))[..., None]
            col = _mix(col, plate.astype(np.float32) * 0.9, hexc("#2e3136"))
            steel_t = hexc("#a9b3bd")[None, None, :] * (0.86 + 0.3 * vnoise(h, w, 40, 2, 31))[..., None]
            col = _mix(col, top, steel_t)
            col = _mix(col, side, hexc("#3c4249")[None, None, :] * (0.9 + 0.2 * nf)[..., None])
            # 轨顶霜点
            frost = (vnoise(h, w, 6, 2, 37 + int(rr)) > 0.72).astype(np.float32) * top
            col = _mix(col, frost * 0.6, hexc("#e6eef5"))

    # ---- 冻雪泥 / 黑冰 ----
    streak = vnoise(h, w, 46, 3.5, 41)
    for i, (cx, cy, rx, ry) in enumerate(LY.SLUSH):
        dd = ((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2 + (nm - 0.5) * 0.9
        m = smooth(1.05, 0.85, dd)
        ring = smooth(1.2, 1.0, dd) * (1 - m)
        ice = hexc("#3b434c")[None, None, :] * (0.85 + 0.3 * nf)[..., None]
        col = col * (1 - 0.32 * ring)[..., None]
        col = _mix(col, m, ice)
        glint = smooth(0.62, 0.8, streak) * m
        col = _mix(col, glint * 0.4, hexc("#a6c0d3"))
        # 冻住的车辙
        for k in (-0.35, 0.35):
            rut = smooth(0.11, 0.0, np.abs(Y - (cy + k * ry))) * m
            col = col * (1 - 0.4 * rut)[..., None]
        # 冰面的气泡与碎冰
        sh = (vnoise(h, w, 3, 2, 50 + i) > 0.86).astype(np.float32) * m
        col = _mix(col, sh * 0.22, hexc("#d5e3ee"))

    # ---- 融雪带（暖管底下）----
    # MELT_BANDS = [(x0, x1, y), …]；关卡没写就沿用老逻辑：场景里有 SteamPipe 就在管下烘一条。
    bands = LY.has("MELT_BANDS", None)
    if bands is None:
        pipe = next((q for q in LY.PROPS if q["id"] == "SteamPipe"), None)
        bands = [] if pipe is None else [(pipe["pos"][0] - pipe["fp"][0] / 2,
                                          pipe["pos"][0] + pipe["fp"][0] / 2, pipe["pos"][1])]
    for (px0, px1, py) in bands:
        melt = smooth(0.9, 0.3, np.abs(Y - (py - 0.25)) + (nm - 0.5) * 0.5) * \
            smooth(px0 - 0.4, px0 + 0.6, X) * smooth(px1 + 0.4, px1 - 0.6, X)
        col = _mix(col, melt * 0.75, hexc("#58606a")[None, None, :] * (0.85 + 0.3 * nf)[..., None])
        col = _mix(col, smooth(0.66, 0.82, streak) * melt * 0.5, hexc("#9fb6c8"))

    # ---- 焦油黑雪 ----
    for i, (cx, cy, rr) in enumerate(LY.TAR_STAINS):
        dd = np.sqrt(((X - cx) / rr) ** 2 + ((Y - cy) / (rr * 0.8)) ** 2) + (nm - 0.5) * 0.8
        m = smooth(1.0, 0.6, dd)
        speck = (vnoise(h, w, 2, 1.5, 60 + i) > 0.55).astype(np.float32)
        col = _mix(col, m * (0.55 + 0.4 * speck), hexc("#1d2127"))
        col = _mix(col, smooth(1.5, 1.0, dd) * (1 - m) * speck * 0.5, hexc("#3a3f46"))

    # ---- 墙脚雪堆 / 铁丝网下的积雪 ----
    n1 = vnoise(1, w, 70, 1, 71)[0]
    drift_top = LY.FACADE_BASE_Y
    drift_bot = LY.FACADE_BASE_Y + 0.55 + 0.6 * n1
    dm = smooth(drift_bot[None, :], drift_bot[None, :] - 0.25, Y) * (Y >= drift_top)
    col = _mix(col, dm, lerp(hexc("#c4d0dc"), hexc("#eef3f8"), smooth(drift_top, drift_top + 0.6, Y)))
    if fence_y is not None:
        n2 = vnoise(1, w, 50, 1, 72)[0]
        fd = smooth(0.45 + 0.35 * n2[None, :], 0.2, np.abs(Y - fence_y - 0.08))
        col = _mix(col, fd * 0.85, hexc("#e3eaf1"))

    # ---- 接触阴影（统一右下偏 15°） ----
    ao = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(ao)
    _AO_LEGACY = {"LampWest": "post", "LampEast": "post", "SignalPost": "post",
                  "Playground": "dome", "SteamPipe": "pipe"}
    for p in LY.PROPS:
        x, y = p["pos"]
        fw, fd_ = p["fp"]
        ox, oy = 0.28, 0.22
        kind = p.get("ao") or _AO_LEGACY.get(p["id"], "box")
        if kind == "post":        # 灯杆 / 信号机：一小摊
            d.ellipse([_px(x - 0.3 + ox, y - 0.2 + oy), _px(x + 0.5 + ox, y + 0.25 + oy)], fill=200)
            continue
        if kind == "dome":        # 圆顶游乐设施
            d.ellipse([_px(x - fw / 2 + ox, y - fd_ + oy), _px(x + fw / 2 + ox, y + 0.2 + oy)], fill=110)
            continue
        if kind == "pipe":        # 长条暖管
            d.rectangle([_px(x - fw / 2 + 0.1, y - 0.2), _px(x + fw / 2 + 0.3, y + 0.5)], fill=140)
            continue
        d.rounded_rectangle([_px(x - fw / 2 + ox * 0.5, y - fd_ + oy * 0.4),
                             _px(x + fw / 2 + ox, y + oy)], radius=8, fill=210)
    aom = blur(np.asarray(ao, np.float32) / 255.0, 9)
    col = col * (1 - 0.42 * aom)[..., None]
    wall = smooth(LY.FACADE_BASE_Y + 1.1, LY.FACADE_BASE_Y, Y)
    col = col * (1 - 0.38 * wall)[..., None]
    if fence_y is not None:
        gap = LY.FENCE_GAP
        fence_sh = smooth(0.28, 0.0, np.abs(Y - (fence_y + 0.12))) * ~((X > gap[0]) & (X < gap[1]))
        col = col * (1 - 0.18 * fence_sh)[..., None]

    # ---- 脚印 ----
    fp = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(fp)
    r = np.random.default_rng(81)
    for pl in LY.PATHS:
        for (ax, ay), (bx, by) in zip(pl[:-1], pl[1:]):
            seg = math.hypot(bx - ax, by - ay)
            n = int(seg / 0.62)
            ux, uy = (bx - ax) / max(seg, 1e-6), (by - ay) / max(seg, 1e-6)
            for k in range(n):
                t = k / max(1, n)
                side = 0.16 if k % 2 == 0 else -0.16
                cx = ax + (bx - ax) * t - uy * side + r.normal(0, 0.03)
                cy = ay + (by - ay) * t + ux * side + r.normal(0, 0.03)
                qx, qy = _px(cx, cy)
                d.ellipse([qx - 4, qy - 3, qx + 4, qy + 3], fill=255)
    fpm = blur(np.asarray(fp, np.float32) / 255.0, 0.8)
    col = col * (1 - 0.2 * fpm)[..., None]
    col = _mix(col, fpm * 0.12, hexc("#5f7590"))

    # ---- 雪面闪点 + 颗粒 ----
    spark = (np.random.default_rng(91).random((h, w)) > 0.9965).astype(np.float32)
    col = col + (spark * 0.14 * (1 - expose))[..., None]
    col = col * (0.985 + 0.03 * np.random.default_rng(92).random((h, w)))[..., None]
    # 楼体脚下（被立面盖住的部分）直接压黑
    col = col * np.where(Y < LY.FACADE_BASE_Y - 0.05, 0.25, 1.0)[..., None]
    return to_img(col)


# ===========================================================================
# 赫鲁晓夫楼立面
# ===========================================================================
PANEL_W, FLOOR_H = 192, 140
FLOORS_Y = [0, 140, 280, 420]          # 4F, 3F, 2F, 1F 的顶边
PLINTH_Y = 560


def _paste(dst: Image.Image, src: Image.Image, x: int, y: int) -> None:
    dst.alpha_composite(src, (int(x), int(y)))


def _panel(floor: int, lit: bool, seed: int, ground: bool, boarded: bool = False) -> Image.Image:
    L = Layer(PANEL_W, FLOOR_H, ss=2)
    r = np.random.default_rng(seed)
    full = L.rect(0, 0, PANEL_W, FLOOR_H)
    shift = r.uniform(-0.05, 0.05)
    base = L.tex("#8b8d8c", 0.07, 7, seed) * np.array([1 + shift, 1 + shift * 0.7, 1 + shift * 0.2])
    L.paint(full, base)
    L.grime(full, seed + 1, 0.12, 11)
    # 窗下的污水痕
    stain = L.rect(58, 112, 134, FLOOR_H) * L.gy(112, FLOOR_H, 1.0, 0.2)
    L.shade(stain * smooth(0.4, 0.9, L.noise(1.4, seed + 2, 9)), 0.78)
    L.rust_streaks(L.rect(0, 0, PANEL_W, FLOOR_H), seed + 3, 0.25)
    # 板缝
    L.paint(L.rect(PANEL_W - 3, 0, PANEL_W, FLOOR_H), hexc("#3d4145"))
    L.paint(L.rect(PANEL_W - 4, 0, PANEL_W - 3, FLOOR_H), hexc("#a5a8a7"), 0.6)
    L.paint(L.rect(0, FLOOR_H - 3, PANEL_W, FLOOR_H), hexc("#3d4145"))
    L.paint(L.rect(0, FLOOR_H - 4, PANEL_W, FLOOR_H - 3), hexc("#a5a8a7"), 0.5)
    # 窗洞（内凹阴影）
    wx0, wy0, wx1, wy1 = 60, 26, 132, 112
    L.paint(L.rect(wx0 - 3, wy0 - 3, wx1 + 3, wy1), hexc("#2a2e33"))
    L.paint(L.rect(wx0, wy0, wx1, wy1), L.tex("#5b4a39", 0.1, 3, seed + 4))
    panes = [(66, 32, 94, 52), (66, 56, 94, 106), (99, 32, 127, 106)]
    for k, (a0, b0, a1, b1) in enumerate(panes):
        g = L.rect(a0, b0, a1, b1)
        if boarded:
            L.paint(g, L.tex("#4a3c2c", 0.15, 2, seed + 10 + k, cy=12))
            for yy in range(b0 + 3, b1, 9):
                L.paint(L.rect(a0, yy, a1, yy + 1), hexc("#2a2118"))
            continue
        if lit:
            glass = lerp(hexc("#c27a35"), hexc("#f2c07a"), L.gy(b0, b1, 0.0, 1.0))
            L.paint(g, glass)
            # 窗帘
            cur = L.rect(a0, b0, a0 + 8, b1) + L.rect(a1 - 7, b0, a1, b1)
            folds = 0.75 + 0.25 * np.sin(L.X * 1.7)
            L.paint(np.clip(cur, 0, 1), hexc("#8e5428") * folds[..., None], 0.85)
            if k == 2 and r.random() < 0.35:
                L.paint(L.ellipse(113, 58, 6, 7), hexc("#6b3a1a"), 0.8)
                L.paint(L.rect(104, 64, 122, b1, 4), hexc("#6b3a1a"), 0.8)
        else:
            glass = lerp(hexc("#24303d"), hexc("#11171f"), L.gy(b0, b1, 0.0, 1.0))
            L.paint(g, glass)
            refl = np.clip(1 - np.abs((L.X - a0) - (L.Y - b0) * 0.5 - 6) / 4, 0, 1) * g
            L.paint(refl, hexc("#4a5d70"), 0.35)
        # 窗底的霜花
        frost = g * smooth(b1 - 14, b1, L.Y) * smooth(0.35, 0.75, L.noise(1.6, seed + 20 + k))
        L.paint(frost, hexc("#dbe7f0"), 0.8)
    # 窗台 + 积雪
    L.paint(L.rect(54, 112, 138, 118), L.tex("#9a9c9b", 0.06, 3, seed + 5))
    L.paint(L.rect(54, 117, 138, 119), hexc("#4a4e52"))
    L.snow_cap(53, 139, 113, 7, seed + 6, droop=0.3)
    if ground:
        # 一楼的焊接防盗栅
        for xx in range(63, 131, 9):
            L.paint(L.rect(xx, wy0 + 2, xx + 2, wy1 - 1), hexc("#2c3035"))
        for yy in (wy0 + 8, 70, wy1 - 8):
            L.paint(L.rect(wx0 + 1, yy, wx1 - 1, yy + 2), hexc("#2c3035"))
        L.rust_streaks(L.rect(wx0, wy0, wx1, wy1), seed + 7, 0.35)
    return L.finish(outline=None)


def _balcony(seed: int) -> Image.Image:
    w, h = 184, 104
    L = Layer(w, h, ss=2)
    r = np.random.default_rng(seed)
    # 阳台上堆的杂物（从栏板上方露头）
    for _ in range(r.integers(1, 4)):
        bx = r.uniform(12, w - 40)
        bw, bh = r.uniform(16, 34), r.uniform(8, 18)
        L.paint(L.rect(bx, 14 - bh, bx + bw, 16), L.tex(r.choice(["#5b4a36", "#4a5058", "#6a5a44"]), 0.1, 3, seed))
    if r.random() < 0.5:
        L.paint(L.line([(w - 30, -2), (w - 24, 16)], 3), hexc("#6b5a3a"))
        L.paint(L.line([(w - 22, 0), (w - 17, 16)], 3), hexc("#6b5a3a"))
    # 栏板（波纹石棉板）
    pan = L.rect(2, 12, w - 2, 76)
    L.paint(pan, L.tex(r.choice(["#7b8883", "#8a857a", "#79848c"]), 0.06, 6, seed + 1))
    ribs = 0.9 + 0.1 * np.sin(L.X * 0.9)
    L.shade(pan, ribs)
    L.grime(pan, seed + 2, 0.18, 6)
    L.rust_streaks(pan, seed + 3, 0.35)
    L.paint(L.rect(0, 9, w, 13), hexc("#4a4f55"))
    L.snow_cap(0, w, 10, 9, seed + 4, droop=0.35)
    # 楼板前沿
    L.paint(L.rect(0, 76, w, 88), L.tex("#8c8e8d", 0.06, 4, seed + 5))
    L.shade(L.rect(0, 76, w, 88), L.gy(76, 88, 1.05, 0.75))
    L.paint(L.rect(0, 88, w, 90), hexc("#3a3e42"))
    L.icicles(4, w - 4, 89, 14, 14, seed + 6)
    return L.finish(outline="#1a1e23", outline_a=0.6)


def _door_porch() -> Image.Image:
    w, h = 260, 210
    L = Layer(w, h, ss=2)
    cx = w / 2
    # 入口凹进的墙面
    L.paint(L.rect(cx - 96, 40, cx + 96, h), L.tex("#6f7272", 0.08, 6, 301))
    L.grime(L.rect(cx - 96, 40, cx + 96, h), 302, 0.25)
    # 门框 + 铁门
    L.paint(L.rect(cx - 58, 64, cx + 58, h), hexc("#2b2f33"))
    door = L.rect(cx - 52, 70, cx + 52, h)
    L.paint(door, L.tex("#3e4b40", 0.09, 4, 303))
    L.rust_streaks(door, 304, 0.5)
    L.paint(L.rect(cx - 1, 70, cx + 1, h), hexc("#1d2420"))
    for yy in (96, 150):
        L.paint(L.rect(cx - 46, yy, cx + 46, yy + 3), hexc("#2a332c"))
    # 焊死的钢条：X + 三道横条，焊点发亮
    bars = [((cx - 56, 72), (cx + 56, h - 4)), ((cx + 56, 72), (cx - 56, h - 4))]
    for a, b in bars:
        L.paint(L.line([a, b], 6), hexc("#3a3f45"))
        L.paint(L.line([(a[0], a[1] - 1), (b[0], b[1] - 1)], 2), hexc("#7a818a"), 0.8)
    for yy in (84, 128, 176):
        L.paint(L.rect(cx - 62, yy, cx + 62, yy + 6), hexc("#3a3f45"))
        L.paint(L.rect(cx - 62, yy, cx + 62, yy + 2), hexc("#7a818a"), 0.8)
        for xx in (cx - 60, cx + 54):
            L.paint(L.ellipse(xx + 3, yy + 3, 5, 4), hexc("#c7cdd2"))
            L.paint(L.ellipse(xx + 3, yy + 3, 8, 6), hexc("#d08040"), 0.25)
    L.rust_streaks(L.rect(cx - 62, 72, cx + 62, h), 305, 0.4)
    # 雨棚
    L.paint(L.rect(cx - 124, 40, cx + 124, 58), L.tex("#8f9190", 0.06, 4, 306))
    L.shade(L.rect(cx - 124, 40, cx + 124, 58), L.gy(40, 58, 1.08, 0.72))
    L.paint(L.rect(cx - 124, 58, cx + 124, 61), hexc("#30343a"))
    L.snow_cap(cx - 126, cx + 126, 42, 26, 307, droop=0.4)
    L.icicles(cx - 120, cx + 120, 60, 22, 22, 308)
    # 门灯（铁丝罩）
    L.paint(L.rect(cx - 3, 61, cx + 3, 66), hexc("#2a2e33"))
    L.paint(L.ellipse(cx, 70, 6, 6), hexc("#f2c27a"))
    L.paint(L.ellipse(cx, 70, 3, 3), hexc("#fff1cf"))
    L.paint(L.arc(cx, 70, 7, 7, 0, 360, 1.2), hexc("#2a2e33"))
    # 门口积雪
    L.snow_cap(cx - 100, cx + 100, h - 4, 16, 309, droop=0.0)
    return L.finish(outline=None)


def _terminal() -> Image.Image:
    w, h = 78, 108
    L = Layer(w, h, ss=3)
    body = L.rect(6, 12, w - 6, 92, 3)
    L.paint(body, L.tex("#5d636b", 0.07, 4, 401))
    L.shade(body, L.gx(6, w - 6, 1.1, 0.8))
    L.rust_streaks(body, 402, 0.45)
    for (x, y) in [(10, 16), (w - 12, 16), (10, 86), (w - 12, 86)]:
        L.paint(L.ellipse(x, y, 1.6, 1.6), hexc("#9aa1a8"))
    # CRT
    L.paint(L.rect(14, 22, w - 14, 56, 4), hexc("#1a1f1c"))
    scr = L.rect(18, 26, w - 18, 52, 3)
    L.paint(scr, lerp(hexc("#58f08f"), hexc("#1f8a4c"), L.gy(26, 52, 0, 1)))
    for yy in range(28, 52, 4):
        L.paint(L.rect(20, yy, 20 + (yy * 7) % 26 + 10, yy + 1.4), hexc("#c9ffd9"), 0.75)
    L.shade(scr, 0.9 + 0.1 * np.sin(L.Y * 3.0))
    # 红色真空管故障灯
    L.paint(L.ellipse(w - 16, 64, 3, 3), hexc("#ef4444"))
    L.paint(L.ellipse(w - 16.6, 63.3, 1.2, 1.2), hexc("#ffd0d0"))
    # 纸带出口 + 键盘
    L.paint(L.rect(14, 62, 40, 65), hexc("#15181b"))
    L.paint(L.rect(18, 64, 36, 74), hexc("#d6d0bf"), 0.9)
    kb = L.poly([(10, 78), (w - 10, 78), (w - 4, 94), (4, 94)])
    L.paint(kb, L.tex("#4a4f55", 0.06, 3, 403))
    for row in range(3):
        for k in range(8):
            x = 9 + k * 7.5 + row * 1.5
            y = 80 + row * 4.6
            L.paint(L.rect(x, y, x + 5, y + 3.2), hexc("#2a2d31"))
            L.paint(L.rect(x, y, x + 5, y + 1), hexc("#8d9399"), 0.7)
    L.snow_cap(4, w - 4, 13, 10, 404)
    L.icicles(8, w - 8, 93, 10, 7, 405, 1.6)
    # 线缆
    L.paint(L.line([(w / 2, 94), (w / 2 + 3, h)], 3), hexc("#1d2024"))
    return L.finish()


def _notice_board() -> Image.Image:
    w, h = 160, 120
    L = Layer(w, h, ss=2)
    r = np.random.default_rng(501)
    L.paint(L.rect(4, 10, w - 4, 96), L.tex("#4b3b2b", 0.12, 3, 502, cy=10))
    L.paint(L.rect(10, 16, w - 10, 90), L.tex("#3a2e22", 0.1, 4, 503))
    papers = [(16, 22, 52, 70), (56, 20, 92, 64), (96, 24, 136, 76), (30, 60, 70, 88), (84, 58, 124, 88)]
    for i, (a0, b0, a1, b1) in enumerate(papers):
        rot = r.uniform(-2, 2)
        pg = L.poly([(a0, b0 + rot), (a1, b0 - rot), (a1, b1 - rot * 0.5), (a0, b1 + rot * 0.5)])
        L.paint(pg, L.tex("#d8d2c1", 0.06, 3, 510 + i))
        L.paint(L.rect(a0 + 2, b0 + 2, a1 - 2, b0 + 7) * pg, hexc("#a2483e"))
        for yy in np.arange(b0 + 11, b1 - 4, 4.2):
            ln = r.uniform(0.5, 1.0) * (a1 - a0 - 8)
            L.paint(L.rect(a0 + 4, yy, a0 + 4 + ln, yy + 1.2) * pg, hexc("#6b6a66"), 0.8)
        if i == 2:
            L.paint(L.arc(a1 - 13, b1 - 14, 8, 8, 0, 360, 2.2), hexc("#5b4aa8"), 0.85)
        if i == 4:
            L.paint(L.poly([(a1 - 10, b1), (a1, b1 - 14), (a1, b1)]), hexc("#3a2e22"))
        L.paint(L.ellipse(a0 + (a1 - a0) / 2, b0 + 2, 1.6, 1.6), hexc("#9aa1a8"))
    L.paint(L.rect(18, 96, 22, h), hexc("#3a2e22"))
    L.paint(L.rect(w - 22, 96, w - 18, h), hexc("#3a2e22"))
    L.snow_cap(2, w - 2, 11, 9, 520)
    L.icicles(6, w - 6, 96, 9, 10, 521, 1.6)
    return L.finish()


def _vent() -> Image.Image:
    w, h = 132, 96
    L = Layer(w, h, ss=3)
    L.paint(L.rect(4, 18, w - 4, h), L.tex("#686b6c", 0.08, 5, 601))
    hole = L.rect(16, 30, w - 16, h - 8, 3)
    L.paint(hole, lerp(hexc("#1a1210"), hexc("#d2702c"), L.gy(30, h - 8, 0.0, 1.0) ** 1.8))
    L.paint(L.ellipse(w / 2, h - 10, 30, 10) * hole, hexc("#f5a24a"), 0.6)
    # 栅栏，中间两根被撬棍别弯
    for k, xx in enumerate(range(22, w - 18, 11)):
        if k in (4, 5):
            bend = -9 if k == 4 else 9
            pts = [(xx, 30), (xx + bend * 0.4, 52), (xx + bend, h - 10)]
        else:
            pts = [(xx, 30), (xx, h - 8)]
        L.paint(L.line(pts, 3.4), hexc("#2d3136"))
        L.paint(L.line([(p[0] - 1, p[1]) for p in pts], 1.1), hexc("#7b828a"), 0.7)
    L.paint(L.rect(16, 28, w - 16, 33), hexc("#2d3136"))
    L.rust_streaks(L.rect(4, 18, w - 4, h), 602, 0.5)
    L.snow_cap(2, w - 2, 20, 12, 603)
    L.icicles(16, w - 16, 33, 9, 8, 604, 1.4)
    return L.finish()


def _drainpipe(h: int) -> Image.Image:
    w = 22
    L = Layer(w, h, ss=2)
    p = L.rect(6, 0, 16, h - 20)
    L.paint(p, L.tex("#6a7178", 0.06, 3, 701))
    L.shade(p, L.gx(6, 16, 1.25, 0.65))
    for y in range(10, h - 20, 70):
        L.paint(L.rect(4, y, 18, y + 5), hexc("#454b51"))
    L.rust_streaks(p, 702, 0.55, cell=(1.2, 20))
    # 底部冰锥 + 冰坨
    L.paint(L.poly([(5, h - 22), (17, h - 22), (19, h - 4), (3, h - 4)]), hexc("#c3d6e4"), 0.92)
    L.paint(L.poly([(7, h - 22), (10, h - 22), (8, h - 6)]), hexc("#f2f8fc"), 0.7)
    return L.finish()


def bake_facade() -> tuple[Image.Image, Image.Image]:
    """北侧立面：按 LY.META["facade"] 选一种墙。返回 (立面精灵, 窗光灯光贴图)。"""
    kind = facade_kind()
    if kind == "depot":
        return _facade_depot()
    if kind == "manor":
        return _facade_manor()
    if kind != "khrushchyovka":
        raise SystemExit(f"未知的立面种类 '{kind}'（gen_env 里只实现了 khrushchyovka / depot / manor）")
    return _facade_khrushchyovka()


def _facade_khrushchyovka() -> tuple[Image.Image, Image.Image]:
    """赫鲁晓夫楼（yard）：4 层预制板 + 阳台 + 焊死的入口 + 电传终端 + 公告栏 + 锅炉房通风口。"""
    fh = facade_h()
    FH = FACADE_H
    if fh != FH:
        raise SystemExit(f"赫鲁晓夫楼立面的开窗模数写死在 {FH}px（FLOORS_Y / PLINTH_Y），本关 FACADE_H={fh}")
    w = _gw()
    img = Image.new("RGBA", (w, FH), (0, 0, 0, 0))
    glows: list[tuple] = []  # (x0,y0,x1,y1,rgb,intensity)
    r = np.random.default_rng(1717)
    cols = w // PANEL_W
    door_px = LY.FACADE_FEATURES["door_x"] * PPM
    lit_set = {(2, 3), (5, 1), (6, 2), (9, 0), (11, 2), (13, 1), (14, 3), (3, 0), (8, 3), (12, 0)}
    boarded = {(0, 0), (15, 0), (10, 1)}
    for f, y0 in enumerate(FLOORS_Y):
        floor_no = 4 - f  # 4F..1F
        for c in range(cols):
            lit = (c, f) in lit_set
            ground = floor_no == 1
            pnl = _panel(floor_no, lit, 1000 + c * 13 + f * 71, ground, (c, f) in boarded)
            _paste(img, pnl, c * PANEL_W, y0)
            if lit:
                glows.append((c * PANEL_W + 66, y0 + 32, c * PANEL_W + 127, y0 + 106,
                              hexc("#f2b866"), 1.0))
    # 勒脚
    L = Layer(w, 40, ss=1)
    pl = L.rect(0, 0, w, 40)
    L.paint(pl, L.tex("#5f6367", 0.08, 6, 801))
    L.grime(pl, 802, 0.3, 9)
    L.paint(L.rect(0, 0, w, 3), hexc("#383c40"))
    for c in range(cols):
        if c in (3, 9, 12):
            L.paint(L.rect(c * PANEL_W + 80, 8, c * PANEL_W + 112, 26), hexc("#181c20"))
    _paste(img, L.finish(outline=None), 0, PLINTH_Y)
    # 阳台（2F~4F 部分开间）
    for f, y0 in enumerate(FLOORS_Y[:3]):
        for c in (1, 4, 6, 10, 13, 15):
            if (c + f) % 3 == 2:
                continue
            bal = _balcony(2000 + c * 7 + f)
            floor_line = y0 + FLOOR_H
            _paste(img, bal, c * PANEL_W + 4, floor_line - 80)
    # 落水管
    for x in (976, 2406):
        _paste(img, _drainpipe(FH), x, 0)
    # 一楼：入口（焊死）、电传终端、公告栏、锅炉房通风口
    porch = _door_porch()
    _paste(img, porch, door_px - porch.width / 2, FH - porch.height)
    glows.append((door_px - 10, FH - porch.height + 60, door_px + 10, FH - porch.height + 80,
                  hexc("#f2c27a"), 1.2))
    term = _terminal()
    tx = LY.FACADE_FEATURES["terminal_x"] * PPM
    _paste(img, term, tx - term.width / 2, FH - 40 - term.height)
    glows.append((tx - 20, FH - 40 - term.height + 26, tx + 20, FH - 40 - term.height + 52,
                  hexc("#4ade80"), 1.3))
    board = _notice_board()
    bx = LY.FACADE_FEATURES["board_x"] * PPM
    _paste(img, board, bx - board.width / 2, FH - 30 - board.height)
    vent = _vent()
    vx = LY.FACADE_FEATURES["vent_x"] * PPM
    _paste(img, vent, vx - vent.width / 2, FH - vent.height)
    glows.append((vx - 48, FH - 50, vx + 48, FH - 8, hexc("#f08a3a"), 1.4))
    # 墙脚积雪
    L = Layer(w, 60, ss=1)
    n = vnoise(1, w, 60, 1, 901)[0]
    top = 60 - (18 + 22 * n)
    m = (L.Y >= top[None, :]).astype(np.float32)
    L.paint(m, lerp(hexc("#eef3f8"), hexc("#b8c6d4"), L.gy(10, 60, 0, 1)))
    _paste(img, L.finish(outline=None), 0, FH - 60)
    # 顶部压暗融进夜空
    arr = np.asarray(img, np.float32) / 255.0
    yy = np.arange(FH, dtype=np.float32)[:, None]
    dark = smooth(120, 0, yy)
    arr[..., :3] = arr[..., :3] * (1 - 0.65 * dark[..., None]) + hexc("#0b0f14") * 0.65 * dark[..., None]
    img = Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    return _facade_glow(img, glows, FH)


# ===========================================================================
# 窗光灯光贴图（两种立面共用）
# ===========================================================================
def _facade_glow(img: Image.Image, glows: list, fh: int) -> tuple[Image.Image, Image.Image]:
    """glows = [(x0, y0, x1, y1, rgb, intensity)] → (立面精灵, 窗光贴图 w×(fh+GLOW_SPILL))。

    一楼的光（y1 落在墙脚 160px 以内）会额外向下展开一个柔和扇形，洒到雪地上。
    """
    w = img.width
    gh = fh + GLOW_SPILL
    core = np.zeros((gh, w, 3), np.float32)
    spill = np.zeros((gh, w, 3), np.float32)
    yy = np.arange(gh, dtype=np.float32)[:, None]
    xx = np.arange(w, dtype=np.float32)[None, :]
    for (x0, y0, x1, y1, c, k) in glows:
        core[int(y0):int(y1), int(x0):int(x1)] += c * k
        if y1 > fh - 160:  # 一楼的光洒到雪地上：向下展开的柔和扇形
            cx, half = (x0 + x1) / 2, (x1 - x0) / 2
            dy = np.clip((yy - fh) / 120.0, 0, 1)
            fan = smooth(half + 40 + dy * 50, half * 0.4, np.abs(xx - cx)) * (1 - dy) ** 1.6 * (yy >= fh - 4)
            spill += fan[..., None] * c * k * 0.5
    glow = blur_rgb(core, 2) * 1.0 + blur_rgb(core, 16) * 0.55 + blur_rgb(core, 48) * 0.35 + blur_rgb(spill, 14)
    return img, to_img(np.clip(glow, 0, 1))


def _darken_top(img: Image.Image, fh: int, band: float = 120.0, amt: float = 0.65) -> Image.Image:
    """顶部压暗，让墙 / 屋顶融进夜空（与赫鲁晓夫楼立面同一套算法）。"""
    arr = np.asarray(img, np.float32) / 255.0
    yy = np.arange(fh, dtype=np.float32)[:, None]
    dark = smooth(band, 0, yy)
    arr[..., :3] = arr[..., :3] * (1 - amt * dark[..., None]) + hexc("#0b0f14") * amt * dark[..., None]
    return Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


# ===========================================================================
# 机车库砖墙 + 调度塔（marshalling）
# ===========================================================================
def _depot_brick(L: Layer, m: np.ndarray, seed: int, base: str = "#6b443c") -> None:
    """在 mask 内画砖：错缝砌 + 每块砖明暗抖动 + 灰缝 + 顶部烟熏。"""
    L.paint(m, L.tex(base, 0.09, 8, seed))
    course_h, brick_w = 13.0, 34.0
    row = np.floor((L.Y - 120.0) / course_h)
    off = (np.abs(row).astype(np.int64) % 2) * (brick_w / 2.0)
    ci = np.floor((L.X + off) / brick_w)
    jit = (np.sin(ci * 12.9898 + row * 78.233) * 43758.5453) % 1.0
    L.shade(m, 0.86 + 0.3 * jit)
    my = (((L.Y - 120.0) % course_h) < 1.7).astype(np.float32)
    mx = (((L.X + off) % brick_w) < 1.9).astype(np.float32)
    L.paint(m * np.clip(my + mx, 0, 1), hexc("#463f3a"), 0.8)
    # 烟熏（屋顶排烟口正下方最重）+ 风化的白霜
    L.tint(m, hexc("#2b2724"), 0.55 * smooth(300.0, 130.0, L.Y))
    L.tint(m, hexc("#c9d6e0"), 0.16 * smooth(0.62, 0.88, L.noise(5, seed + 3)))
    L.grime(m, seed + 5, 0.22, 9)
    L.rust_streaks(m, seed + 7, 0.3, color="#5b3a26", cell=(2.2, 26))


def _depot_window(L: Layer, cx: float, y0: float, ww: float, wh: float, mode: str, seed: int) -> None:
    """工业钢窗：mode = dark | lit | broken。y0 = 窗顶。"""
    x0, x1, y1 = cx - ww / 2, cx + ww / 2, y0 + wh
    frame = L.rect(x0 - 5, y0 - 5, x1 + 5, y1 + 7)
    L.paint(frame, L.tex("#3d4a44", 0.07, 5, seed))
    L.shade(frame, L.gy(y0 - 5, y1 + 7, 1.12, 0.8))
    glass = L.rect(x0, y0, x1, y1)
    if mode == "lit":
        L.paint(glass, L.tex("#f0b469", 0.06, 14, seed + 1))
        L.shade(glass, L.gy(y0, y1, 1.14, 0.86))
        # 灯罩在玻璃上的两块亮斑
        L.paint(L.ellipse(cx - ww * 0.18, y0 + wh * 0.42, ww * 0.16, wh * 0.2), hexc("#ffe6b0"), 0.5)
        L.paint(L.ellipse(cx + ww * 0.2, y0 + wh * 0.6, ww * 0.12, wh * 0.14), hexc("#ffd79a"), 0.35)
    else:
        L.paint(glass, L.tex("#1b2229", 0.1, 9, seed + 1))
        L.shade(glass, L.gy(y0, y1, 1.25, 0.7))
        L.paint(L.poly([(x0, y0), (x0 + ww * 0.34, y0), (x0, y0 + wh * 0.5)]), hexc("#39454f"), 0.35)
        if mode == "broken":
            r = np.random.default_rng(seed + 2)
            for _ in range(9):
                bx = r.uniform(x0 + 6, x1 - 6)
                by = r.uniform(y0 + 6, y1 - 6)
                L.paint(L.poly([(bx, by), (bx + r.uniform(6, 26), by + r.uniform(-8, 8)),
                                (bx + r.uniform(-4, 10), by + r.uniform(8, 30))]), hexc("#0a0d10"), 0.95)
            L.paint(L.poly([(x0 + 4, y1 - 4), (x0 + ww * 0.4, y1 - 4), (x0 + ww * 0.3, y1 - 26),
                            (x0 + 8, y1 - 20)]), hexc("#6a5a44"), 0.9)   # 挡风的木板
    # 窗棂（3 竖 2 横）
    for k in (1, 2, 3):
        xx = x0 + ww * k / 4
        L.paint(L.rect(xx - 1.6, y0, xx + 1.6, y1), hexc("#33403a"))
    for k in (1, 2):
        yy = y0 + wh * k / 3
        L.paint(L.rect(x0, yy - 1.6, x1, yy + 1.6), hexc("#33403a"))
    # 窗台上的雪 + 冰锥
    L.snow_cap(x0 - 7, x1 + 7, y1 + 8, 9, seed + 4, droop=0.3)
    L.icicles(x0, x1, y1 + 9, 16, 12, seed + 6, 2.0)
    L.snow_cap(x0 - 7, x1 + 7, y0 - 3, 7, seed + 8, droop=0.2)


def _depot_rollup(L: Layer, cx: float, base: float, dw: float, dh: float, seed: int) -> None:
    """卷帘货门：竖向压型钢板 + 导轨 + 链条挂锁 + 门脚积雪。"""
    x0, x1, y0 = cx - dw / 2, cx + dw / 2, base - dh
    L.paint(L.rect(x0 - 9, y0 - 22, x1 + 9, y0 + 4), L.tex("#4a4e52", 0.06, 6, seed))   # 门楣
    L.snow_cap(x0 - 12, x1 + 12, y0 - 20, 12, seed + 1, droop=0.3)
    door = L.rect(x0, y0, x1, base)
    L.paint(door, L.tex("#5d666d", 0.05, 10, seed + 2))
    rib = ((L.X % 15.0) < 7.5).astype(np.float32)
    L.shade(door, 1.0 + 0.09 * rib)
    for k in range(int(dh // 26)):       # 卷帘的横向接缝
        yy = y0 + 12 + k * 26
        L.paint(L.rect(x0, yy, x1, yy + 2.2), hexc("#39413f"), 0.75)
        L.paint(L.rect(x0, yy + 2.2, x1, yy + 3.4), hexc("#7d878e"), 0.35)
    L.shade(door, L.gy(y0, base, 1.06, 0.74))
    L.grime(door, seed + 3, 0.28, 11)
    L.rust_streaks(door, seed + 4, 0.5, color="#6d4526", cell=(3.0, 40))
    for xx in (x0 - 7, x1 + 1):          # 导轨
        L.paint(L.rect(xx, y0 - 6, xx + 6, base + 4), hexc("#3a3f43"))
        L.paint(L.rect(xx, y0 - 6, xx + 2, base + 4), hexc("#6c757c"), 0.6)
    # 链条 + 挂锁（斜着拉过门面）
    L.paint(L.line([(x0 + 8, base - dh * 0.42), (x1 - 8, base - dh * 0.5)], 3.4), hexc("#25292c"))
    L.paint(L.line([(x0 + 8, base - dh * 0.42), (x1 - 8, base - dh * 0.5)], 1.4), hexc("#8d959b"), 0.7)
    mx, my = (x0 + x1) / 2, base - dh * 0.46
    L.paint(L.rect(mx - 11, my - 3, mx + 11, my + 21), hexc("#3b3f2c"))
    L.paint(L.arc(mx, my - 3, 8, 9, 180, 360, 3.4), hexc("#9aa1a6"))
    # 编号牌（不用字体：两块白漆条 + 一个红章方块）
    L.paint(L.rect(x0 + 26, y0 + 40, x0 + 108, y0 + 78), hexc("#7d8791"), 0.85)
    L.paint(L.rect(x0 + 34, y0 + 50, x0 + 96, y0 + 57), hexc("#e7eae4"), 0.75)
    L.paint(L.rect(x0 + 34, y0 + 62, x0 + 74, y0 + 69), hexc("#e7eae4"), 0.6)
    L.paint(L.rect(x1 - 62, y0 + 44, x1 - 26, y0 + 80), hexc("#8e2b22"), 0.7)
    L.snow_cap(x0 - 14, x1 + 14, base + 2, 15, seed + 5, droop=0.0)
    L.icicles(x0, x1, y0 + 6, 14, 26, seed + 7, 2.2)


def _depot_tower(L: Layer, cx: float, fh: float, glows: list, seed: int) -> None:
    """调度塔：砖砌塔身 + 外挂钢梯 + 顶层玻璃调度室（CRT 绿光 + 台灯暖光）+ 天线。"""
    tw = 3.6 * PPM                 # 塔身宽 230px
    cab_w, cab_h = 4.4 * PPM, 118  # 调度室 282×118
    foot, top = fh - 40, 168         # 塔身：从勒脚到调度室地板
    x0, x1 = cx - tw / 2, cx + tw / 2
    body = L.rect(x0, top, x1, foot)
    _depot_brick(L, body, seed, base="#6f4a40")
    L.shade(body, L.gx(x0, x1, 1.1, 0.82))       # 西亮东暗
    # 塔身的小窗（每层一扇，只有中间那层亮着）
    for k, (wy, mode) in enumerate(((top + 42, "dark"), (top + 148, "lit"), (top + 252, "dark"))):
        _depot_window(L, cx, wy, 74, 96, mode, seed + 20 + k * 3)
        if mode == "lit":
            glows.append((cx - 34, wy + 8, cx + 34, wy + 90, hexc("#f2b866"), 0.85))
    # 外挂钢梯（之字形）+ 平台栏杆
    for k in range(6):
        ya, yb = foot - 20 - k * 62, foot - 82 - k * 62
        sx = x1 - 16 if k % 2 == 0 else x1 - 74
        ex = x1 - 74 if k % 2 == 0 else x1 - 16
        L.paint(L.line([(sx, ya), (ex, yb)], 4.0), hexc("#2f3538"))
        for s in range(5):
            t = s / 4.0
            L.paint(L.rect(sx + (ex - sx) * t - 1, ya + (yb - ya) * t - 9, sx + (ex - sx) * t + 1,
                           ya + (yb - ya) * t), hexc("#454c50"), 0.9)
    L.paint(L.rect(x1 - 84, top + 8, x1 + 4, top + 14), hexc("#39413f"))    # 平台
    L.snow_cap(x1 - 86, x1 + 6, top + 10, 6, seed + 31, droop=0.2)
    # 调度室：一圈玻璃 + 型钢框 + 屋顶
    cab = L.rect(cx - cab_w / 2, top - cab_h, cx + cab_w / 2, top)
    L.paint(cab, L.tex("#16232b", 0.08, 12, seed + 40))
    L.shade(cab, L.gy(top - cab_h, top, 1.3, 0.8))
    # 里面：CRT 的绿光 + 桌上的台灯 + 人影
    L.paint(L.rect(cx - cab_w / 2 + 26, top - cab_h + 34, cx - 24, top - 26), hexc("#2f7a4a"), 0.75)
    L.paint(L.rect(cx + 18, top - cab_h + 40, cx + 96, top - 30), hexc("#e8b46a"), 0.55)
    L.paint(L.ellipse(cx - 58, top - 46, 15, 22), hexc("#0d1216"), 0.85)      # 值班员的剪影
    L.paint(L.rect(cx - 74, top - 26, cx + 118, top - 18), hexc("#1d2429"), 0.9)   # 桌沿
    for k in range(6):                                                          # 型钢窗框
        xx = cx - cab_w / 2 + 10 + k * (cab_w - 20) / 5
        L.paint(L.rect(xx - 3, top - cab_h, xx + 3, top), hexc("#2c3438"))
    L.paint(L.rect(cx - cab_w / 2, top - cab_h + cab_h * 0.5 - 2, cx + cab_w / 2,
                   top - cab_h + cab_h * 0.5 + 2), hexc("#2c3438"))
    L.paint(L.rect(cx - cab_w / 2 - 8, top - cab_h - 12, cx + cab_w / 2 + 8, top - cab_h + 6),
            L.tex("#4c5257", 0.06, 6, seed + 41))                              # 挑檐
    L.snow_cap(cx - cab_w / 2 - 10, cx + cab_w / 2 + 10, top - cab_h - 8, 17, seed + 42, droop=0.35)
    L.icicles(cx - cab_w / 2, cx + cab_w / 2, top - cab_h + 6, 22, 34, seed + 43, 2.2)
    # 天线 + 喇叭 + 航空障碍灯
    L.paint(L.line([(cx + 74, top - cab_h - 10), (cx + 74, top - cab_h - 118)], 3.0), hexc("#39413f"))
    for k in range(4):
        yy = top - cab_h - 34 - k * 20
        L.paint(L.line([(cx + 74, yy), (cx + 92, yy - 8)], 1.6), hexc("#4a5257"), 0.9)
    L.paint(L.poly([(cx - 96, top - cab_h - 14), (cx - 62, top - cab_h - 26), (cx - 62, top - cab_h - 2),
                    (cx - 96, top - cab_h - 14)]), hexc("#5a6167"))            # 号角喇叭
    L.paint(L.ellipse(cx + 74, top - cab_h - 120, 5, 5), hexc("#c8402f"))
    glows.append((cx + 66, top - cab_h - 128, cx + 82, top - cab_h - 112, hexc("#e04a33"), 0.7))
    glows.append((cx - cab_w / 2 + 22, top - cab_h + 30, cx - 20, top - 22, hexc("#4ade80"), 1.15))
    glows.append((cx + 14, top - cab_h + 36, cx + 100, top - 26, hexc("#f2c27a"), 1.0))
    # 塔基：乘务员门 + 门灯
    dm = L.rect(cx - 40, foot - 150, cx + 40, foot)
    L.paint(dm, L.tex("#4b5257", 0.06, 6, seed + 50))
    L.paint(L.rect(cx - 46, foot - 156, cx + 46, foot - 148), hexc("#3a4045"))
    L.paint(L.rect(cx + 22, foot - 86, cx + 34, foot - 74), hexc("#9aa1a6"))
    L.snow_cap(cx - 48, cx + 48, foot - 2, 12, seed + 51, droop=0.0)


def _facade_depot() -> tuple[Image.Image, Image.Image]:
    """机车库 / 调度塔立面（marshalling）：砖墙 + 两扇卷帘货门 + 工业钢窗 + 塔 + 发车令板的位置。"""
    w = _gw()
    fh = facade_h()
    L = Layer(w, fh, ss=1)
    glows: list[tuple] = []
    F = LY.FACADE_FEATURES
    wall_top, plinth_top = 128, fh - 40

    # ---- 屋顶（锯齿形天窗的剪影）----
    roof_pts = [(0, wall_top)]
    for k in range(int(w // 240) + 1):
        x = k * 240
        roof_pts += [(x, wall_top - 34), (x + 150, wall_top - 78), (x + 240, wall_top - 34)]
    roof_pts += [(w, wall_top)]
    roof = L.poly(roof_pts)
    L.paint(roof, L.tex("#2b3238", 0.05, 9, 401))
    L.shade(roof, L.gy(wall_top - 80, wall_top, 1.15, 0.8))
    for k in range(int(w // 240) + 1):                       # 天窗玻璃（全暗：车间早停电了）
        x = k * 240 + 42
        L.paint(L.poly([(x, wall_top - 44), (x + 92, wall_top - 72), (x + 92, wall_top - 40),
                        (x, wall_top - 34)]), hexc("#141b21"), 0.9)
    L.snow_cap(0, w, wall_top - 30, 16, 402, droop=0.25)
    for k in range(int(w // 240) + 1):
        L.snow_cap(k * 240 + 148, k * 240 + 244, wall_top - 34, 13, 403 + k, droop=0.3)

    # ---- 砖墙 + 勒脚 + 挑檐 ----
    wall = L.rect(0, wall_top, w, plinth_top)
    _depot_brick(L, wall, 410)
    L.paint(L.rect(0, wall_top - 6, w, wall_top + 20), L.tex("#59616a", 0.06, 7, 411))   # 挑檐
    L.snow_cap(0, w, wall_top + 2, 15, 412, droop=0.35)
    L.icicles(0, w, wall_top + 20, 26, int(w // 26), 413, 2.4)
    pl = L.rect(0, plinth_top, w, fh)
    L.paint(pl, L.tex("#5f6367", 0.08, 6, 801))
    L.grime(pl, 802, 0.3, 9)
    L.paint(L.rect(0, plinth_top, w, plinth_top + 3), hexc("#383c40"))

    # ---- 卷帘货门 ----
    for i, dx in enumerate(F.get("freight_x", [])):
        _depot_rollup(L, dx * PPM, plinth_top + 6, 4.0 * PPM, 296, 420 + i * 9)

    # ---- 工业钢窗（避开货门与调度塔）----
    tower_x = F.get("tower_x")
    for i, wx in enumerate(F.get("windows_x", [9.0, 13.2, 26.4, 34.6, 39.4])):
        if tower_x is not None and abs(wx - tower_x) < 3.2:
            continue
        mode = ("lit", "dark", "dark", "lit", "broken")[i % 5]
        _depot_window(L, wx * PPM, 296, 2.0 * PPM, 104, mode, 440 + i * 5)
        if mode == "lit":
            glows.append((wx * PPM - 58, 306, wx * PPM + 58, 392, hexc("#f2b866"), 0.95))

    # ---- 乘务员门（发车令就钉在它旁边）----
    dx = F.get("door_x", 14.0) * PPM
    door = L.rect(dx - 38, plinth_top - 142, dx + 38, plinth_top + 4)
    L.paint(door, L.tex("#4f565b", 0.06, 6, 460))
    L.shade(door, L.gy(plinth_top - 142, plinth_top, 1.1, 0.82))
    L.paint(L.rect(dx - 44, plinth_top - 150, dx + 44, plinth_top - 140), hexc("#3a4045"))
    L.paint(L.rect(dx - 30, plinth_top - 118, dx + 4, plinth_top - 40), hexc("#414a4f"), 0.8)
    L.paint(L.rect(dx + 18, plinth_top - 78, dx + 30, plinth_top - 66), hexc("#9aa1a6"))
    L.paint(L.rect(dx - 44, plinth_top - 152, dx + 44, plinth_top - 148), hexc("#8e2b22"), 0.75)  # 红漆门楣
    L.snow_cap(dx - 46, dx + 46, plinth_top - 146, 9, 461, droop=0.25)
    L.paint(L.ellipse(dx, plinth_top - 176, 13, 9), hexc("#2f3538"))       # 门灯
    L.paint(L.ellipse(dx, plinth_top - 174, 8, 5), hexc("#ffd9a0"), 0.9)
    glows.append((dx - 26, plinth_top - 190, dx + 26, plinth_top - 160, hexc("#f2c27a"), 1.25))
    # 红星模板漆（门边）
    sx, sy = dx + 76, plinth_top - 96
    star = [(sx + 26 * math.cos(math.radians(a)), sy + 26 * math.sin(math.radians(a)))
            for a in range(-90, 270, 144)]
    L.paint(L.poly(star), hexc("#9c3327"), 0.7)

    # ---- 搪瓷站名牌（不用字体：白漆条抽象成「西站」）----
    bx = F.get("sign_x", 24.0) * PPM
    L.paint(L.rect(bx - 62, 336, bx + 62, 386), L.tex("#2f4a63", 0.07, 6, 470))
    L.paint(L.rect(bx - 66, 332, bx + 66, 340), hexc("#7d8791"), 0.8)
    L.paint(L.rect(bx - 46, 350, bx - 6, 360), hexc("#e7eae4"), 0.8)
    L.paint(L.rect(bx + 2, 350, bx + 42, 360), hexc("#e7eae4"), 0.8)
    L.paint(L.rect(bx - 30, 366, bx + 26, 374), hexc("#e7eae4"), 0.55)
    L.rust_streaks(L.rect(bx - 62, 336, bx + 62, 386), 471, 0.45, color="#7a5a34", cell=(1.4, 12))
    L.snow_cap(bx - 68, bx + 68, 336, 8, 472, droop=0.2)

    # ---- 调度塔 ----
    if tower_x is not None:
        _depot_tower(L, tower_x * PPM, fh, glows, 480)

    # ---- 电缆桥架 + 落水管 ----
    L.paint(L.rect(0, 246, w, 258), hexc("#33393d"))
    L.paint(L.rect(0, 246, w, 250), hexc("#5b6267"), 0.7)
    for x in range(96, w, 320):
        L.paint(L.rect(x, 240, x + 8, 272), hexc("#2b3033"))
    L.snow_cap(0, w, 248, 7, 490, droop=0.15)
    img = L.finish()
    for x in (2.0 * PPM, 17.4 * PPM, 42.0 * PPM):
        _paste(img, _drainpipe(fh), x, 0)

    # ---- 墙脚积雪 ----
    L2 = Layer(w, 60, ss=1)
    n = vnoise(1, w, 60, 1, 901)[0]
    top = 60 - (16 + 24 * n)
    m = (L2.Y >= top[None, :]).astype(np.float32)
    L2.paint(m, lerp(hexc("#eef3f8"), hexc("#b8c6d4"), L2.gy(10, 60, 0, 1)))
    _paste(img, L2.finish(outline=None), 0, fh - 60)

    return _facade_glow(_darken_top(img, fh), glows, fh)

# ===========================================================================
# 松林庄园 · 二号恒温库 + 焚化车间（manor）
# ===========================================================================
def _manor_blast_door(L: Layer, cx: float, base: float, dw: float, dh: float, glows: list, seed: int) -> None:
    """恒温库的保温防爆门：门框 hazard 条纹 + 转轮把手 + 门缝冷气 + 一圈霜。"""
    x0, x1, y0 = cx - dw / 2, cx + dw / 2, base - dh
    L.paint(L.rect(x0 - 16, y0 - 16, x1 + 16, base + 2), L.tex("#565c62", 0.06, 6, seed))
    # hazard 条纹门框
    fr = L.rect(x0 - 16, y0 - 16, x1 + 16, base + 2) - L.rect(x0 - 4, y0 - 4, x1 + 4, base + 2)
    stripe = ((L.X + L.Y) % 26.0 < 13.0).astype(np.float32)
    L.paint(fr, hexc("#b8a02c"), 0.85)
    L.paint(fr * stripe, hexc("#191a1c"), 0.9)
    L.grime(fr, seed + 1, 0.3, 8)
    door = L.rect(x0, y0, x1, base)
    L.paint(door, L.tex("#8b949c", 0.05, 9, seed + 2))
    for k in range(4):     # 保温板的横缝
        yy = y0 + 14 + k * (dh - 20) / 4
        L.paint(L.rect(x0, yy, x1, yy + 3), hexc("#5f686f"), 0.8)
        L.paint(L.rect(x0, yy + 3, x1, yy + 4.6), hexc("#aeb6bd"), 0.5)
    L.shade(door, L.gx(x0, x1, 1.08, 0.84))
    L.shade(door, L.gy(y0, base, 1.04, 0.86))
    # 转轮把手 + 铰链
    wx, wy = cx + dw * 0.26, y0 + dh * 0.52
    L.paint(L.ellipse(wx, wy, 26, 26), hexc("#39413f"))
    L.paint(L.ellipse(wx, wy, 20, 20), hexc("#6c757c"))
    for a in range(0, 360, 120):
        L.paint(L.line([(wx, wy), (wx + 19 * math.cos(math.radians(a)), wy + 19 * math.sin(math.radians(a)))],
                       4), hexc("#4a5157"))
    L.paint(L.ellipse(wx, wy, 6, 6), hexc("#22262a"))
    for yy in (y0 + 30, base - 40):
        L.paint(L.rect(x0 + 4, yy, x0 + 18, yy + 26), hexc("#4a5157"))
    # 门缝冷气（冷光缝 + 垂霜）
    L.paint(L.rect(x0 + 2, base - 10, x1 - 2, base - 2), hexc("#bfe3ff"), 0.85)
    glows.append((x0 + 4, base - 12, x1 - 4, base, hexc("#bfe3ff"), 0.9))
    frost = smooth(0.5, 0.85, L.noise(3, seed + 3))
    ring = (L.rect(x0 - 22, y0 - 22, x1 + 22, base + 2) - L.rect(x0 - 2, y0 - 2, x1 + 2, base + 2))
    L.tint(ring, hexc("#dfeaf2"), 0.55 * frost)
    L.icicles(x0 - 10, x1 + 10, y0 - 12, 20, 22, seed + 4, 2.2)
    L.snow_cap(x0 - 18, x1 + 18, y0 - 14, 10, seed + 5, droop=0.3)


def _facade_manor() -> tuple[Image.Image, Image.Image]:
    """松林庄园：左半 = 二号恒温库（保温板 + 防爆门 + 行政钢廊），右半 = 焚化车间（砖 + 烟囱 + 炉口）。"""
    w = _gw()
    fh = facade_h()
    L = Layer(w, fh, ss=1)
    glows: list[tuple] = []
    F = LY.FACADE_FEATURES
    split = F.get("split_x", 24.0) * PPM        # 恒温库 / 焚化车间的分界
    wall_top, plinth_top = 150, fh - 40

    # ---- 左：恒温库保温板墙 ----
    dep = L.rect(0, wall_top, split, plinth_top)
    L.paint(dep, L.tex("#79828a", 0.05, 10, 601))
    for xx in np.arange(24, split, 76):        # 保温板竖缝
        L.paint(L.rect(xx, wall_top, xx + 2.4, plinth_top), hexc("#5a626a"), 0.8)
        L.paint(L.rect(xx + 2.4, wall_top, xx + 3.6, plinth_top), hexc("#98a1a9"), 0.5)
    L.shade(dep, L.gy(wall_top, plinth_top, 1.06, 0.84))
    L.grime(dep, 602, 0.18, 12)
    # 蓝漆带 + 「№2」搪瓷字（不用字体：白漆条）
    L.paint(L.rect(0, 236, split, 292), hexc("#2f4a63"), 0.9)
    L.paint(L.rect(0, 236, split, 240), hexc("#7d8791"), 0.7)
    bx = F.get("sign_x", 8.0) * PPM
    L.paint(L.rect(bx - 40, 248, bx - 12, 282), hexc("#e7eae4"), 0.85)      # №
    L.paint(L.rect(bx - 4, 248, bx + 34, 282), hexc("#e7eae4"), 0.85)       # 2
    L.paint(L.rect(bx + 4, 256, bx + 26, 262), hexc("#2f4a63"), 0.9)
    L.paint(L.rect(bx + 4, 268, bx + 26, 274), hexc("#2f4a63"), 0.9)
    L.rust_streaks(L.rect(0, 236, split, 292), 603, 0.3, color="#6a4a2a", cell=(1.6, 14))
    # 高窗（clerestory）：两扇亮着（墙里 26℃）
    for i, wx in enumerate(F.get("windows_x", [4.0, 11.0, 17.0, 21.0])):
        mode = ("lit", "dark", "lit", "dark")[i % 4]
        _depot_window(L, wx * PPM, 176, 1.5 * PPM, 66, mode, 610 + i * 5)
        if mode == "lit":
            glows.append((wx * PPM - 42, 184, wx * PPM + 42, 236, hexc("#f2c27a"), 0.9))
    # 行政监控钢廊（二楼 Overwatch）
    cy = F.get("catwalk_y", 320)
    L.paint(L.rect(0, cy, split, cy + 16), hexc("#39413f"))
    L.paint(L.rect(0, cy, split, cy + 4), hexc("#5b6267"), 0.8)
    for xx in np.arange(20, split, 64):        # 栏杆立柱
        L.paint(L.rect(xx, cy - 34, xx + 3, cy), hexc("#454c50"), 0.95)
    L.paint(L.rect(0, cy - 36, split, cy - 32), hexc("#4a5157"))
    L.paint(L.rect(0, cy - 20, split, cy - 17), hexc("#4a5157"), 0.8)
    L.snow_cap(0, split, cy - 34, 6, 620, droop=0.15)
    L.snow_cap(0, split, cy + 2, 8, 621, droop=0.2)
    for k, lx in enumerate(F.get("catwalk_lamps_x", [6.0, 16.0])):   # 钢廊灯 + 值守的剪影
        lxx = lx * PPM
        L.paint(L.ellipse(lxx, cy - 44, 9, 6), hexc("#2f3538"))
        L.paint(L.ellipse(lxx, cy - 42, 5.5, 3.6), hexc("#ffd9a0"), 0.9)
        glows.append((lxx - 24, cy - 52, lxx + 24, cy - 30, hexc("#f2c27a"), 1.1))
        if k == 1:
            L.paint(L.poly([(lxx + 70, cy - 2), (lxx + 96, cy - 2), (lxx + 92, cy - 52),
                            (lxx + 84, cy - 64), (lxx + 78, cy - 52)]), hexc("#12161a"), 0.92)
            L.paint(L.ellipse(lxx + 85, cy - 68, 7, 8), hexc("#12161a"), 0.92)
    # 防爆门 + 冷冻门
    _manor_blast_door(L, F.get("blast_x", 13.0) * PPM, plinth_top + 4, 3.0 * PPM, 226, glows, 630)
    fz = F.get("freezer_x", 20.5) * PPM
    L.paint(L.rect(fz - 52, plinth_top - 150, fz + 52, plinth_top + 2), L.tex("#8b949c", 0.05, 7, 640))
    L.paint(L.rect(fz - 44, plinth_top - 140, fz + 44, plinth_top - 4), hexc("#6d767e"))
    L.paint(L.rect(fz - 44, plinth_top - 140, fz + 44, plinth_top - 132), hexc("#39413f"))
    L.paint(L.rect(fz + 26, plinth_top - 84, fz + 38, plinth_top - 70), hexc("#9aa1a6"))
    L.tint(L.rect(fz - 56, plinth_top - 154, fz + 56, plinth_top + 2), hexc("#dfeaf2"),
           0.4 * smooth(0.5, 0.85, L.noise(3, 641)))
    L.icicles(fz - 50, fz + 50, plinth_top - 148, 16, 14, 642, 2.0)
    L.snow_cap(fz - 56, fz + 56, plinth_top - 150, 9, 643, droop=0.25)

    # ---- 右：焚化车间 ----
    hall = L.rect(split, wall_top - 26, w, plinth_top)
    _depot_brick(L, hall, 650, base="#5e463c")
    L.shade(hall, L.gy(wall_top - 26, plinth_top, 1.05, 0.8))
    # 烟囱
    chx = F.get("chimney_x", 40.0) * PPM
    chw = 1.9 * PPM
    chim = L.rect(chx - chw / 2, 0, chx + chw / 2, wall_top - 10)
    L.paint(chim, L.tex("#4e4038", 0.07, 8, 651))
    L.shade(chim, L.gx(chx - chw / 2, chx + chw / 2, 1.12, 0.78))
    for yy in (60, 150, 240):
        L.paint(L.rect(chx - chw / 2 - 4, yy, chx + chw / 2 + 4, yy + 10), hexc("#3a3230"))
        L.snow_cap(chx - chw / 2 - 6, chx + chw / 2 + 6, yy + 2, 6, 652 + int(yy), droop=0.2)
    L.tint(chim, hexc("#221d1a"), 0.5 * smooth(220, 0, L.Y))          # 烟熏
    L.paint(L.ellipse(chx, 26, 7, 7), hexc("#c8402f"))
    glows.append((chx - 10, 16, chx + 10, 36, hexc("#e04a33"), 0.7))
    L.snow_cap(chx - chw / 2 - 3, chx + chw / 2 + 3, 6, 10, 653, droop=0.3)
    # 炉口（2000℃）
    mx = F.get("maw_x", 34.0) * PPM
    mw, mh = 3.2 * PPM, 168
    maw = L.rect(mx - mw / 2, plinth_top - mh, mx + mw / 2, plinth_top + 2)
    L.paint(maw, hexc("#140a07"))
    L.tint(maw, hexc("#ff8a3c"), 0.75 * smooth(plinth_top - 60, plinth_top, L.Y))
    L.tint(maw, hexc("#c8401e"), 0.5 * smooth(plinth_top - 110, plinth_top - 50, L.Y))
    for k in range(4):
        L.paint(L.rect(mx - mw / 2, plinth_top - mh + 26 + k * 34, mx + mw / 2,
                       plinth_top - mh + 32 + k * 34) * maw, hexc("#100604"), 0.85)
    L.paint(L.rect(mx - mw / 2 - 14, plinth_top - mh - 14, mx + mw / 2 + 14, plinth_top - mh),
            L.tex("#4a4038", 0.06, 6, 654))     # 炉眉
    L.snow_cap(mx - mw / 2 - 16, mx + mw / 2 + 16, plinth_top - mh - 12, 9, 655, droop=0.3)
    glows.append((mx - mw / 2 + 6, plinth_top - mh + 20, mx + mw / 2 - 6, plinth_top, hexc("#ff7a2e"), 1.7))
    # 炉口上方的烟熏 + 敞开的进料铁门
    L.tint(hall, hexc("#1c1714"), 0.55 * smooth(plinth_top - 40, wall_top - 20, L.Y)
           * smooth(mw * 1.6, mw * 0.4, np.abs(L.X - mx)))
    fd = L.poly([(mx + mw / 2 + 6, plinth_top - mh + 8), (mx + mw / 2 + 74, plinth_top - mh + 26),
                 (mx + mw / 2 + 74, plinth_top - 6), (mx + mw / 2 + 6, plinth_top - 4)])
    L.paint(fd, L.tex("#3d4348", 0.06, 6, 656))
    L.shade(fd, 0.85)
    L.snow_cap(mx + mw / 2 + 4, mx + mw / 2 + 76, plinth_top - mh + 6, 6, 657, droop=0.2)
    # 车间高窗（全暗）+ 人员门
    for i, wx in enumerate(F.get("hall_windows_x", [28.0, 43.0])):
        _depot_window(L, wx * PPM, 210, 1.6 * PPM, 84, "broken" if i == 1 else "dark", 660 + i * 5)
    pdx = F.get("hall_door_x", 30.0) * PPM
    L.paint(L.rect(pdx - 36, plinth_top - 138, pdx + 36, plinth_top + 2), L.tex("#4f565b", 0.06, 6, 665))
    L.paint(L.rect(pdx - 42, plinth_top - 146, pdx + 42, plinth_top - 136), hexc("#3a4045"))
    L.paint(L.rect(pdx + 16, plinth_top - 76, pdx + 28, plinth_top - 64), hexc("#9aa1a6"))
    L.snow_cap(pdx - 44, pdx + 44, plinth_top - 142, 8, 666, droop=0.25)
    # 沿墙 pipe run
    L.paint(L.rect(split, 356, w, 368), hexc("#4a5157"))
    L.paint(L.rect(split, 356, w, 360), hexc("#6c757c"), 0.7)
    for xx in np.arange(split + 40, w, 260):
        L.paint(L.rect(xx, 350, xx + 8, 380), hexc("#2b3033"))
    L.snow_cap(split, w, 358, 6, 667, droop=0.15)

    # ---- 勒脚 / 女儿墙 / 积雪 ----
    pl = L.rect(0, plinth_top, w, fh)
    L.paint(pl, L.tex("#5f6367", 0.08, 6, 801))
    L.grime(pl, 802, 0.3, 9)
    L.paint(L.rect(0, plinth_top, w, plinth_top + 3), hexc("#383c40"))
    L.paint(L.rect(0, wall_top - 8, split, wall_top + 14), L.tex("#59616a", 0.06, 7, 670))
    L.snow_cap(0, split, wall_top - 4, 14, 671, droop=0.35)
    L.icicles(0, split, wall_top + 14, 24, int(split // 26), 672, 2.4)
    L.paint(L.rect(split, wall_top - 34, w, wall_top - 12), L.tex("#59616a", 0.06, 7, 673))
    L.snow_cap(split, w, wall_top - 30, 14, 674, droop=0.35)
    L.icicles(split, w, wall_top - 12, 22, int((w - split) // 30), 675, 2.2)
    L2 = Layer(w, 60, ss=1)
    n = vnoise(1, w, 60, 1, 901)[0]
    top = 60 - (16 + 24 * n)
    m = (L2.Y >= top[None, :]).astype(np.float32)
    L2.paint(m, lerp(hexc("#eef3f8"), hexc("#b8c6d4"), L2.gy(10, 60, 0, 1)))
    img = L.finish()
    _paste(img, L2.finish(outline=None), 0, fh - 60)
    return _facade_glow(_darken_top(img, fh), glows, fh)

