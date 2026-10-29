"""道具精灵（PRP_*）。每个函数返回 (Image, pivot)，pivot = 精灵内的落地点（像素）。

尺寸遵循 1m = 64px（立面不压缩）/ 地面深度 1m = 39.68px。
"""
from __future__ import annotations

import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

from artlib import GY, PPM, Layer, hexc, lerp, obox, smooth, tile_noise, vnoise

FONT_BOLD = "C:/Windows/Fonts/arialbd.ttf"


def _m(v):  # 米 → 水平像素
    return v * PPM


def _d(v):  # 米 → 地面深度像素
    return v * GY


# ---------------------------------------------------------------------------
def _crate(L, x, base, w, d, h, seed, snow=True, wood="#7a6446"):
    top, front = obox(L, x, base, w, d, h, wood, wood, seed)
    L.shade(front, 0.88)
    for k in range(1, 4):
        y = base - h + h * k / 4
        L.paint(L.rect(x + 1, y - 0.7, x + w - 1, y + 0.7), hexc("#2e2418"), 0.9)
    for k in range(1, 3):
        y = base - h - d + d * k / 3
        L.paint(L.rect(x + 1, y - 0.6, x + w - 1, y + 0.6), hexc("#3a2e20"), 0.8)
    for xx in (x, x + w - 6):
        L.paint(L.rect(xx, base - h, xx + 6, base), L.tex("#8a7350", 0.1, 3, seed + 3))
    L.paint(L.line([(x + 6, base - 3), (x + w - 6, base - h + 3)], 4), hexc("#86704d"))
    for (nx, ny) in [(x + 3, base - h + 4), (x + w - 3, base - h + 4), (x + 3, base - 4), (x + w - 3, base - 4)]:
        L.paint(L.ellipse(nx, ny, 1.2, 1.2), hexc("#5a3a22"))
    L.grime(front, seed + 4, 0.25, 4)
    L.paint(front * smooth(base - 10, base, L.Y), hexc("#dfe8f0"), 0.35)
    if snow:
        L.snow_cap(x - 1, x + w + 1, base - h + 2, (d + 4) / 0.8, seed + 5, droop=0.3)


def crate_stack():
    w, h = 132, 156
    L = Layer(w, h, 3)
    base = 148
    cw, cd, ch = 51, 32, 51
    _crate(L, 12, base, cw, cd, ch, 11, snow=False)
    _crate(L, 66, base - 4, cw, cd, ch, 12, snow=True)
    _crate(L, 30, base - ch - 14, cw, cd, ch, 13, snow=True)
    L.snow_cap(4, 128, base - 2, 10, 14, droop=0.0)
    return L.finish(), (w / 2, base)


def supply_crates():
    w, h = 150, 116
    L = Layer(w, h, 3)
    base = 108
    for (x, b, s) in [(8, base, 21), (76, base - 3, 22), (40, base - 29 - 12, 23)]:
        top, front = obox(L, x, b, 64, 24, 29, "#55603f", "#4c5638", s)
        L.paint(L.rect(x + 3, b - 29, x + 5, b), hexc("#2e3424"))
        L.paint(L.rect(x + 59, b - 29, x + 61, b), hexc("#2e3424"))
        L.paint(L.rect(x + 18, b - 20, x + 46, b - 17), hexc("#c9ccc0"), 0.7)
        L.paint(L.rect(x + 18, b - 13, x + 34, b - 10.5), hexc("#c9ccc0"), 0.6)
        L.paint(L.arc(x + 32, b - 6, 6, 3, 0, 180, 1.6), hexc("#8c7a55"))
        L.grime(front, s + 1, 0.25)
        L.snow_cap(x - 1, x + 65, b - 29 + 2, 32, s + 2, droop=0.3)
    return L.finish(), (w / 2, base)


def dumpster():
    w, h = 156, 156
    L = Layer(w, h, 3)
    base, x0, bw, d, bh = 146, 17, 122, 44, 77
    body = L.poly([(x0 + 4, base - 6), (x0 + bw - 4, base - 6), (x0 + bw + 3, base - bh), (x0 - 3, base - bh)])
    L.paint(body, L.tex("#55645a", 0.08, 5, 31))
    L.shade(body, L.gy(base - bh, base, 1.05, 0.78))
    for k in range(1, 6):
        xx = x0 + bw * k / 6
        L.paint(L.rect(xx - 1.5, base - bh + 3, xx + 1.5, base - 8), hexc("#3d4a41"))
        L.paint(L.rect(xx - 2.5, base - bh + 3, xx - 1.5, base - 8), hexc("#7a8a7e"), 0.5)
    L.rust_streaks(body, 32, 0.35)
    L.grime(body, 33, 0.3)
    L.paint(L.rect(x0 - 6, base - bh + 18, x0 + 4, base - bh + 30), hexc("#3d4a41"))
    L.paint(L.rect(x0 + bw - 4, base - bh + 18, x0 + bw + 6, base - bh + 30), hexc("#3d4a41"))
    for wx in (x0 + 14, x0 + bw - 14):
        L.paint(L.ellipse(wx, base - 5, 7, 5), hexc("#1b1e21"))
    # 盖子（半开）+ 垃圾袋
    lid = L.poly([(x0 - 4, base - bh), (x0 + bw + 4, base - bh), (x0 + bw + 1, base - bh - d - 6),
                  (x0 - 1, base - bh - d + 2)])
    L.paint(lid, L.tex("#3a453f", 0.08, 4, 34))
    L.paint(L.ellipse(x0 + bw * 0.72, base - bh - 10, 18, 11), hexc("#1d2126"))
    L.paint(L.ellipse(x0 + bw * 0.69, base - bh - 13, 7, 4), hexc("#4c5660"), 0.6)
    L.snow_cap(x0 - 4, x0 + bw * 0.55, base - bh + 2, 46, 35, droop=0.3)
    L.snow_cap(x0 + bw * 0.85, x0 + bw + 4, base - bh + 2, 40, 36, droop=0.2)
    L.icicles(x0, x0 + bw, base - bh + 4, 10, 10, 37, 1.6)
    L.snow_cap(x0 - 8, x0 + bw + 8, base - 1, 10, 38, droop=0.0)
    return L.finish(), (w / 2, base)


def electric_cabinet():
    w, h = 84, 146
    L = Layer(w, h, 3)
    base = 138
    top, front = obox(L, 13, base, 58, 16, 102, "#6f757c", "#666c73", 41)
    L.paint(L.rect(41.5, base - 100, 42.5, base - 2), hexc("#2a2e33"))
    for yy in range(int(base - 92), int(base - 70), 4):
        L.paint(L.rect(19, yy, 37, yy + 1.6), hexc("#2a2e33"))
        L.paint(L.rect(47, yy, 65, yy + 1.6), hexc("#2a2e33"))
    tri = L.poly([(42 - 9, base - 50), (42 + 9, base - 50), (42, base - 64)])
    L.paint(tri, hexc("#c4a43c"))
    L.paint(L.line([(43, base - 61), (40, base - 56), (44, base - 56), (41, base - 52)], 1.4), hexc("#1a1a1a"))
    L.paint(L.rect(37, base - 40, 47, base - 34), hexc("#3a3f45"))
    L.paint(L.arc(42, base - 42, 3, 3, 180, 360, 1.4), hexc("#9aa1a8"))
    L.rust_streaks(front, 42, 0.6)
    L.grime(front, 43, 0.25)
    L.snow_cap(11, 73, base - 102 + 2, 24, 44, droop=0.3)
    L.icicles(14, 70, base - 101, 10, 6, 45, 1.4)
    L.snow_cap(6, 78, base - 1, 9, 46, droop=0.0)
    return L.finish(), (w / 2, base)


def car_wreck():
    w, h = 316, 196
    L = Layer(w, h, 3)
    base = 186
    x0, x1 = 17, 299            # 车身长 282px
    belt, roof = base - 52, base - 93
    D = 67
    paint = "#6e818f"
    # ---- 顶面（引擎盖 / 后备箱），被压缩的深度 D ----
    topf = L.poly([(x0 + 6, belt), (x1 - 4, belt), (x1 - 8, belt - D + 6), (x0 + 10, belt - D + 6)])
    L.paint(topf, L.tex(paint, 0.08, 6, 51))
    L.shade(topf, 1.08)
    # ---- 座舱：挡风玻璃 + 车顶 ----
    ws = L.poly([(x0 + 82, belt - 4), (x0 + 100, roof), (x0 + 100, roof - D + 12), (x0 + 82, belt - D + 4)])
    L.paint(ws, lerp(hexc("#2b3540"), hexc("#55687a"), L.gy(roof - D, belt, 0, 1)))
    rw = L.poly([(x0 + 196, belt - 4), (x0 + 182, roof), (x0 + 182, roof - D + 12), (x0 + 196, belt - D + 4)])
    L.paint(rw, lerp(hexc("#2b3540"), hexc("#55687a"), L.gy(roof - D, belt, 0, 1)))
    rooft = L.rect(x0 + 100, roof - D + 12, x0 + 182, roof)
    L.paint(rooft, L.tex(paint, 0.07, 6, 52))
    side_c = L.poly([(x0 + 84, belt), (x0 + 102, roof), (x0 + 180, roof), (x0 + 196, belt)])
    L.paint(side_c, L.tex(paint, 0.08, 6, 53))
    # 侧窗：一扇碎了
    win1 = L.poly([(x0 + 92, belt - 3), (x0 + 106, roof + 4), (x0 + 138, roof + 4), (x0 + 138, belt - 3)])
    win2 = L.poly([(x0 + 143, belt - 3), (x0 + 143, roof + 4), (x0 + 176, roof + 4), (x0 + 188, belt - 3)])
    L.paint(win1, lerp(hexc("#3a4856"), hexc("#1c242d"), L.gy(roof, belt, 0, 1)))
    L.paint(win2, hexc("#0f1317"))
    shard = L.poly([(x0 + 143, roof + 4), (x0 + 160, roof + 4), (x0 + 150, roof + 16), (x0 + 156, roof + 22),
                    (x0 + 143, roof + 30)])
    L.paint(shard, hexc("#4a5a68"), 0.8)
    frost = (win1 + win2) * smooth(0.45, 0.8, L.noise(2, 54))
    L.paint(np.clip(frost, 0, 1), hexc("#dfe9f1"), 0.75)
    # ---- 车身侧面 ----
    body = L.poly([(x0, belt + 4), (x0 + 6, belt), (x1 - 4, belt), (x1, belt + 6), (x1, base - 20),
                   (x1 - 8, base - 12), (x0 + 6, base - 12), (x0, base - 20)])
    L.paint(body, L.tex(paint, 0.08, 6, 55))
    L.shade(body, L.gy(belt, base - 12, 1.06, 0.72))
    L.paint(L.rect(x0 + 2, belt + 10, x1 - 2, belt + 12.5), hexc("#a7b0b6"), 0.7)
    for xx in (x0 + 100, x0 + 140, x0 + 192):
        L.paint(L.rect(xx, belt, xx + 1.2, base - 16), hexc("#2f383f"))
    for xx in (x0 + 120, x0 + 170):
        L.paint(L.rect(xx, belt + 16, xx + 9, belt + 19), hexc("#b5bcc1"))
    # 锈蚀 + 轮拱
    rust = body * smooth(belt + 20, base - 12, L.Y) * smooth(0.45, 0.7, L.noise(4, 56))
    L.tint(rust, hexc("#6a4a2a"), 0.85)
    for wx in (x0 + 52, x0 + 232):
        L.paint(L.ellipse(wx, base - 18, 23, 20), hexc("#191c1f"))
        L.paint(L.ellipse(wx, base - 14, 16, 12), hexc("#26292c"))
        L.paint(L.ellipse(wx, base - 14, 7, 6), hexc("#4e555b"))
    # 后视镜 + 车灯
    L.paint(L.rect(x0 + 74, belt - 8, x0 + 82, belt - 2), hexc("#3a444c"))
    L.paint(L.ellipse(x1 - 4, belt + 18, 3, 5), hexc("#c8c2a8"), 0.8)
    L.paint(L.rect(x0, belt + 14, x0 + 4, belt + 22), hexc("#6b2a22"), 0.8)
    # ---- 厚雪 ----
    L.snow_cap(x0 + 96, x0 + 186, roof + 2, (D - 14) / 0.8, 57, droop=0.35)
    L.snow_cap(x0 + 4, x0 + 86, belt + 2, (D - 12) / 0.8, 58, droop=0.3)
    L.snow_cap(x0 + 192, x1 - 2, belt + 2, (D - 12) / 0.8, 59, droop=0.3)
    L.icicles(x0 + 10, x1 - 10, belt + 3, 7, 12, 60, 1.4)
    L.snow_cap(x0 - 10, x1 + 10, base - 4, 22, 61, droop=0.0)
    return L.finish(), (w / 2, base)


def steam_pipe():
    length = int(_m(18.0))
    w, h = length + 28, 128
    L = Layer(w, h, 2)
    base = 120
    x0 = 14
    cy = base - 11 - 44
    r = 17
    # 支墩
    for k in range(0, 7):
        sx = x0 + 24 + k * (length - 48) / 6
        sup = L.rect(sx - 9, cy + 6, sx + 9, base - 4)
        L.paint(sup, L.tex("#7c7f80", 0.08, 4, 70 + k))
        L.shade(sup, L.gx(sx - 9, sx + 9, 1.1, 0.75))
        L.paint(L.rect(sx - 13, cy + 2, sx + 13, cy + 8), hexc("#464b50"))
        L.snow_cap(sx - 14, sx + 14, base - 4, 10, 80 + k, droop=0.0)
    # 管体（铝皮保温层）
    pipe = L.rect(x0, cy - r, x0 + length, cy + r, 6)
    tex = L.tex("#8c9399", 0.06, 8, 71)
    L.paint(pipe, tex)
    prof = 1.15 - 0.55 * np.clip((L.Y - (cy - r)) / (2 * r), 0, 1) ** 1.3
    L.shade(pipe, np.clip(prof, 0.4, 1.3))
    L.paint(pipe * smooth(cy - r + 5, cy - r + 1, L.Y), hexc("#c7cdd2"), 0.5)
    for k in range(int(length / 58) + 1):
        xx = x0 + k * 58
        L.paint(L.rect(xx, cy - r, xx + 1.4, cy + r) * pipe, hexc("#4a5056"), 0.9)
        L.paint(L.rect(xx + 1.4, cy - r, xx + 3, cy + r) * pipe, hexc("#b7bec4"), 0.4)
    for k in range(7):
        xx = x0 + 24 + k * (length - 48) / 6
        L.paint(L.rect(xx - 4, cy - r - 1, xx + 4, cy + r + 1), hexc("#3d4247"))
    # 破损处露出保温棉 + 锈
    rr = np.random.default_rng(72)
    for _ in range(6):
        xx = rr.uniform(x0 + 30, x0 + length - 60)
        wd = rr.uniform(16, 34)
        hole = L.ellipse(xx, cy + rr.uniform(-4, 6), wd / 2, rr.uniform(5, 9)) * pipe
        L.paint(hole, L.tex("#a89058", 0.15, 2, int(xx)))
        L.tint(hole * smooth(0.4, 0.7, L.noise(1.5, int(xx) + 1)), hexc("#6a4a2a"), 0.7)
    L.rust_streaks(pipe, 73, 0.35, cell=(2.5, 6))
    # 蒸汽阀（世界 x=14m → 管内 5m）
    vx = x0 + _m(5.0)
    L.paint(L.rect(vx - 7, cy - r - 24, vx + 7, cy - r + 2), L.tex("#6b7075", 0.08, 3, 74))
    L.paint(L.ellipse(vx, cy - r - 28, 13, 5), hexc("#6a3a28"))
    L.paint(L.arc(vx, cy - r - 28, 13, 5, 0, 360, 2.6), hexc("#8a4e34"))
    L.paint(L.line([(vx - 13, cy - r - 28), (vx + 13, cy - r - 28)], 2), hexc("#6a3a28"))
    L.paint(L.ellipse(vx, cy - r - 8, 12, 9), hexc("#cfe0ec"), 0.75)
    # 顶部积雪 + 冰锥
    L.snow_cap(x0 - 2, x0 + length + 2, cy - r + 5, 16, 75, droop=0.3)
    L.icicles(x0 + 10, x0 + length - 10, cy + r - 2, 12, 34, 76, 1.8)
    return L.finish(), (w / 2, base)


def brazier():
    w, h = 68, 92
    L = Layer(w, h, 4)
    base, cx, rr = 86, 34, 19
    hgt = 54
    body = L.rect(cx - rr, base - hgt, cx + rr, base - 4)
    body = np.clip(body + L.ellipse(cx, base - 5, rr, 5), 0, 1)
    L.paint(body, L.tex("#33373c", 0.12, 3, 91))
    L.shade(body, np.clip(1.25 - 0.9 * np.abs(L.X - cx + 5) / rr, 0.35, 1.3))
    L.tint(body * smooth(0.5, 0.75, L.noise(2.5, 92)), hexc("#6a4a2a"), 0.8)
    for yy in (base - 40, base - 20):
        L.paint(L.rect(cx - rr, yy, cx + rr, yy + 2.2) * body, hexc("#22252a"))
    rrg = np.random.default_rng(93)
    for _ in range(9):
        hx, hy = cx + rrg.uniform(-rr + 5, rr - 5), base - rrg.uniform(10, 34)
        L.paint(L.ellipse(hx, hy, 2.2, 2.2), hexc("#ffb05a"))
        L.paint(L.ellipse(hx, hy, 1.0, 1.0), hexc("#fff0c8"))
    # 顶口 + 余烬
    L.paint(L.ellipse(cx, base - hgt, rr, 6), hexc("#191512"))
    L.paint(L.ellipse(cx, base - hgt + 1, rr - 4, 4), hexc("#e0702a"))
    L.paint(L.ellipse(cx, base - hgt + 1, rr - 9, 2.5), hexc("#ffd58a"))
    for k in range(5):
        a = -0.9 + k * 0.45
        L.paint(L.line([(cx + math.cos(a) * 6, base - hgt + 2), (cx + math.cos(a) * 22, base - hgt - 14 - k % 2 * 4)], 4),
                hexc("#3a2a1c"))
    L.paint(L.arc(cx, base - hgt, rr, 6, 180, 360, 1.8), hexc("#555a60"))
    # 底部融雪（湿冰）
    L.paint(L.ellipse(cx, base - 2, rr + 10, 6) * (1 - body), hexc("#3d444c"), 0.6)
    return L.finish(), (cx, base)


def flame_sheet(frames=6):
    fw, fh = 56, 84
    sheet = Image.new("RGBA", (fw * frames, fh), (0, 0, 0, 0))
    nz = tile_noise(96, 12, 95)
    nz2 = tile_noise(96, 6, 96)
    for f in range(frames):
        ys, xs = np.mgrid[0:fh, 0:fw].astype(np.float32)
        t = np.clip(1.0 - ys / (fh - 6), 0.0, 1.0)  # 0 顶 → 1 底
        sway = np.sin(ys * 0.11 + f * 1.05) * 3.0 * (1 - t)
        dx = (xs - fw / 2 - sway) / (6 + 13 * t ** 0.7)
        n = nz[(ys.astype(int) + f * 16) % 96, (xs.astype(int) * 2) % 96]
        n2 = nz2[(ys.astype(int) + f * 32) % 96, (xs.astype(int) * 3) % 96]
        dens = np.exp(-dx * dx) * (t ** 0.8) + (n - 0.5) * 0.55 + (n2 - 0.5) * 0.25
        dens *= smooth(fh - 2, fh - 10, ys)
        a = smooth(0.28, 0.55, dens)
        heat = np.clip((dens - 0.3) * 1.6, 0, 1)
        col = np.where(heat[..., None] > 0.6,
                       lerp(hexc("#ffb347"), hexc("#fff4cf"), np.clip((heat - 0.6) / 0.4, 0, 1)),
                       lerp(hexc("#c8401e"), hexc("#ffb347"), np.clip(heat / 0.6, 0, 1)))
        img = np.dstack([col, a])
        sheet.paste(Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGBA"), (f * fw, 0))
    return sheet, (fw / 2, fh - 4)


def street_lamp():
    w, h = 116, 384
    L = Layer(w, h, 3)
    base, px = 376, 24
    top = base - 340
    pole = L.poly([(px - 7, base), (px + 7, base), (px + 4, top), (px - 4, top)])
    L.paint(pole, L.tex("#7f8181", 0.07, 4, 101, cy=20))
    L.shade(pole, L.gx(px - 7, px + 7, 1.2, 0.65))
    L.rust_streaks(pole, 102, 0.4, cell=(1.0, 30))
    for yy in range(top + 30, base - 20, 46):
        L.paint(L.rect(px - 6, yy, px + 6, yy + 1.2), hexc("#4b4e50"), 0.6)
    L.paint(L.rect(px - 11, base - 26, px + 11, base), L.tex("#6d7070", 0.08, 3, 103))
    # 弯臂 + 眼镜蛇灯头
    arm = L.line([(px, top + 6), (px + 10, top - 10), (px + 34, top - 18), (px + 62, top - 14)], 4, False)
    L.paint(arm, hexc("#4e555c"))
    head = L.poly([(px + 50, top - 20), (px + 82, top - 18), (px + 88, top - 10), (px + 52, top - 8)])
    L.paint(head, L.tex("#4a5057", 0.06, 3, 104))
    lens = L.ellipse(px + 70, top - 7, 15, 4)
    L.paint(lens, hexc("#ffcf8a"))
    L.paint(L.ellipse(px + 70, top - 7, 8, 2), hexc("#fff3dc"))
    L.snow_cap(px + 48, px + 88, top - 18, 9, 105, droop=0.2)
    L.snow_cap(px + 4, px + 40, top - 14, 6, 106, droop=0.1)
    L.icicles(px + 54, px + 84, top - 6, 9, 5, 107, 1.4)
    L.snow_cap(px - 16, px + 18, base - 2, 14, 108, droop=0.0)
    return L.finish(), (px, base)


def bench():
    w, h = 134, 92
    L = Layer(w, h, 3)
    base, x0, bw = 84, 10, 115
    for lx in (x0 + 10, x0 + bw - 22):
        L.paint(L.rect(lx, base - 30, lx + 12, base), L.tex("#7a7c7c", 0.08, 3, lx))
        L.paint(L.rect(lx, base - 64, lx + 12, base - 30), L.tex("#6f7171", 0.08, 3, lx + 1))
    # 靠背（在座位后方，屏幕上更高）
    for k in range(3):
        y = base - 62 + k * 9
        L.paint(L.rect(x0, y, x0 + bw, y + 6), L.tex("#6a5238", 0.12, 3, 110 + k, cy=2))
        L.paint(L.rect(x0, y + 5, x0 + bw, y + 6.2), hexc("#2c2218"))
    # 座面（顶面 + 前沿）
    for k in range(3):
        y = base - 46 + k * 5.5
        L.paint(L.rect(x0 - 2, y, x0 + bw + 2, y + 4.6), L.tex("#735a3e", 0.12, 3, 120 + k, cy=2))
    L.paint(L.rect(x0 - 2, base - 30, x0 + bw + 2, base - 26), hexc("#4d3b28"))
    L.snow_cap(x0 - 2, x0 + bw + 2, base - 30, 20, 125, droop=0.3)
    L.snow_cap(x0 - 1, x0 + bw + 1, base - 60, 8, 126, droop=0.2)
    L.snow_cap(x0 - 8, x0 + bw + 8, base - 1, 12, 127, droop=0.0)
    return L.finish(), (w / 2, base)


def playground_dome():
    R = _m(1.4)
    w, h = int(2 * R + 30), 180
    L = Layer(w, h, 3)
    cx = w / 2
    base = h - 8
    cy = base - _d(1.3)
    cols = ["#8a4a42", "#4a5f80", "#a08a4a"]

    def P(u, v, z):  # 地面偏移(米) + 高度(米) → 像素
        return (cx + u * PPM, cy + v * GY - z * PPM)

    segs = []  # (depth, pts, color, width)
    for k in range(8):
        phi = math.pi * k / 8
        for sgn in (1, -1):
            pts = [P(1.4 * math.cos(th) * math.cos(phi) * sgn, -1.4 * math.cos(th) * math.sin(phi) * sgn,
                     1.4 * math.sin(th)) for th in np.linspace(0, math.pi / 2, 12)]
            depth = -math.sin(phi) * sgn
            segs.append((depth, pts, cols[k % 3], 2.6))
    for th in (math.pi / 6, math.pi / 3):
        for half in (0, 1):
            ph = np.linspace(math.pi * half, math.pi * (half + 1), 20)
            pts = [P(1.4 * math.cos(th) * math.cos(p), -1.4 * math.cos(th) * math.sin(p), 1.4 * math.sin(th)) for p in ph]
            segs.append((-1.0 if half == 0 else 1.0, pts, "#7b7f84", 2.2))
    # 地面环
    for half in (0, 1):
        ph = np.linspace(math.pi * half, math.pi * (half + 1), 24)
        pts = [P(1.4 * math.cos(p), -1.4 * math.sin(p), 0.02) for p in ph]
        segs.append((-1.2 if half == 0 else 1.2, pts, "#5b5f64", 3.0))
    for depth, pts, c, wd in sorted(segs, key=lambda s: s[0]):
        m = L.line(pts, wd)
        shade = 0.7 if depth < 0 else 1.0
        L.paint(m, hexc(c) * shade)
        hi = L.line([(x - 0.6, y - 0.8) for x, y in pts], wd * 0.4)
        L.paint(hi * m, hexc("#e8eef3"), 0.35 * shade)
        sn = L.line([(x, y - 1.2) for x, y in pts if y < cy - 40], wd * 0.9) if any(y < cy - 40 for _, y in pts) else None
        if sn is not None:
            L.paint(sn, hexc("#e6edf3"), 0.7)
    L.snow_cap(cx - 20, cx + 20, cy - R - 2, 7, 131, droop=0.2)
    L.snow_cap(cx - R - 10, cx + R + 10, cy + _d(1.4) + 2, 10, 132, droop=0.0)
    return L.finish(), (cx, base)


def fence_segment(kind: str):
    seg = _m(4.0)
    w, h = int(seg + 10), 156
    L = Layer(w, h, 2)
    base, x0 = 148, 5
    top = base - 128
    gap = 8  # 12cm 底缝
    mesh = L.rect(x0, top + 4, x0 + seg, base - gap)
    if kind == "torn":
        tear = L.poly([(x0 + seg * 0.55, base - gap), (x0 + seg, base - gap), (x0 + seg, top + 30),
                       (x0 + seg * 0.82, top + 60), (x0 + seg * 0.62, top + 96)])
        mesh = np.clip(mesh - tear, 0, 1)
    if kind == "torn_l":
        tear = L.poly([(x0, base - gap), (x0 + seg * 0.45, base - gap), (x0 + seg * 0.38, top + 96),
                       (x0 + seg * 0.18, top + 60), (x0, top + 30)])
        mesh = np.clip(mesh - tear, 0, 1)
    u = (L.X - L.Y) % 9.0
    v = (L.X + L.Y) % 9.0
    wire = (smooth(1.3, 0.4, np.minimum(u, 9 - u)) + smooth(1.3, 0.4, np.minimum(v, 9 - v))).clip(0, 1)
    L.paint(wire * mesh, hexc("#a3adb7"), 0.72)
    ice = (vnoise(L.H, L.W, 5 * L.ss, 5 * L.ss, 140 + len(kind)) > 0.74) * wire * mesh
    L.paint(ice.astype(np.float32), hexc("#eef4f8"), 0.8)
    L.paint(mesh * smooth(base - 40, base - gap, L.Y) * wire, hexc("#e0e8ef"), 0.5)
    # 撕口卷边
    if kind.startswith("torn"):
        edge = np.clip(L.line([(x0 + seg * 0.62, top + 96), (x0 + seg * 0.82, top + 60), (x0 + seg, top + 30)], 2.4)
                       if kind == "torn" else
                       L.line([(x0 + seg * 0.38, top + 96), (x0 + seg * 0.18, top + 60), (x0, top + 30)], 2.4), 0, 1)
        L.paint(edge, hexc("#7f8892"))
    # 立柱 + 顶管
    for px in (x0, x0 + seg):
        post = L.rect(px - 3, top - 6, px + 3, base)
        L.paint(post, L.tex("#5b636b", 0.07, 3, int(px)))
        L.shade(post, L.gx(px - 3, px + 3, 1.25, 0.65))
        L.snow_cap(px - 4, px + 4, top - 6, 6, int(px) + 3, droop=0.1)
    L.paint(L.rect(x0, top, x0 + seg, top + 4), hexc("#69717a"))
    L.snow_cap(x0, x0 + seg, top + 1, 6, 150 + len(kind), droop=0.25)
    # 刺丝
    for k, yy in enumerate((top - 6, top - 12)):
        pts = [(x0 + t, yy + math.sin(t * 0.35 + k) * 1.4) for t in np.linspace(0, seg, 60)]
        L.paint(L.line(pts, 1.1, False), hexc("#4d545b"))
        for t in np.arange(6, seg, 14):
            L.paint(L.line([(x0 + t - 2, yy - 2), (x0 + t + 2, yy + 2)], 0.9, False), hexc("#4d545b"))
    if kind == "b":
        sign = L.rect(x0 + seg * 0.4, top + 34, x0 + seg * 0.4 + 40, top + 58)
        L.paint(sign, L.tex("#c8c4b4", 0.08, 3, 160))
        L.paint(L.rect(x0 + seg * 0.4, top + 34, x0 + seg * 0.4 + 40, top + 41), hexc("#9a3e36"))
        L.paint(L.rect(x0 + seg * 0.4 + 5, top + 46, x0 + seg * 0.4 + 35, top + 48), hexc("#4a4a48"), 0.8)
        L.rust_streaks(sign, 161, 0.5)
    L.snow_cap(x0 - 6, x0 + seg + 6, base - 1, 14, 170 + len(kind), droop=0.0)
    return L.finish(outline="#0a0d11", outline_a=0.5), (x0, base)


def corpse_tarp():
    w, h = 134, 70
    L = Layer(w, h, 3)
    base = 62
    pts = [(10, base - 6)]
    for t in np.linspace(0, 1, 18):
        x = 12 + t * 100
        bump = 14 + 8 * math.exp(-((t - 0.15) / 0.08) ** 2) + 5 * math.exp(-((t - 0.45) / 0.18) ** 2)
        pts.append((x, base - 10 - bump))
    pts += [(114, base - 8), (112, base - 2), (12, base - 1)]
    tarp = L.poly(pts)
    L.paint(tarp, L.tex("#5a6052", 0.1, 4, 181))
    L.shade(tarp, L.gy(base - 34, base, 1.12, 0.7))
    folds = 0.88 + 0.12 * np.sin(L.X * 0.45 + np.sin(L.Y * 0.3) * 2)
    L.shade(tarp, folds)
    for xx in (40, 82):
        L.paint(L.rect(xx, base - 30, xx + 2.2, base - 1) * tarp, hexc("#8c7a55"))
    # 露出的毡靴
    L.paint(L.rect(112, base - 16, 126, base - 3, 3), hexc("#2a2622"))
    L.paint(L.rect(113, base - 26, 124, base - 15, 3), hexc("#322c26"))
    L.snow_cap(14, 110, base - 22, 14, 182, droop=0.3, under=tarp)
    L.snow_cap(2, w - 2, base - 1, 10, 183, droop=0.0)
    return L.finish(), (w / 2, base)


def boxcar():
    length = int(_m(14.0))
    w, h = length + 40, 420
    L = Layer(w, h, 2)
    base, x0 = 410, 20
    rail_y = base - _d(0.64)
    wheel_r = 30
    body_bot = base - 25 - 70
    body_top = body_bot - 179
    D = _d(2.8)
    paint = "#663a2d"
    # 车顶（拱形，压缩深度 D）
    roof = L.rect(x0 + 2, body_top - D, x0 + length - 2, body_top + 1)
    L.paint(roof, L.tex("#5a4038", 0.06, 10, 201))
    L.shade(roof, 0.8 + 0.3 * np.sin(np.clip((L.Y - (body_top - D)) / D, 0, 1) * math.pi))
    # 车体
    body = L.rect(x0, body_top, x0 + length, body_bot)
    L.paint(body, L.tex(paint, 0.08, 10, 202))
    planks = 0.92 + 0.08 * np.sin(L.Y * 0.57)
    L.shade(body, planks)
    for yy in np.arange(body_top + 10, body_bot, 11):
        L.paint(L.rect(x0, yy, x0 + length, yy + 0.9), hexc("#3a2219"), 0.7)
    L.shade(body, L.gy(body_top, body_bot, 1.08, 0.82))
    L.grime(body, 203, 0.22, 12)
    L.tint(body * smooth(0.55, 0.85, L.noise(6, 204, 3)), hexc("#9aa5ae"), 0.25)  # 霜
    for k in range(14):
        xx = x0 + 8 + k * (length - 16) / 13
        if abs(xx - (x0 + length / 2)) < 130:
            continue
        L.paint(L.rect(xx - 3, body_top, xx + 3, body_bot), hexc("#2c2e31"))
        L.paint(L.rect(xx - 3, body_top, xx - 1.8, body_bot), hexc("#5e6369"), 0.7)
    for yy in (body_top, body_bot - 6):
        L.paint(L.rect(x0, yy, x0 + length, yy + 6), hexc("#2c2e31"))
    # 推拉门（微开）
    dx0, dx1 = x0 + length / 2 - 121, x0 + length / 2 + 121
    door = L.rect(dx0, body_top + 6, dx1, body_bot - 2)
    L.paint(door, L.tex("#6d4132", 0.08, 8, 205))
    for yy in np.arange(body_top + 14, body_bot, 11):
        L.paint(L.rect(dx0, yy, dx1, yy + 0.9) * door, hexc("#3a2219"), 0.7)
    L.paint(L.rect(dx1 - 16, body_top + 6, dx1, body_bot - 2), hexc("#0d0b0a"))
    L.paint(L.rect(dx1 - 14, body_bot - 36, dx1 - 2, body_bot - 6), hexc("#3a2a1a"), 0.7)
    for xx in (dx0, dx1 - 16):
        L.paint(L.rect(xx - 2, body_top + 6, xx + 3, body_bot - 2), hexc("#2c2e31"))
    L.paint(L.rect(dx0 - 10, body_top - 3, dx1 + 10, body_top + 3), hexc("#3a3d40"))
    L.paint(L.rect(dx0 - 10, body_bot - 4, dx1 + 10, body_bot + 2), hexc("#3a3d40"))
    L.paint(L.rect(dx1 - 34, body_top + 92, dx1 - 22, body_top + 104), hexc("#3a3d40"))
    L.paint(L.ellipse(dx1 - 28, body_top + 110, 3, 3), hexc("#8a8f94"))
    L.paint(L.line([(dx1 - 28, body_top + 104), (dx1 - 28, body_top + 108)], 0.8), hexc("#c4b48a"))
    L.rust_streaks(body, 206, 0.45, color="#5a3020")
    # 白色模板字：大号「3」+ 数据栏条
    txt = Layer(w, h, 1)
    im = Image.new("L", (w * L.ss, h * L.ss), 0)
    ImageDraw.Draw(im).text(((x0 + 120) * L.ss, (body_top + 34) * L.ss), "3", fill=255,
                            font=ImageFont.truetype(FONT_BOLD, 92 * L.ss))
    m3 = np.asarray(im, np.float32) / 255.0
    L.paint(m3 * smooth(0.25, 0.6, L.noise(2, 207)), hexc("#d8dcd8"), 0.8)
    for k in range(4):
        yy = body_top + 40 + k * 12
        L.paint(L.rect(x0 + length - 200, yy, x0 + length - 200 + (80 - k * 14), yy + 5), hexc("#cfd4d0"), 0.55)
    # 底架、转向架、车轮
    L.paint(L.rect(x0 + 6, body_bot, x0 + length - 6, body_bot + 16), hexc("#1f2124"))
    for k in range(5):
        xx = x0 + 260 + k * 90
        L.paint(L.line([(xx, body_bot + 16), (xx + 40, rail_y - 30)], 2), hexc("#2a2c2f"))
    for bx in (x0 + 150, x0 + length - 150):
        frame = L.poly([(bx - 96, body_bot + 18), (bx + 96, body_bot + 18), (bx + 86, rail_y - 18),
                        (bx - 86, rail_y - 18)])
        L.paint(frame, hexc("#25282c"))
        for s in (-1, 1):
            wx = bx + s * 56
            wy = rail_y - wheel_r
            L.paint(L.ellipse(wx, wy, wheel_r, wheel_r), hexc("#1a1c1f"))
            L.paint(L.arc(wx, wy, wheel_r - 2, wheel_r - 2, 200, 330, 2.4), hexc("#6f767d"))
            L.paint(L.ellipse(wx, wy, 9, 9), hexc("#3b3f44"))
            L.paint(L.rect(wx - 11, wy - 10, wx + 11, wy + 8), hexc("#2e3236"))
        for k in range(3):
            L.paint(L.ellipse(bx - 14 + k * 14, body_bot + 32, 5, 9), hexc("#474c52"))
        L.snow_cap(bx - 96, bx + 96, body_bot + 20, 6, int(bx), droop=0.1)
    for ex in (x0 - 14, x0 + length):
        L.paint(L.rect(ex, body_bot - 6, ex + 14, body_bot + 8), hexc("#2a2c2f"))
    # 车顶厚雪 + 冰锥
    L.snow_cap(x0 - 2, x0 + length + 2, body_top + 2, (D + 6) / 0.8, 208, droop=0.35)
    L.icicles(x0 + 6, x0 + length - 6, body_top + 4, 18, 80, 209, 2.2)
    L.icicles(x0 + 6, x0 + length - 6, body_bot + 14, 9, 40, 210, 1.6)
    L.snow_cap(x0 - 20, x0 + length + 20, base - 2, 12, 211, droop=0.0)
    return L.finish(), (x0 + length / 2, base)


def water_tower():
    w, h = 340, 560
    L = Layer(w, h, 2)
    base, cx = 548, 170
    rb, ryb = _m(1.8), _d(1.8)
    cyb = base - ryb
    hb = 218
    # 砖砌塔身
    shaft = np.clip(L.rect(cx - rb, cyb - hb, cx + rb, cyb) + L.ellipse(cx, cyb, rb, ryb) *
                    (L.Y >= cyb), 0, 1)
    u = np.clip((L.X - cx) / rb, -1, 1)
    ang = np.arcsin(u)
    bx = (ang * rb) / 18.0
    row = np.floor((L.Y) / 8.0)
    brick_u = (bx + (row % 2) * 0.5) % 1.0
    mortar = (smooth(0.06, 0.0, np.minimum(brick_u, 1 - brick_u) * np.cos(ang).clip(0.2)) +
              smooth(1.0, 0.0, (L.Y % 8.0))).clip(0, 1)
    btone = 0.85 + 0.3 * vnoise(L.H, L.W, 18 * L.ss, 8 * L.ss, 221)
    brick = hexc("#6d4a3c")[None, None, :] * btone[..., None]
    L.paint(shaft, brick)
    L.paint(shaft * mortar, hexc("#8a8279"), 0.7)
    light = np.clip(0.55 + 0.6 * np.cos(ang + 0.45), 0.25, 1.15)
    L.shade(shaft, light)
    L.grime(shaft, 222, 0.2, 10)
    L.tint(shaft * smooth(cyb - 80, cyb, L.Y), hexc("#cfd9e2"), 0.25)
    # 拱门 + 小窗
    door = np.clip(L.rect(cx - 24, cyb - 74 + ryb * 0.0, cx + 24, base - 6) + L.ellipse(cx, cyb - 74, 24, 18), 0, 1)
    door *= (L.Y > cyb - 92)
    L.paint(door, L.tex("#3b2c20", 0.12, 2, 223, cy=12))
    for k in range(4):
        L.paint(L.rect(cx - 24 + k * 12, cyb - 90, cx - 23 + k * 12, base - 6) * door, hexc("#1f1710"))
    for (wx, wy) in [(cx - 50, cyb - 160), (cx + 40, cyb - 150)]:
        L.paint(np.clip(L.rect(wx - 8, wy, wx + 8, wy + 24) + L.ellipse(wx, wy, 8, 7), 0, 1), hexc("#141820"))
    L.paint(L.rect(cx - rb - 6, cyb - hb - 10, cx + rb + 6, cyb - hb + 4), L.tex("#7c6a5e", 0.08, 3, 224))
    # 水箱（木桶板 + 钢箍）
    rt = _m(2.15)
    ht = 166
    tb = cyb - hb - 6
    tank = L.rect(cx - rt, tb - ht, cx + rt, tb) + L.ellipse(cx, tb, rt, _d(2.15)) * (L.Y >= tb)
    tank = np.clip(tank, 0, 1)
    ut = np.clip((L.X - cx) / rt, -1, 1)
    at = np.arcsin(ut)
    stave = ((at * rt) / 11.0) % 1.0
    L.paint(tank, hexc("#4d3e30")[None, None, :] * (0.85 + 0.25 * vnoise(L.H, L.W, 3 * L.ss, 30 * L.ss, 225))[..., None])
    L.paint(tank * smooth(0.08, 0.0, np.minimum(stave, 1 - stave) * np.cos(at).clip(0.2)), hexc("#241b13"), 0.8)
    L.shade(tank, np.clip(0.5 + 0.65 * np.cos(at + 0.45), 0.25, 1.15))
    for yy in np.linspace(tb - ht + 16, tb - 10, 5):
        band = L.rect(cx - rt, yy, cx + rt, yy + 4) * tank
        L.paint(band, hexc("#3b3f44"))
        L.paint(band * smooth(yy + 1.5, yy, L.Y), hexc("#8a9096"), 0.6)
    L.tint(tank * smooth(0.65, 0.85, L.noise(6, 226, 20)), hexc("#cfe0ec"), 0.25)
    L.icicles(cx - rt + 6, cx + rt - 6, tb + _d(2.15) - 4, 30, 34, 227, 2.4)
    # 锥形顶 + 厚雪
    apex = tb - ht - 64
    roof = L.poly([(cx - rt - 10, tb - ht + 4), (cx + rt + 10, tb - ht + 4), (cx, apex)])
    L.paint(roof, L.tex("#4a5057", 0.06, 4, 228))
    L.paint(roof * smooth(0.0, 1.0, (L.Y - apex) / 70.0), hexc("#e8eef4"), 0.85)
    L.snow_cap(cx - rt - 12, cx + rt + 12, tb - ht + 6, 14, 229, droop=0.4)
    # 检修梯
    for xx in (cx + rt - 30, cx + rt - 18):
        L.paint(L.rect(xx, tb - ht + 10, xx + 1.6, base - 40), hexc("#2a2e33"))
    for yy in np.arange(tb - ht + 16, base - 40, 10):
        L.paint(L.rect(cx + rt - 30, yy, cx + rt - 16, yy + 1.4), hexc("#2a2e33"))
    L.snow_cap(cx - rb - 20, cx + rb + 20, base - 2, 22, 230, droop=0.0)
    return L.finish(), (cx, base)


def watchtower():
    w, h = 236, 480
    L = Layer(w, h, 3)
    base, cx = 470, 118
    plat_y = base - 352
    fl, fr = (cx - _m(1.3), base), (cx + _m(1.3), base)
    bl, br = (cx - _m(1.15), base - _d(1.3)), (cx + _m(1.15), base - _d(1.3))
    tl, tr = (cx - 60, plat_y), (cx + 60, plat_y)
    tbl, tbr = (cx - 54, plat_y - 30), (cx + 54, plat_y - 30)
    steel = "#4a5058"
    for a, b in [(bl, tbl), (br, tbr)]:
        L.paint(L.line([a, b], 4), hexc(steel) * 0.7)
    for k in range(6):
        t0, t1 = k / 6, (k + 1) / 6
        pa = (bl[0] + (tbl[0] - bl[0]) * t0, bl[1] + (tbl[1] - bl[1]) * t0)
        pb = (br[0] + (tbr[0] - br[0]) * t1, br[1] + (tbr[1] - br[1]) * t1)
        L.paint(L.line([pa, pb], 1.6), hexc(steel) * 0.6)
    # 检修梯（中间）
    for xx in (cx - 8, cx + 8):
        L.paint(L.line([(xx, base - 20), (xx, plat_y)], 1.6), hexc("#3a3f45"))
    for yy in np.arange(plat_y + 8, base - 20, 12):
        L.paint(L.rect(cx - 8, yy, cx + 8, yy + 1.4), hexc("#3a3f45"))
    for a, b in [(fl, tl), (fr, tr)]:
        L.paint(L.line([a, b], 6), hexc(steel))
        L.paint(L.line([(a[0] - 1.5, a[1]), (b[0] - 1.5, b[1])], 1.6), hexc("#8a9198"), 0.6)
    for k in range(6):
        t0, t1 = k / 6, (k + 1) / 6
        pa = (fl[0] + (tl[0] - fl[0]) * t0, fl[1] + (tl[1] - fl[1]) * t0)
        pb = (fr[0] + (tr[0] - fr[0]) * t1, fr[1] + (tr[1] - fr[1]) * t1)
        pc = (fr[0] + (tr[0] - fr[0]) * t0, fr[1] + (tr[1] - fr[1]) * t0)
        pd = (fl[0] + (tl[0] - fl[0]) * t1, fl[1] + (tl[1] - fl[1]) * t1)
        L.paint(L.line([pa, pb], 2.2), hexc(steel))
        L.paint(L.line([pc, pd], 2.2), hexc(steel))
        L.paint(L.line([pa, pc], 2.2), hexc(steel) * 0.9)
    # 平台
    deck = L.poly([(cx - 72, plat_y), (cx + 72, plat_y), (cx + 66, plat_y - 34), (cx - 66, plat_y - 34)])
    L.paint(deck, L.tex("#4b4339", 0.1, 3, 241))
    L.paint(L.rect(cx - 72, plat_y, cx + 72, plat_y + 8), hexc("#353a40"))
    # 探照灯（朝西）
    lx, ly = cx - 8, plat_y - 34
    L.paint(L.rect(lx - 4, ly - 4, lx + 4, ly + 14), hexc("#2f3439"))
    drum = L.poly([(lx - 24, ly - 30), (lx + 18, ly - 24), (lx + 18, ly - 2), (lx - 24, ly + 4)])
    L.paint(drum, L.tex("#5a6068", 0.06, 3, 242))
    L.shade(drum, L.gy(ly - 30, ly + 4, 1.2, 0.7))
    L.paint(L.ellipse(lx - 25, ly - 13, 6, 17), hexc("#fff1c4"))
    L.paint(L.ellipse(lx - 24, ly - 13, 3, 10), hexc("#ffffff"))
    L.snow_cap(lx - 22, lx + 18, ly - 26, 7, 243, droop=0.2)
    # 栏杆（前沿）
    for xx in np.linspace(cx - 70, cx + 70, 8):
        L.paint(L.rect(xx - 1.2, plat_y - 40, xx + 1.2, plat_y), hexc("#3d434a"))
    L.paint(L.rect(cx - 72, plat_y - 42, cx + 72, plat_y - 38), hexc("#555c64"))
    L.paint(L.rect(cx - 72, plat_y - 22, cx + 72, plat_y - 19.6), hexc("#555c64"))
    L.snow_cap(cx - 70, cx + 70, plat_y - 33, 12, 244, droop=0.2)
    L.snow_cap(cx - 73, cx + 73, plat_y - 41, 5, 245, droop=0.1)
    L.icicles(cx - 70, cx + 70, plat_y + 8, 14, 16, 246, 1.6)
    L.rust_streaks(L.rect(0, 0, w, h) * (L.a > 0), 247, 0.3)
    for p in (fl, fr):
        L.paint(L.rect(p[0] - 8, p[1] - 10, p[0] + 8, p[1]), hexc("#6d7070"))
    L.snow_cap(cx - 100, cx + 100, base - 2, 14, 248, droop=0.0)
    return L.finish(), (cx, base)


def signal_post():
    w, h = 54, 252
    L = Layer(w, h, 4)
    base, cx = 246, 27
    L.paint(L.rect(cx - 2.5, base - 210, cx + 2.5, base), L.tex("#4e555c", 0.06, 3, 251, cy=20))
    L.paint(L.rect(cx - 9, base - 18, cx + 9, base), L.tex("#5d6266", 0.08, 3, 252))
    hy = base - 196
    L.paint(L.ellipse(cx, hy, 15, 15), hexc("#e8e6e0"))
    L.paint(L.ellipse(cx, hy, 12.5, 12.5), hexc("#16181a"))
    L.paint(L.ellipse(cx, hy, 7, 7), hexc("#ff4a3a"))
    L.paint(L.ellipse(cx - 2, hy - 2, 2.4, 2.4), hexc("#ffd6cc"))
    L.paint(L.arc(cx, hy - 2, 10, 9, 190, 350, 3), hexc("#2a2d30"))
    L.snow_cap(cx - 15, cx + 15, hy - 14, 6, 253, droop=0.2)
    L.snow_cap(cx - 12, cx + 12, base - 2, 10, 254, droop=0.0)
    return L.finish(), (cx, base)


def tin_can():
    w, h = 16, 16
    L = Layer(w, h, 6)
    c = L.rect(4, 4, 12, 13, 2)
    L.paint(c, L.tex("#9aa3ac", 0.08, 1, 261))
    L.shade(c, L.gx(4, 12, 1.3, 0.6))
    L.paint(L.rect(4, 7, 12, 10) * c, hexc("#8a5a3a"), 0.7)
    L.paint(L.ellipse(8, 4.5, 4, 1.5), hexc("#c9d0d6"))
    return L.finish(), (8, 13)


def brake_van():
    """报废守车：9m 短车体 + 车顶瞭望棚 + 两端外平台 / 栏杆 + 端头手制动轮。"""
    length = int(_m(9.0))
    w, h = length + 44, 400
    L = Layer(w, h, 2)
    base, x0 = 390, 22
    rail_y = base - _d(0.64)
    wheel_r = 26
    body_bot = base - 22 - 62
    body_top = body_bot - 150
    D = _d(2.6)
    # 车顶 + 瞭望棚（cupola）
    roof = L.rect(x0 + 2, body_top - D, x0 + length - 2, body_top + 1)
    L.paint(roof, L.tex("#4d4136", 0.06, 9, 301))
    L.shade(roof, 0.8 + 0.3 * np.sin(np.clip((L.Y - (body_top - D)) / D, 0, 1) * math.pi))
    cw = length * 0.30
    cup = L.rect(x0 + length * 0.36, body_top - D - 54, x0 + length * 0.36 + cw, body_top - D + 2)
    L.paint(cup, L.tex("#5a4a3c", 0.07, 7, 302))
    for k in range(4):                                    # 瞭望窗（全暗，玻璃早没了）
        xx = x0 + length * 0.36 + 10 + k * (cw - 20) / 3
        L.paint(L.rect(xx - 7, body_top - D - 44, xx + 7, body_top - D - 14), hexc("#101418"))
        L.paint(L.rect(xx - 9, body_top - D - 46, xx + 9, body_top - D - 42), hexc("#3d4348"))
    L.snow_cap(x0 + length * 0.36 - 4, x0 + length * 0.36 + cw + 4, body_top - D - 52, 10, 303, droop=0.3)
    # 车体：竖板条 + 加固斜撑
    body = L.rect(x0, body_top, x0 + length, body_bot)
    L.paint(body, L.tex("#5d4a38", 0.08, 9, 304))
    L.shade(body, 0.94 + 0.06 * np.sin(L.Y * 0.5))
    for xx in np.arange(x0 + 6, x0 + length - 4, 13):
        L.paint(L.rect(xx, body_top, xx + 1.1, body_bot), hexc("#33271c"), 0.65)
    L.shade(body, L.gy(body_top, body_bot, 1.08, 0.8))
    L.grime(body, 305, 0.26, 10)
    L.tint(body * smooth(0.5, 0.85, L.noise(6, 306, 3)), hexc("#9aa5ae"), 0.3)      # 霜
    L.rust_streaks(body, 307, 0.5, color="#5a3020")
    for k in (0.18, 0.82):                                   # 斜撑
        L.paint(L.line([(x0 + length * k - 40, body_bot - 6), (x0 + length * k + 40, body_top + 6)], 5),
                hexc("#3a2d20"), 0.9)
    for yy in (body_top, body_bot - 6):
        L.paint(L.rect(x0, yy, x0 + length, yy + 6), hexc("#2c2e31"))
    # 车门（滑门，半开一条黑缝）+ 编号牌（漆条，不用字体）
    dx0, dx1 = x0 + length * 0.55, x0 + length * 0.55 + 110
    L.paint(L.rect(dx0, body_top + 5, dx1, body_bot - 2), L.tex("#66513d", 0.08, 7, 308))
    L.paint(L.rect(dx1 - 12, body_top + 5, dx1, body_bot - 2), hexc("#0c0a09"))
    L.paint(L.rect(dx0 - 8, body_top + 2, dx1 + 8, body_top + 7), hexc("#3a3d40"))
    L.paint(L.rect(x0 + 24, body_top + 26, x0 + 118, body_top + 60), hexc("#7d8791"), 0.8)
    L.paint(L.rect(x0 + 32, body_top + 34, x0 + 104, body_top + 41), hexc("#e2e6e0"), 0.7)
    L.paint(L.rect(x0 + 32, body_top + 46, x0 + 78, body_top + 53), hexc("#e2e6e0"), 0.55)
    # 底架 / 轴 / 轮（两轴守车）
    L.paint(L.rect(x0 + 4, body_bot, x0 + length - 4, body_bot + 14), hexc("#1f2124"))
    for bx in (x0 + 110, x0 + length - 110):
        frame = L.poly([(bx - 70, body_bot + 16), (bx + 70, body_bot + 16), (bx + 62, rail_y - 16),
                        (bx - 62, rail_y - 16)])
        L.paint(frame, hexc("#25282c"))
        for s in (-1, 1):
            wx = bx + s * 40
            wy = rail_y - wheel_r
            L.paint(L.ellipse(wx, wy, wheel_r, wheel_r), hexc("#1a1c1f"))
            L.paint(L.arc(wx, wy, wheel_r - 2, wheel_r - 2, 200, 330, 2.2), hexc("#6f767d"))
            L.paint(L.ellipse(wx, wy, 8, 8), hexc("#3b3f44"))
        L.snow_cap(bx - 70, bx + 70, body_bot + 18, 6, int(bx), droop=0.1)
    # 两端外平台 + 栏杆 + 手制动轮
    for ex, sgn in ((x0 - 18, -1), (x0 + length, 1)):
        L.paint(L.rect(ex, body_bot - 4, ex + 18, body_bot + 10), hexc("#2a2c2f"))
        for k in range(3):
            L.paint(L.rect(ex + 2 + k * 6, body_bot - 52, ex + 4 + k * 6, body_bot - 2),
                    hexc("#3d4348"), 0.9)
        L.paint(L.rect(ex, body_bot - 54, ex + 18, body_bot - 50), hexc("#4a5157"))
        L.snow_cap(ex, ex + 18, body_bot - 50, 5, 309 + int(ex), droop=0.2)
    bw = x0 + length + 9
    L.paint(L.ellipse(bw, body_top + 34, 17, 17), hexc("#33383c"))
    L.paint(L.ellipse(bw, body_top + 34, 13, 13), hexc("#22262a"))
    for a in range(0, 360, 60):
        L.paint(L.line([(bw, body_top + 34),
                        (bw + 13 * math.cos(math.radians(a)), body_top + 34 + 13 * math.sin(math.radians(a)))],
                       2.4), hexc("#4a5157"))
    # 车顶厚雪 + 冰锥 + 落地铁轨积雪
    L.snow_cap(x0 - 2, x0 + length + 2, body_top + 2, (D + 6) / 0.8, 310, droop=0.35)
    L.icicles(x0 + 6, x0 + length - 6, body_top + 4, 16, 60, 311, 2.0)
    L.icicles(x0 + 6, x0 + length - 6, body_bot + 12, 8, 30, 312, 1.5)
    L.snow_cap(x0 - 20, x0 + length + 20, base - 2, 12, 313, droop=0.0)
    return L.finish(), (x0 + length / 2, base)


def switch_stand():
    """转辙器手柄台：混凝土基座 + 立式机架 + 配重手柄 + 红白表示牌 + 小灯。"""
    w, h = 96, 150
    L = Layer(w, h, 4)
    base, cx = 142, 48
    L.paint(L.rect(cx - 26, base - 16, cx + 26, base), L.tex("#6a6f74", 0.08, 4, 321))
    L.shade(L.rect(cx - 26, base - 16, cx + 26, base), L.gy(base - 16, base, 1.06, 0.85))
    L.snow_cap(cx - 28, cx + 28, base - 14, 7, 322, droop=0.2)
    L.paint(L.rect(cx - 5, base - 96, cx + 5, base - 10), L.tex("#3f474c", 0.06, 3, 323, cy=14))
    L.paint(L.rect(cx - 12, base - 104, cx + 12, base - 92), L.tex("#4a5157", 0.06, 3, 324))
    # 配重手柄（斜向上）+ 握把
    L.paint(L.line([(cx + 2, base - 96), (cx + 40, base - 132)], 6), hexc("#39413f"))
    L.paint(L.line([(cx + 2, base - 96), (cx + 40, base - 132)], 2.4), hexc("#767f85"), 0.6)
    L.paint(L.rect(cx + 34, base - 140, cx + 46, base - 126), hexc("#20262a"))
    # 表示牌（红白两半：定位 / 反位）
    L.paint(L.ellipse(cx - 22, base - 112, 13, 13), hexc("#d8d5cf"))
    L.paint(L.rect(cx - 35, base - 112, cx - 22, base - 99), hexc("#b03a2c"))
    L.paint(L.rect(cx - 22, base - 125, cx - 9, base - 112), hexc("#b03a2c"))
    L.paint(L.arc(cx - 22, base - 112, 13, 13, 0, 360, 2.2), hexc("#2f3538"))
    L.snow_cap(cx - 36, cx - 8, base - 124, 5, 325, droop=0.2)
    # 小灯
    L.paint(L.rect(cx - 3, base - 122, cx + 3, base - 104), hexc("#2f3538"))
    L.paint(L.ellipse(cx, base - 126, 6, 7), hexc("#3a4045"))
    L.paint(L.ellipse(cx, base - 126, 3.6, 4.4), hexc("#ffd9a0"), 0.85)
    L.snow_cap(cx - 7, cx + 7, base - 130, 4, 326, droop=0.2)
    return L.finish(), (cx, base)


def dispatch_board():
    """发车令铁皮板：两根角钢立柱 + 带雨檐的搪瓷板 + 钉着的纸（一张盖红章）。"""
    w, h = 190, 210
    L = Layer(w, h, 4)
    base, cx = 202, 95
    for px_ in (cx - 62, cx + 56):
        L.paint(L.rect(px_, base - 150, px_ + 7, base), L.tex("#4a5157", 0.06, 3, 331, cy=16))
        L.paint(L.rect(px_ - 3, base - 8, px_ + 10, base), L.tex("#5d6266", 0.08, 3, 332))
    L.snow_cap(cx - 70, cx + 68, base - 4, 8, 333, droop=0.0)
    # 板面
    b = L.rect(cx - 78, base - 168, cx + 76, base - 52)
    L.paint(b, L.tex("#5f6a72", 0.06, 6, 334))
    L.shade(b, L.gy(base - 168, base - 52, 1.08, 0.86))
    L.grime(b, 335, 0.2, 6)
    L.rust_streaks(b, 336, 0.35, color="#7a5a34", cell=(1.5, 14))
    L.paint(L.rect(cx - 78, base - 168, cx + 76, base - 163), hexc("#39413f"))
    # 雨檐 + 雪
    L.paint(L.poly([(cx - 88, base - 168), (cx + 86, base - 168), (cx + 78, base - 180),
                    (cx - 80, base - 180)]), hexc("#4a5157"))
    L.snow_cap(cx - 88, cx + 86, base - 176, 9, 337, droop=0.3)
    L.icicles(cx - 84, cx + 82, base - 168, 12, 16, 338, 1.8)
    # 钉着的纸：三张白条 + 一张盖红章的发车令（今晚还没撕）
    papers = [(cx - 66, base - 156, 46, 62, "#e8e6df", 0), (cx - 12, base - 152, 40, 54, "#ddd9cf", 1),
              (cx + 34, base - 158, 38, 60, "#e6e3da", 2)]
    for (px0, py0, pw, ph, pc, k) in papers:
        L.paint(L.rect(px0, py0, px0 + pw, py0 + ph), hexc(pc), 0.95)
        L.shade(L.rect(px0, py0, px0 + pw, py0 + ph), L.gy(py0, py0 + ph, 1.05, 0.9))
        for ln in range(4):
            yy = py0 + 10 + ln * 11
            L.paint(L.rect(px0 + 5, yy, px0 + pw - 6 - (ln % 3) * 7, yy + 2.4), hexc("#5c6068"), 0.5)
        L.paint(L.ellipse(px0 + pw / 2, py0 + 3, 2.2, 2.2), hexc("#2f3538"))
    st = papers[0]
    L.paint(L.rect(st[0] + 8, st[1] + 40, st[0] + 30, st[1] + 56), hexc("#a03328"), 0.8)
    L.paint(L.rect(st[0] + 12, st[1] + 44, st[0] + 26, st[1] + 52), hexc("#c8503f"), 0.6)
    # 下半张：撕剩的旧令 + 一条搪瓷横条
    for (px0, py0, pw, ph) in ((cx - 60, base - 88, 34, 30), (cx - 14, base - 92, 30, 34),
                               (cx + 26, base - 86, 40, 26)):
        L.paint(L.poly([(px0, py0), (px0 + pw, py0 + 3), (px0 + pw - 5, py0 + ph), (px0 + 4, py0 + ph - 4)]),
                hexc("#cfccc2"), 0.85)
        for ln in range(2):
            L.paint(L.rect(px0 + 5, py0 + 8 + ln * 8, px0 + pw - 8, py0 + 10 + ln * 8), hexc("#5c6068"), 0.4)
    L.paint(L.rect(cx - 78, base - 58, cx + 76, base - 52), hexc("#39413f"), 0.8)
    # 板脚的雪
    L.snow_cap(cx - 80, cx + 78, base - 52, 7, 339, droop=0.2)
    return L.finish(), (cx, base)


ALL = {
    "PRP_Crate_Wood_Stack": crate_stack,
    "PRP_SupplyCrates_Military": supply_crates,
    "PRP_Dumpster_Steel": dumpster,
    "PRP_Locker_ElectricCabinet": electric_cabinet,
    "PRP_Car_Moskvich_Wreck": car_wreck,
    "PRP_SteamPipe_Long": steam_pipe,
    "PRP_Brazier_OilDrum": brazier,
    "PRP_StreetLamp_Sodium": street_lamp,
    "PRP_Bench_Snowy": bench,
    "PRP_Playground_Dome": playground_dome,
    "PRP_Corpse_Tarp": corpse_tarp,
    "PRP_Buran_Boxcar03": boxcar,
    "PRP_WaterTower": water_tower,
    "PRP_Watchtower_Searchlight": watchtower,
    "PRP_SignalPost_Red": signal_post,
    "PRP_TinCan": tin_can,
    "PRP_BrakeVan_Dead": brake_van,
    "PRP_SwitchStand": switch_stand,
    "PRP_DispatchBoard_Tin": dispatch_board,
}
FENCES = {"a": "PRP_Fence_ChainLink_A", "b": "PRP_Fence_ChainLink_B", "torn": "PRP_Fence_ChainLink_Torn",
          "torn_l": "PRP_Fence_ChainLink_TornL"}
