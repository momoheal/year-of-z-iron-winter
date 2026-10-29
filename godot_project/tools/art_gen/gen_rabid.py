"""CHR_03 灰鳞高热狂暴者精灵表（与 CHR_01/05 同布局：8 列 × 3 行，72×112，pivot (36,108)）。

  行：0=S 1=E 2=N
  列：0 待机（佝偻）· 1-4 奔跑 · 5 扑咬（起跳）· 6 倒地 · 7 抽搐待机
规格书 §1.1 病症关键词：grey-scale skin flakes peeling off, blackened sclera, 40°C fever delirium。
辨识要点：佝偻前倾 + 下垂前伸的手 + 灰白剥落的皮肤 —— 剪影上必须与直立的清杀兵 / 阿列克谢一眼区分。
"""
from __future__ import annotations

import math
import numpy as np
from PIL import Image

from artlib import Layer, hexc, smooth
from gen_chars import CX, FH, FW, GY_, _legs, _limb

RABID = dict(
    kind="rabid",
    trousers="#33363a", trousers_dk="#232528", boots="#2a2420", boot_shaft="#3a332c",
    coat="#3c3730", coat_dk="#28241f", skin="#8d9290", skin_dk="#5a5f5d", hair="#1e1c1a",
)


def _flakes(L, mask, seed):
    """灰鳞：亮暗两色的剥落斑点。"""
    n1 = L.noise(1.1, seed)
    n2 = L.noise(1.6, seed + 1)
    L.paint(mask * smooth(0.6, 0.72, n1), hexc("#cfd3cf"), 0.75)
    L.paint(mask * smooth(0.62, 0.75, n2), hexc("#454947"), 0.7)


def _skin_limb(L, pts, w, seed, dim=1.0):
    m = _limb(L, pts, w, RABID["skin"], RABID["skin_dk"])
    _flakes(L, m, seed)
    L.shade(m, dim)
    return m


def _claw(L, x, y, dirx, dim=1.0):
    L.paint(L.ellipse(x, y, 3.6, 3.2), hexc(RABID["skin"]) * dim)
    for k in (-1.6, 0, 1.6):
        L.paint(L.line([(x + dirx * 2, y + 1 + k * 0.6), (x + dirx * 5, y + 3 + k)], 0.9, False),
                hexc("#2a2826") * dim)


def _torso(L, view, sh, hip, lean, seed):
    P = RABID
    if view == "E":
        pts = [(CX - 6 + lean, sh), (CX + 10 + lean, sh + 3), (CX + 11, hip + 3), (CX + 4, hip + 8),
               (CX - 2, hip + 4), (CX - 9, hip + 7)]
    else:
        pts = [(CX - 14, sh + 2), (CX + 14, sh + 2), (CX + 13, hip + 4), (CX + 7, hip + 9), (CX + 2, hip + 5),
               (CX - 4, hip + 10), (CX - 13, hip + 6)]
    m = L.poly(pts)
    L.paint(m, L.tex(P["coat"], 0.1, 2.5, seed))
    L.shade(m, L.gx(CX - 14, CX + 14 + lean, 1.15, 0.72))
    # 撕破处露出的灰鳞皮肤 + 干涸血迹
    r = np.random.default_rng(seed)
    for _ in range(3):
        x = CX + r.uniform(-9, 9) + lean * 0.5
        y = r.uniform(sh + 6, hip)
        tear = L.ellipse(x, y, r.uniform(2, 4), r.uniform(1.5, 3)) * m
        L.paint(tear, hexc(P["skin"]))
        _flakes(L, tear, seed + 7)
    L.paint(m * smooth(0.62, 0.8, L.noise(3, seed + 3)), hexc("#4a1c1a"), 0.75)
    L.rim(m, 0, -1.2, "#0b0f14", 0.3)


def _head(L, view, hx, hy, open_mouth, seed):
    P = RABID
    if view == "N":
        h = L.ellipse(hx, hy, 7, 8)
        L.paint(h, hexc(P["skin"]))
        _flakes(L, h, seed)
        hair = L.ellipse(hx, hy - 2, 7.5, 7) * smooth(0.3, 0.6, L.noise(1.4, seed + 1) + (hy - L.Y) * 0.05)
        L.paint(hair, hexc(P["hair"]))
        return
    fx = hx + (2 if view == "E" else 0)
    face = L.ellipse(fx, hy, 6.6 if view == "S" else 6.2, 7.6)
    L.paint(face, hexc(P["skin"]))
    L.shade(face, L.gx(fx - 7, fx + 7, 1.1, 0.78))
    _flakes(L, face, seed)
    # 乱发
    hair = L.ellipse(fx - (2 if view == "E" else 0), hy - 5, 7.2, 4.5)
    L.paint(hair * smooth(0.25, 0.55, L.noise(1.2, seed + 2)), hexc(P["hair"]))
    if view == "S":
        for ex in (-2.8, 2.8):
            L.paint(L.ellipse(hx + ex, hy, 2.3, 1.8), hexc("#050505"))
            L.paint(L.ellipse(hx + ex, hy, 0.6, 0.6), hexc("#d8d0c0"))
        L.paint(L.ellipse(hx, hy + 5, 2.6, 2.4 if open_mouth else 1.0), hexc("#1a0c0b"))
        if open_mouth:
            L.paint(L.rect(hx - 2, hy + 3.4, hx + 2, hy + 4.2), hexc("#c8c0a8"))
    else:
        L.paint(L.ellipse(fx + 3.5, hy - 0.5, 2.0, 1.7), hexc("#050505"))
        L.paint(L.ellipse(fx + 4.2, hy - 0.5, 0.55, 0.55), hexc("#d8d0c0"))
        L.paint(L.ellipse(fx + 5.5, hy + 4.5, 2.2, 2.4 if open_mouth else 0.9), hexc("#1a0c0b"))


def _dead(L, seed):
    P = RABID
    y = GY_ - 6
    for a, b, w in (((CX + 4, y), (CX + 26, y + 2), 9.5), ((CX + 4, y + 1), (CX + 24, y - 6), 8.5)):
        m = _limb(L, [a, b], w, P["trousers"], P["trousers_dk"])
    L.paint(L.ellipse(CX + 28, y + 2, 4.5, 3), hexc(P["boots"]))
    body = L.ellipse(CX - 6, y, 15, 6.5)
    L.paint(body, L.tex(P["coat"], 0.1, 2, seed))
    L.paint(body * smooth(0.55, 0.75, L.noise(2.5, seed + 1)), hexc("#4a1c1a"), 0.8)
    _skin_limb(L, [(CX - 10, y - 3), (CX - 16, y - 12), (CX - 24, y - 14)], 6, seed + 2)
    _claw(L, CX - 25, y - 14, -1)
    _skin_limb(L, [(CX - 4, y + 3), (CX + 2, y + 7)], 6, seed + 3, 0.85)
    h = L.ellipse(CX - 23, y + 1, 6.5, 5.5)
    L.paint(h, hexc(P["skin"]))
    _flakes(L, h, seed + 4)
    L.paint(L.ellipse(CX - 25, y - 1, 6, 3.5), hexc(P["hair"]), 0.9)
    L.paint(L.ellipse(CX - 21, y + 2, 1.6, 1.0), hexc("#050505"))
    L.snow_cap(CX - 20, CX + 10, y - 5, 3, seed + 5, droop=0.1, under=body)


def frame(view, col):
    L = Layer(FW, FH, 4)
    seed = 300 + col * 7
    if col == 6:
        _dead(L, seed)
        return L.finish(outline="#06080b", outline_a=0.9)
    lunge = col == 5
    walking = col in (1, 2, 3, 4)
    phase = (col - 1) / 4 if walking else 0.0
    s = math.sin(phase * math.tau) if walking else 0.0
    c = math.cos(phase * math.tau) if walking else 0.0
    bob = -2.2 * abs(s) if walking else 0.0
    twitch = 1.5 if col == 7 else 0.0
    hip = 72.0 + bob + (4 if lunge else 0)
    sh = 50.0 + bob + (6 if lunge else 0)
    lean = 9.0 if view == "E" else 0.0
    if lunge and view == "E":
        lean = 15.0
    P = dict(RABID)
    # 腿（奔跑时步幅更大，用 crouch=False 的步态）
    _legs(L, P, view, s * 1.25 if not lunge else 0.9, c, hip, False)
    if view == "E":
        back = [(CX + 4 + lean * 0.5, sh + 3), (CX + 10 + s * 4, sh + 15), (CX + 14 + s * 7, sh + 25)]  # 与同侧腿反相
        if lunge:
            back = [(CX + 4 + lean * 0.5, sh + 3), (CX + 18, sh + 2), (CX + 28, sh + 4)]
        _skin_limb(L, back, 6.5, seed + 1, 0.72)
        _claw(L, back[-1][0], back[-1][1], 1, 0.72)
        _torso(L, view, sh, hip, lean, seed)
        hx, hy = CX + 8 + lean, sh - 4 + twitch
        _head(L, view, hx, hy, lunge or col == 7, seed + 2)
        front = [(CX + 6 + lean * 0.5, sh + 4), (CX + 14 - s * 4, sh + 16), (CX + 19 - s * 7, sh + 27)]
        if lunge:
            front = [(CX + 6 + lean * 0.5, sh + 4), (CX + 20, sh + 6), (CX + 31, sh + 9)]
        _skin_limb(L, front, 7, seed + 3)
        _claw(L, front[-1][0], front[-1][1], 1)
    else:
        sw = s * 3.5 * (1 if view == "S" else -1)
        for side, k in ((-1, 1), (1, -1)):
            pts = [(CX + side * 13, sh + 4), (CX + side * 17, sh + 18 + k * sw), (CX + side * 14, sh + 33 + k * sw)]
            if lunge:
                pts = [(CX + side * 13, sh + 3), (CX + side * 20, sh - 4), (CX + side * 17, sh - 14)]
            if view == "N":
                _skin_limb(L, pts, 7, seed + 5 + side, 0.9)
                _claw(L, pts[-1][0], pts[-1][1], side, 0.9)
        _torso(L, view, sh, hip, 0, seed)
        hx, hy = CX + (1.5 if col == 7 else 0), sh - 2 + twitch
        _head(L, view, hx, hy, lunge or col == 7, seed + 2)
        if view == "S":
            for side, k in ((-1, 1), (1, -1)):
                pts = [(CX + side * 13, sh + 4), (CX + side * 17, sh + 18 + k * sw),
                       (CX + side * 14, sh + 33 + k * sw)]
                if lunge:
                    pts = [(CX + side * 13, sh + 3), (CX + side * 20, sh - 4), (CX + side * 17, sh - 14)]
                _skin_limb(L, pts, 7, seed + 5 + side)
                _claw(L, pts[-1][0], pts[-1][1], side)
    return L.finish(outline="#06080b", outline_a=0.9)


def sheet() -> Image.Image:
    img = Image.new("RGBA", (FW * 8, FH * 3), (0, 0, 0, 0))
    for row, view in enumerate(("S", "E", "N")):
        for col in range(8):
            img.alpha_composite(frame(view, col), (col * FW, row * FH))
    return img


def blood_splat(n=96, seed=0):
    from artlib import to_img, vnoise
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot((xs - n / 2) / (n / 2), (ys - n / 2) / (n * 0.31))
    nz = vnoise(n, n, 10, 7, seed) * 0.6 + vnoise(n, n, 4, 3, seed + 1) * 0.4
    a = smooth(0.95, 0.6, r + (nz - 0.5) * 0.7)
    drops = (vnoise(n, n, 3, 2, seed + 2) > 0.8) * smooth(1.4, 0.9, r)
    a = np.clip(a + drops * 0.8, 0, 1) * 0.85
    rgb = np.broadcast_to(hexc("#4a1416"), (n, n, 3)).copy() * (0.8 + 0.4 * nz)[..., None]
    return to_img(rgb, a)
