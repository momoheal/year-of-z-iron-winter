"""环境大图：货场地面烘焙（TIL_01~03 合成）、赫鲁晓夫楼立面（TIL_04）、立面窗光灯光贴图。"""
from __future__ import annotations

import math
import numpy as np
from PIL import Image, ImageDraw

from artlib import (GY, PPM, Layer, blur, blur_rgb, fbm, hexc, lerp, norm01, smooth, to_img,
                    vnoise)
import layout as LY

GW = int(LY.W * PPM)               # 3072
GH = int(round(LY.H * GY))         # 1587
FACADE_H = 600
GLOW_SPILL = 170                   # 窗光贴图在墙脚以下额外延伸的像素（照到雪地上）


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
    w, h = GW, GH
    xs = (np.arange(w, dtype=np.float32) + 0.5) / PPM
    ys = (np.arange(h, dtype=np.float32) + 0.5) / GY
    X, Y = np.meshgrid(xs, ys)
    Ypx = np.arange(h, dtype=np.float32)[:, None] + np.zeros((1, w), np.float32)

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
    yard = ((Y > LY.FACADE_BASE_Y) & (Y < LY.FENCE_Y - 0.15)).astype(np.float32)

    # ---- 院子：混凝土预制板从雪下露出来 ----
    expose = smooth(0.66, 0.82, nm * 0.72 + nb * 0.28 + pathm * 0.18) * yard * 0.8
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
    col = _mix(col, pathm * 0.72 * yard, hexc("#87909b") * 1.0)
    col = _mix(col, pathm * 0.62 * (1 - yard), hexc("#8b939d"))

    # ---- 货场：道砟、枕木、钢轨 ----
    sn = vnoise(h, w, 2.4, 1.7, 21)
    sn2 = vnoise(h, w, 1.2, 0.9, 22)
    stones = hexc("#5a5e65")[None, None, :] * (0.62 + 0.55 * sn + 0.25 * (sn2 - 0.5))[..., None]
    for ti, c in enumerate(LY.TRACKS):
        bal = smooth(2.25, 1.75, np.abs(Y - c) + (nm - 0.5) * 0.7)
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

    # ---- 蒸汽管下的融雪带 ----
    pipe = next(p for p in LY.PROPS if p["id"] == "SteamPipe")
    px0 = pipe["pos"][0] - pipe["fp"][0] / 2
    px1 = pipe["pos"][0] + pipe["fp"][0] / 2
    py = pipe["pos"][1]
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
    n2 = vnoise(1, w, 50, 1, 72)[0]
    fd = smooth(0.45 + 0.35 * n2[None, :], 0.2, np.abs(Y - LY.FENCE_Y - 0.08))
    col = _mix(col, fd * 0.85, hexc("#e3eaf1"))

    # ---- 接触阴影（统一右下偏 15°） ----
    ao = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(ao)
    for p in LY.PROPS:
        x, y = p["pos"]
        fw, fd_ = p["fp"]
        ox, oy = 0.28, 0.22
        if p["id"] in ("LampWest", "LampEast", "SignalPost"):
            d.ellipse([_px(x - 0.3 + ox, y - 0.2 + oy), _px(x + 0.5 + ox, y + 0.25 + oy)], fill=200)
            continue
        if p["id"] == "Playground":
            d.ellipse([_px(x - fw / 2 + ox, y - fd_ + oy), _px(x + fw / 2 + ox, y + 0.2 + oy)], fill=110)
            continue
        if p["id"] == "SteamPipe":
            d.rectangle([_px(x - fw / 2 + 0.1, y - 0.2), _px(x + fw / 2 + 0.3, y + 0.5)], fill=140)
            continue
        d.rounded_rectangle([_px(x - fw / 2 + ox * 0.5, y - fd_ + oy * 0.4),
                             _px(x + fw / 2 + ox, y + oy)], radius=8, fill=210)
    aom = blur(np.asarray(ao, np.float32) / 255.0, 9)
    col = col * (1 - 0.42 * aom)[..., None]
    wall = smooth(LY.FACADE_BASE_Y + 1.1, LY.FACADE_BASE_Y, Y)
    col = col * (1 - 0.38 * wall)[..., None]
    fence_sh = smooth(0.28, 0.0, np.abs(Y - (LY.FENCE_Y + 0.12))) * \
        ~((X > LY.FENCE_GAP[0]) & (X < LY.FENCE_GAP[1]))
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
    """返回 (立面精灵 3072×600, 窗光灯光贴图 3072×(600+GLOW_SPILL))。"""
    w = GW
    img = Image.new("RGBA", (w, FACADE_H), (0, 0, 0, 0))
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
        _paste(img, _drainpipe(FACADE_H), x, 0)
    # 一楼：入口（焊死）、电传终端、公告栏、锅炉房通风口
    porch = _door_porch()
    _paste(img, porch, door_px - porch.width / 2, FACADE_H - porch.height)
    glows.append((door_px - 10, FACADE_H - porch.height + 60, door_px + 10, FACADE_H - porch.height + 80,
                  hexc("#f2c27a"), 1.2))
    term = _terminal()
    tx = LY.FACADE_FEATURES["terminal_x"] * PPM
    _paste(img, term, tx - term.width / 2, FACADE_H - 40 - term.height)
    glows.append((tx - 20, FACADE_H - 40 - term.height + 26, tx + 20, FACADE_H - 40 - term.height + 52,
                  hexc("#4ade80"), 1.3))
    board = _notice_board()
    bx = LY.FACADE_FEATURES["board_x"] * PPM
    _paste(img, board, bx - board.width / 2, FACADE_H - 30 - board.height)
    vent = _vent()
    vx = LY.FACADE_FEATURES["vent_x"] * PPM
    _paste(img, vent, vx - vent.width / 2, FACADE_H - vent.height)
    glows.append((vx - 48, FACADE_H - 50, vx + 48, FACADE_H - 8, hexc("#f08a3a"), 1.4))
    # 墙脚积雪
    L = Layer(w, 60, ss=1)
    n = vnoise(1, w, 60, 1, 901)[0]
    top = 60 - (18 + 22 * n)
    m = (L.Y >= top[None, :]).astype(np.float32)
    L.paint(m, lerp(hexc("#eef3f8"), hexc("#b8c6d4"), L.gy(10, 60, 0, 1)))
    _paste(img, L.finish(outline=None), 0, FACADE_H - 60)
    # 顶部压暗融进夜空
    arr = np.asarray(img, np.float32) / 255.0
    yy = np.arange(FACADE_H, dtype=np.float32)[:, None]
    dark = smooth(120, 0, yy)
    arr[..., :3] = arr[..., :3] * (1 - 0.65 * dark[..., None]) + hexc("#0b0f14") * 0.65 * dark[..., None]
    img = Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")

    # ---- 窗光灯光贴图 ----
    gh = FACADE_H + GLOW_SPILL
    core = np.zeros((gh, w, 3), np.float32)
    spill = np.zeros((gh, w, 3), np.float32)
    yy = np.arange(gh, dtype=np.float32)[:, None]
    xx = np.arange(w, dtype=np.float32)[None, :]
    for (x0, y0, x1, y1, c, k) in glows:
        core[int(y0):int(y1), int(x0):int(x1)] += c * k
        if y1 > FACADE_H - 160:  # 一楼的光洒到雪地上：向下展开的柔和扇形
            cx, half = (x0 + x1) / 2, (x1 - x0) / 2
            dy = np.clip((yy - FACADE_H) / 120.0, 0, 1)
            fan = smooth(half + 40 + dy * 50, half * 0.4, np.abs(xx - cx)) * (1 - dy) ** 1.6 * (yy >= FACADE_H - 4)
            spill += fan[..., None] * c * k * 0.5
    glow = blur_rgb(core, 2) * 1.0 + blur_rgb(core, 16) * 0.55 + blur_rgb(core, 48) * 0.35 + blur_rgb(spill, 14)
    glow_img = to_img(np.clip(glow, 0, 1))
    return img, glow_img
