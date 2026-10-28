"""角色精灵表（CHR_01 阿列克谢 / CHR_05 内务清杀兵 ОСК）。

精灵表布局：8 列 × 3 行，每帧 72×112，pivot = (36, 108) 脚底中心。
  行：0=S（面向镜头）1=E（朝右，W 由引擎 flip_h）2=N（背对）
  列：0 待机 · 1-4 行走循环 · 5 蹲伏待机 · 6-7 蹲伏移动
"""
from __future__ import annotations

import math
import numpy as np
from PIL import Image

from artlib import Layer, hexc, smooth

FW, FH = 72, 112
GY_ = 108
CX = 36

ALEKSEI = dict(
    kind="aleksei",
    trousers="#3b4250", trousers_dk="#2a2f3a", boots="#2b2622", boot_shaft="#4a4640",
    coat="#4b5246", coat_dk="#343a31", quilt="#2c3129", hat="#5a4a3c", hat_lt="#7a6650",
    skin="#c4ae9a", scarf="#7a4a3a", mitt="#3a3430", pack="#5d5440", pack_dk="#3f392c",
)
OSK = dict(
    kind="osk",
    trousers="#596168", trousers_dk="#40474e", boots="#1b1e21", boot_shaft="#24282c",
    coat="#5d656c", coat_dk="#454c53", quilt=None, hat="#565e65", hat_lt="#6f7880",
    skin="#7b8478", scarf=None, mitt="#1d2023", pack="#3f4637", pack_dk="#2d3328",
)


def _limb(L, pts, w, col, dk=None):
    m = L.line(pts, w)
    L.paint(m, hexc(col))
    L.shade(m, L.gx(min(p[0] for p in pts) - w / 2, max(p[0] for p in pts) + w / 2, 1.12, 0.78))
    if dk:
        L.rim(m, 1.2, 0, dk, 0.5)
    return m


def _pose(view, phase, crouch, walking):
    s = math.sin(phase * math.tau) if walking else 0.0
    c = math.cos(phase * math.tau) if walking else 0.0
    bob = -1.6 * abs(s) if walking else 0.0
    if crouch:
        hip, sh, head = 82.0, 58.0, 45.0
        bob *= 0.5
    else:
        hip, sh, head = 68.0, 40.0, 25.0
    return s, c, hip + bob, sh + bob, head + bob


def _legs(L, P, view, s, c, hip, crouch):
    legs = []
    if view in ("S", "N"):
        for side, lift in ((-1, max(0.0, s) * 5), (1, max(0.0, -s) * 5)):
            hx = CX + side * 6
            if crouch:
                knee = (CX + side * 12, hip + 9 - lift * 0.4)
                foot = (CX + side * 8, GY_ - 2 - lift * 0.5)
            else:
                knee = (hx + side * 1.0, (hip + GY_) / 2 - lift * 0.6)
                foot = (hx, GY_ - 3 - lift)
            legs.append(((hx, hip), knee, foot, 0))
    else:
        for k, sg in enumerate((1, -1)):
            if crouch:
                if k == 0:
                    knee, foot = (CX + 9 + s * 2, hip + 3), (CX + 5 + s * 3, GY_ - 2)
                else:
                    knee, foot = (CX + 1 - s * 2, hip + 13), (CX - 7 - s * 3, GY_ - 2)
                hx = CX - 3
            else:
                hx = CX - 1
                fx = hx + sg * s * 11
                lift = max(0.0, sg * c) * 4
                foot = (fx, GY_ - 3 - lift)
                knee = ((hx + fx) / 2 + 3, (hip + GY_) / 2 - lift * 0.5)
            legs.append(((hx, hip), knee, foot, k))
    order = legs if view != "E" else [legs[1], legs[0]]
    for hipp, knee, foot, k in order:
        dim = 0.8 if (view == "E" and k == 1) else 1.0
        m = _limb(L, [hipp, knee, (foot[0], foot[1] - 4)], 10.5, P["trousers"], P["trousers_dk"])
        L.shade(m, dim)
        bx = foot[0] + (3 if view == "E" else 0)
        L.paint(L.rect(foot[0] - 5, foot[1] - 10, foot[0] + 5, foot[1] - 1, 2), hexc(P["boot_shaft"]) * dim)
        L.paint(L.ellipse(bx, foot[1], 6.5 if view == "E" else 5.5, 3.8), hexc(P["boots"]) * dim)
        L.paint(L.ellipse(bx, foot[1] - 0.5, 4, 1.6), hexc("#d9e3ec"), 0.35)  # 鞋面上的雪


def _torso(L, P, view, hip, sh, crouch):
    lean = 7.0 if (crouch and view == "E") else 0.0
    if view == "E":
        pts = [(CX - 8 + lean, sh), (CX + 8 + lean, sh + 1), (CX + 10, hip + 6), (CX - 10, hip + 6)]
    else:
        pts = [(CX - 13, sh + 1), (CX + 13, sh + 1), (CX + 14, hip + 7), (CX - 14, hip + 7)]
    m = L.poly(pts)
    L.paint(m, L.tex(P["coat"], 0.07, 2.5, 7))
    L.shade(m, L.gx(CX - 14, CX + 14, 1.15, 0.75))
    L.shade(m, L.gy(sh, hip + 7, 1.05, 0.85))
    if P["quilt"]:
        for y in np.arange(sh + 5, hip + 6, 5.5):
            L.paint(L.rect(CX - 15, y, CX + 15, y + 0.9) * m, hexc(P["quilt"]), 0.8)
        if view == "S":
            L.paint(L.rect(CX - 0.6, sh + 4, CX + 0.6, hip + 7) * m, hexc(P["quilt"]))
    else:
        # 橡胶防护服：高光 + 腰带 + 胸挂
        L.rim(m, -1.5, 0, "#9aa3ab", 0.55)
        L.paint(L.rect(CX - 15, hip - 2, CX + 15, hip + 1.6) * m, hexc("#24282c"))
        if view == "S":
            for px in (-7, 0, 7):
                L.paint(L.rect(CX + px - 3, sh + 12, CX + px + 3, sh + 20, 1), hexc("#3f4637"))
        if view == "E":
            L.paint(L.rect(CX + 1 + lean * 0.6, sh + 12, CX + 9 + lean * 0.6, sh + 21, 1), hexc("#3f4637"))
    L.rim(m, 0, -1.2, "#0b0f14", 0.3)
    return lean


def _pack(L, P, view, sh, hip, lean):
    if view == "N":
        m = L.rect(CX - 10, sh + 4, CX + 10, hip - 2, 4)
    elif view == "E":
        m = L.rect(CX - 16 + lean * 0.5, sh + 3, CX - 6 + lean * 0.5, hip - 4, 4)
    else:
        return
    L.paint(m, L.tex(P["pack"], 0.08, 2, 21))
    L.shade(m, L.gy(sh, hip, 1.1, 0.8))
    if view == "N":
        L.paint(L.rect(CX - 10, sh + 10, CX + 10, sh + 12) * m, hexc(P["pack_dk"]))
        for x in (CX - 8, CX + 6):
            L.paint(L.rect(x, sh - 1, x + 2, sh + 6), hexc(P["pack_dk"]))
    L.paint(L.rect(CX - 16, sh + 3, CX + 16, sh + 7) * m, hexc("#e3eaf1"), 0.35)


def _arm(L, P, pts, dim=1.0):
    m = _limb(L, pts, 8.5, P["coat"], P["coat_dk"])
    L.shade(m, dim)
    hx, hy = pts[-1]
    L.paint(L.ellipse(hx, hy + 1, 4.2, 4.2), hexc(P["mitt"]) * dim)
    return m


def _head(L, P, view, head, lean):
    hx = CX + (lean * 1.4 if view == "E" else 0)
    if P["kind"] == "aleksei":
        if view == "S":
            L.paint(L.ellipse(hx, head + 2, 6.8, 7.8), hexc(P["skin"]))
            L.shade(L.ellipse(hx, head + 2, 6.8, 7.8), L.gx(hx - 7, hx + 7, 1.1, 0.8))
            for ex in (-3, 3):
                L.paint(L.arc(hx + ex, head + 1.5, 2.6, 2.6, 0, 360, 0.9), hexc("#b8c2cc"))
                L.paint(L.ellipse(hx + ex, head + 1.5, 0.9, 0.9), hexc("#1a1e22"))
            L.paint(L.line([(hx - 4.5, head), (hx - 2, head + 3)], 0.5, False), hexc("#eef4f8"))  # 裂镜
            L.paint(L.rect(hx - 1, head + 4, hx + 1, head + 5.5), hexc("#9a8472"))
            L.paint(L.rect(hx - 2.5, head + 7, hx + 2.5, head + 7.8), hexc("#6b5546"))
        elif view == "E":
            L.paint(L.ellipse(hx + 2, head + 2, 6.5, 7.6), hexc(P["skin"]))
            L.paint(L.ellipse(hx + 8, head + 3.5, 1.6, 2.2), hexc(P["skin"]))
            L.paint(L.arc(hx + 5.5, head + 1.5, 2.4, 2.4, 0, 360, 0.9), hexc("#b8c2cc"))
            L.paint(L.line([(hx + 3, head + 1), (hx - 2, head + 1)], 0.7, False), hexc("#b8c2cc"))
        # 护耳毛帽（ушанка）
        dome = L.ellipse(hx + (1 if view == "E" else 0), head - 5.5, 10.5, 6.8) if view != "N" else             L.ellipse(hx, head - 2, 10.5, 9.5)
        L.paint(dome, L.tex(P["hat"], 0.18, 1.2, 31))
        L.shade(dome, L.gx(hx - 10, hx + 10, 1.15, 0.75))
        if view != "N":
            L.paint(L.rect(hx - 10.5, head - 7, hx + 10.5, head - 3, 2), L.tex(P["hat_lt"], 0.2, 1, 32))
        if view == "E":
            L.paint(L.rect(hx - 5, head - 2, hx + 1, head + 9, 2), L.tex(P["hat"], 0.18, 1, 33))
        else:
            for sx in (-1, 1):
                L.paint(L.rect(hx + sx * 10.5 - 3, head - 2, hx + sx * 10.5 + 3, head + 9, 2),
                        L.tex(P["hat"], 0.18, 1, 34))
        L.snow_cap(hx - 8, hx + 8, head - 11, 4, 35, droop=0.1)
        # 围巾
        sc = L.rect(hx - 7.5, head + 8.5, hx + 7.5, head + 13.5, 2)
        L.paint(sc, L.tex(P["scarf"], 0.1, 1.5, 36))
        if view == "S":
            L.paint(L.rect(hx + 3, head + 12, hx + 7, head + 24, 1.5), L.tex(P["scarf"], 0.1, 1.5, 37) * 0.85)
        else:
            L.paint(L.rect(hx - 8, head + 12, hx - 4, head + 22, 1.5), L.tex(P["scarf"], 0.1, 1.5, 38) * 0.85)
    else:
        hood = L.ellipse(hx, head, 9.5, 10)
        L.paint(hood, L.tex(P["hat"], 0.06, 2, 41))
        L.shade(hood, L.gx(hx - 10, hx + 10, 1.2, 0.7))
        L.rim(hood, -1.4, -1, "#a3acb4", 0.5)
        if view == "S":
            L.paint(L.ellipse(hx, head + 1.5, 7, 8), hexc(P["skin"]))
            for ex in (-3.3, 3.3):
                L.paint(L.ellipse(hx + ex, head - 0.5, 2.8, 2.8), hexc("#3a4038"))
                L.paint(L.ellipse(hx + ex, head - 0.5, 2.0, 2.0), hexc("#162026"))
                L.paint(L.ellipse(hx + ex - 0.6, head - 1.1, 0.8, 0.8), hexc("#7dd3fc"))
            L.paint(L.rect(hx - 2.6, head + 5, hx + 2.6, head + 12, 1.2), hexc("#3f4637"))
            L.paint(L.ellipse(hx, head + 12, 3, 1.4), hexc("#2a2f26"))
            L.paint(L.line([(hx + 2, head + 11), (hx + 7, head + 18), (hx + 6, head + 24)], 1.8, False),
                    hexc("#2a2e2a"))
        elif view == "E":
            L.paint(L.ellipse(hx + 3, head + 1.5, 6, 7.5), hexc(P["skin"]))
            L.paint(L.ellipse(hx + 5, head - 0.5, 2.6, 2.8), hexc("#162026"))
            L.paint(L.ellipse(hx + 4.4, head - 1.1, 0.8, 0.8), hexc("#7dd3fc"))
            L.paint(L.rect(hx + 6, head + 4, hx + 12, head + 9, 1.4), hexc("#3f4637"))
            L.paint(L.line([(hx + 9, head + 9), (hx + 6, head + 16), (hx + 1, head + 20)], 1.8, False),
                    hexc("#2a2e2a"))
        else:
            for yy in (head - 3, head + 2):
                L.paint(L.rect(hx - 8, yy, hx + 8, yy + 1.4) * hood, hexc("#2a2e33"))
        L.snow_cap(hx - 6, hx + 6, head - 8.5, 3, 42, droop=0.1)


def _rifle(L, view, sh, lean):
    gun, wood = hexc("#2a2d31"), hexc("#6a4428")
    if view == "S":
        a, b = (CX + 13, sh + 27), (CX - 9, sh + 10)
        L.paint(L.line([a, b], 3.6), gun)
        L.paint(L.line([(CX + 6, sh + 22), (CX - 1, sh + 16)], 4.4), wood)
        L.paint(L.line([(CX + 2, sh + 20), (CX + 3, sh + 29), (CX + 6, sh + 31)], 3.2, False), gun)
        L.paint(L.ellipse(b[0], b[1], 2.6, 2.6), hexc("#fff4d6"))
        L.paint(L.ellipse(CX + 11, sh + 25, 3.6, 3.6), hexc("#1d2023"))
        L.paint(L.ellipse(CX - 3, sh + 15, 3.6, 3.6), hexc("#1d2023"))
    elif view == "E":
        x0 = CX - 6 + lean
        L.paint(L.line([(x0 - 2, sh + 13), (x0 + 6, sh + 15)], 5), wood)
        L.paint(L.line([(x0 + 4, sh + 15), (x0 + 30, sh + 19)], 3.4), gun)
        L.paint(L.line([(x0 + 13, sh + 16), (x0 + 21, sh + 17.5)], 4.4), wood)
        L.paint(L.line([(x0 + 11, sh + 17), (x0 + 12, sh + 25), (x0 + 15, sh + 28)], 3.2, False), gun)
        L.paint(L.ellipse(x0 + 30, sh + 19, 2.4, 2.4), hexc("#fff4d6"))
        L.paint(L.ellipse(x0 + 7, sh + 18, 3.6, 3.6), hexc("#1d2023"))
        L.paint(L.ellipse(x0 + 19, sh + 20, 3.6, 3.6), hexc("#1d2023"))
    else:
        L.paint(L.line([(CX - 12, sh + 2), (CX + 12, sh + 28)], 2), hexc("#2d3328"))
        L.paint(L.line([(CX + 9, sh - 8), (CX + 14, sh + 26)], 3.4), gun)
        L.paint(L.line([(CX + 13, sh + 16), (CX + 15, sh + 30)], 5), wood)


def frame(P, view, phase, crouch, walking):
    L = Layer(FW, FH, 4)
    s, c, hip, sh, head = _pose(view, phase, crouch, walking)
    osk = P["kind"] == "osk"
    sw = s * 3.2
    if view == "E":
        lean = 7.0 if crouch else 0.0
        if not osk:
            _arm(L, P, [(CX - 1 + lean * 0.6, sh + 4), (CX - 3 - s * 5, sh + 15), (CX - 3 - s * 9, sh + 26)], 0.75)
        _legs(L, P, view, s, c, hip, crouch)
        if not osk:
            _pack(L, P, view, sh, hip, lean)
        _torso(L, P, view, hip, sh, crouch)
        _head(L, P, view, head, lean)
        if osk:
            _arm(L, P, [(CX + lean * 0.6, sh + 4), (CX + 2 + lean, sh + 14), (CX + 1 + lean, sh + 18)])
            _rifle(L, view, sh, lean)
        else:
            _arm(L, P, [(CX + 1 + lean * 0.6, sh + 4), (CX + 2 + s * 5 + lean * 0.5, sh + 15),
                        (CX + 3 + s * 9 + lean * 0.8, sh + 26)])
    else:
        _legs(L, P, view, s, c, hip, crouch)
        _torso(L, P, view, hip, sh, crouch)
        if view == "N" and not osk:
            _pack(L, P, view, sh, hip, 0)
        if osk and view == "S":
            _arm(L, P, [(CX - 13, sh + 4), (CX - 13, sh + 14), (CX - 3, sh + 15)])
            _arm(L, P, [(CX + 13, sh + 4), (CX + 15, sh + 18), (CX + 11, sh + 25)])
            L.paint(L.rect(CX - 17, sh + 5, CX - 10, sh + 9, 1), hexc("#8a3a32"))  # 臂章
            _head(L, P, view, head, 0)
            _rifle(L, view, sh, 0)
        else:
            _arm(L, P, [(CX - 13, sh + 4), (CX - 16, sh + 15 + sw), (CX - 15, sh + 27 + sw)])
            _arm(L, P, [(CX + 13, sh + 4), (CX + 16, sh + 15 - sw), (CX + 15, sh + 27 - sw)])
            if osk:
                L.paint(L.rect(CX + 10, sh + 5, CX + 17, sh + 9, 1), hexc("#8a3a32"))
                _rifle(L, view, sh, 0)
            _head(L, P, view, head, 0)
    return L.finish(outline="#06080b", outline_a=0.9)


def sheet(P) -> Image.Image:
    img = Image.new("RGBA", (FW * 8, FH * 3), (0, 0, 0, 0))
    for row, view in enumerate(("S", "E", "N")):
        cells = [(0.0, False, False)] + [(k / 4, False, True) for k in range(4)] + \
                [(0.0, True, False), (0.25, True, True), (0.75, True, True)]
        for col, (ph, cr, wk) in enumerate(cells):
            img.alpha_composite(frame(P, view, ph, cr, wk), (col * FW, row * FH))
    return img
