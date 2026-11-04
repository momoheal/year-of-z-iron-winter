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


def pine_snow():
    """雪松：三层枝盘 + 压雪 + 树干；庄园外围的松林。"""
    w, h = 190, 430
    L = Layer(w, h, 3)
    base, cx = 424, 95
    L.paint(L.rect(cx - 7, base - 120, cx + 7, base), L.tex("#4a382a", 0.1, 4, 501, cy=20))
    L.shade(L.rect(cx - 7, base - 120, cx + 7, base), L.gx(cx - 7, cx + 7, 1.15, 0.75))
    tiers = [(base - 96, 84, 96), (base - 178, 68, 86), (base - 250, 52, 78), (base - 312, 34, 66)]
    for k, (ty, rw, rh) in enumerate(tiers):
        m = L.poly([(cx - rw, ty), (cx + rw, ty), (cx + rw * 0.55, ty - rh * 0.62), (cx, ty - rh),
                    (cx - rw * 0.55, ty - rh * 0.62)])
        L.paint(m, L.tex("#2c3b30", 0.12, 6, 502 + k))
        L.shade(m, L.gy(ty - rh, ty, 1.12, 0.72))
        L.shade(m, L.gx(cx - rw, cx + rw, 1.08, 0.86))
        # 枝盘上的压雪（外缘厚）
        sm = L.poly([(cx - rw + 4, ty - 2), (cx + rw - 4, ty - 2), (cx + rw * 0.5, ty - rh * 0.5),
                     (cx, ty - rh * 0.72), (cx - rw * 0.5, ty - rh * 0.5)])
        n = L.noise(4, 506 + k)
        L.paint(sm * smooth(0.35, 0.6, n), lerp(hexc("#e9eff5"), hexc("#a9bacb"), 0.3), 0.95)
        L.icicles(cx - rw * 0.7, cx + rw * 0.7, ty - 1, 12, 14, 508 + k, 1.8)
    L.snow_cap(cx - 26, cx + 26, base - 306, 12, 510, droop=0.4)
    L.snow_cap(cx - 34, cx + 34, base - 2, 13, 511, droop=0.0)
    return L.finish(), (cx, base)


def cold_chest():
    """特供冷柜（卧式）：结霜柜体 + 掀盖 + 温度牌 + 挂锁。"""
    w, h = 210, 150
    L = Layer(w, h, 3)
    base, x0 = 144, 20
    top, front = obox(L, x0, base, 170, _d(1.1), 74, "#8f9aa2", "#79848c", 520, snow=0.5)
    L.shade(front, L.gx(x0, x0 + 170, 1.06, 0.86))
    L.paint(L.rect(x0 + 4, base - 46, x0 + 166, base - 40), hexc("#39413f"), 0.8)   # 盖缝
    for xx in (x0 + 52, x0 + 116):                                                   # 合页
        L.paint(L.rect(xx, base - 50, xx + 10, base - 38), hexc("#4a5157"))
    L.paint(L.rect(x0 + 140, base - 44, x0 + 152, base - 32), hexc("#9aa1a6"))       # 挂锁
    L.paint(L.rect(x0 + 12, base - 66, x0 + 62, base - 50), hexc("#2f4a63"), 0.85)   # 温度牌
    L.paint(L.rect(x0 + 18, base - 62, x0 + 46, base - 56), hexc("#e7eae4"), 0.7)
    L.rust_streaks(front, 521, 0.35, color="#6a4a2a", cell=(2.0, 16))
    L.grime(front, 522, 0.2, 6)
    fr = smooth(0.6, 0.85, L.noise(3, 523))
    L.tint(front, hexc("#dfeaf2"), 0.4 * fr)                                          # 结霜
    L.tint(top, hexc("#e9eff5"), 0.35 * smooth(0.5, 0.8, L.noise(3, 524)))
    L.snow_cap(x0 - 4, x0 + 174, base - 74, 8, 525, droop=0.25)
    L.snow_cap(x0 - 10, x0 + 180, base - 2, 10, 526, droop=0.0)
    return L.finish(), (x0 + 85, base)


def forklift():
    """铲货叉车（停）：门架 + 货叉贴地 + 护顶架 + 座位上搭一件棉大衣。"""
    w, h = 220, 240
    L = Layer(w, h, 3)
    base, x0 = 232, 30
    # 车体
    body = L.rect(x0 + 40, base - 92, x0 + 168, base - 26)
    L.paint(body, L.tex("#7a5a2c", 0.08, 6, 530))
    L.shade(body, L.gy(base - 92, base - 26, 1.1, 0.8))
    L.grime(body, 531, 0.25, 7)
    L.rust_streaks(body, 532, 0.4, color="#5a3020")
    L.paint(L.rect(x0 + 40, base - 60, x0 + 168, base - 52), hexc("#2c2e31"), 0.8)
    # 护顶架
    for px_ in (x0 + 52, x0 + 150):
        L.paint(L.rect(px_, base - 176, px_ + 7, base - 90), hexc("#39413f"))
    L.paint(L.rect(x0 + 44, base - 184, x0 + 164, base - 174), hexc("#4a5157"))
    L.snow_cap(x0 + 42, x0 + 166, base - 180, 8, 533, droop=0.25)
    # 门架 + 货叉（贴地）
    for px_ in (x0 + 6, x0 + 26):
        L.paint(L.rect(px_, base - 168, px_ + 8, base - 10), hexc("#39413f"))
    L.paint(L.rect(x0 + 2, base - 128, x0 + 34, base - 120), hexc("#4a5157"))
    L.paint(L.rect(x0 - 16, base - 12, x0 + 40, base - 4), hexc("#4a5157"))
    L.paint(L.rect(x0 - 16, base - 12, x0 - 10, base - 4), hexc("#6c757c"), 0.7)
    L.snow_cap(x0 - 18, x0 + 42, base - 10, 5, 534, droop=0.1)
    # 轮
    for wx, wr in ((x0 + 66, 26), (x0 + 146, 22)):
        L.paint(L.ellipse(wx, base - wr, wr, wr), hexc("#1a1c1f"))
        L.paint(L.ellipse(wx, base - wr, wr * 0.45, wr * 0.45), hexc("#3b3f44"))
        L.snow_cap(wx - wr, wx + wr, base - wr * 1.5, 6, int(wx), droop=0.2)
    # 座位上的棉大衣 + 驾驶杆
    L.paint(L.poly([(x0 + 96, base - 92), (x0 + 132, base - 92), (x0 + 128, base - 122),
                    (x0 + 100, base - 122)]), hexc("#4c4a42"), 0.95)
    L.paint(L.poly([(x0 + 100, base - 122), (x0 + 128, base - 122), (x0 + 122, base - 132),
                    (x0 + 106, base - 132)]), hexc("#5a574c"), 0.9)
    L.paint(L.line([(x0 + 138, base - 92), (x0 + 146, base - 118)], 4), hexc("#2f3538"))
    L.snow_cap(x0 + 38, x0 + 170, base - 2, 11, 535, droop=0.0)
    return L.finish(), (x0 + 90, base)


def incinerator_feed():
    """焚化炉进料口：斜坡 + 掀开的铁盖 + 炉口红光 + 灰斗 + 半烧的纸。"""
    w, h = 230, 200
    L = Layer(w, h, 3)
    base, cx = 194, 120
    # 炉体前脸
    face = L.rect(cx - 78, base - 150, cx + 78, base)
    L.paint(face, L.tex("#4a4038", 0.08, 7, 540))
    L.shade(face, L.gy(base - 150, base, 1.05, 0.75))
    L.grime(face, 541, 0.3, 8)
    L.rust_streaks(face, 542, 0.5, color="#5a3020", cell=(2.4, 22))
    # 铆钉带
    for yy in (base - 140, base - 76):
        L.paint(L.rect(cx - 78, yy, cx + 78, yy + 5), hexc("#2c2e31"), 0.8)
        for k in range(9):
            L.paint(L.ellipse(cx - 70 + k * 17.5, yy + 2.5, 2, 2), hexc("#6c757c"), 0.8)
    # 炉口（红光）+ 掀开的铁盖
    maw = L.rect(cx - 46, base - 108, cx + 46, base - 22)
    L.paint(maw, hexc("#160b08"))
    L.tint(maw, hexc("#ff7a2e"), 0.55 * smooth(base - 40, base - 22, L.Y))
    L.tint(maw, hexc("#c8401e"), 0.35 * smooth(base - 70, base - 40, L.Y))
    for k in range(5):   # 炉栅
        L.paint(L.rect(cx - 46, base - 96 + k * 16, cx + 46, base - 92 + k * 16) * maw, hexc("#120806"), 0.8)
    lid = L.poly([(cx - 50, base - 108), (cx + 50, base - 108), (cx + 62, base - 158), (cx - 38, base - 158)])
    L.paint(lid, L.tex("#3d4348", 0.06, 6, 543))
    L.shade(lid, 0.9)
    L.snow_cap(cx - 40, cx + 64, base - 156, 8, 544, droop=0.3)
    # 斜坡 + 灰斗 + 半烧的纸
    ramp = L.poly([(cx - 96, base), (cx - 46, base - 22), (cx + 46, base - 22), (cx + 96, base)])
    L.paint(ramp, L.tex("#565c62", 0.06, 6, 545))
    L.shade(ramp, L.gy(base - 22, base, 1.05, 0.85))
    L.snow_cap(cx - 98, cx - 52, base - 4, 7, 546, droop=0.15)
    L.paint(L.ellipse(cx + 66, base - 16, 26, 12), hexc("#2b2f33"))
    L.paint(L.ellipse(cx + 66, base - 18, 22, 9), hexc("#14171a"))
    for k in range(4):
        px_ = cx - 70 + k * 22
        L.paint(L.poly([(px_, base - 6), (px_ + 14, base - 10), (px_ + 12, base - 20), (px_ + 2, base - 16)]),
                hexc("#d8d5cf" if k % 2 else "#8a8578"), 0.85)
        L.tint(L.rect(px_, base - 20, px_ + 14, base - 6), hexc("#1a1c1f"), 0.5 * smooth(0.4, 0.8, L.noise(2, 547 + k)))
    L.snow_cap(cx - 80, cx + 80, base - 2, 10, 548, droop=0.0)
    return L.finish(), (cx, base)


def fence_electric(cut: bool = False):
    """电网高墙段（4m）：混凝土立柱 + 三道带绝缘子的铁丝 + 警示牌；cut = 被剪开的那一段。"""
    w, h = 266, 170
    L = Layer(w, h, 3)
    base = 164
    for px_ in (14, w - 22):
        L.paint(L.rect(px_, base - 150, px_ + 9, base), L.tex("#6a6f74", 0.08, 4, 551, cy=18))
        L.shade(L.rect(px_, base - 150, px_ + 9, base), L.gx(px_, px_ + 9, 1.12, 0.8))
        L.snow_cap(px_ - 2, px_ + 11, base - 148, 6, int(px_), droop=0.2)
        L.paint(L.rect(px_ - 5, base - 8, px_ + 14, base), L.tex("#5d6266", 0.08, 4, 552))
    if not cut:
        for k, yy in enumerate((base - 140, base - 108, base - 76)):
            sag = 4 + k
            L.paint(L.line([(18, yy), (w / 2, yy + sag), (w - 18, yy)], 1.6), hexc("#8d959b"), 0.9)
            for px_ in (14, w - 22):
                L.paint(L.ellipse(px_ + 4.5, yy - 1, 3.4, 4.4), hexc("#c8cfc4"))   # 瓷绝缘子
        # 警示牌
        L.paint(L.poly([(w / 2 - 26, base - 128), (w / 2 + 26, base - 128), (w / 2 + 26, base - 92),
                        (w / 2 - 26, base - 92)]), hexc("#b8a02c"), 0.9)
        L.paint(L.poly([(w / 2 - 4, base - 122), (w / 2 + 10, base - 110), (w / 2 + 2, base - 110),
                        (w / 2 + 6, base - 98), (w / 2 - 8, base - 112), (w / 2, base - 112)]),
                hexc("#141414"), 0.9)
        L.snow_cap(w / 2 - 28, w / 2 + 28, base - 126, 5, 553, droop=0.2)
    else:
        # 剪断的铁丝垂下来 + 一头立柱歪了
        for k, yy in enumerate((base - 140, base - 108, base - 76)):
            L.paint(L.line([(18, yy), (60 + k * 10, yy + 26 + k * 8)], 1.6), hexc("#8d959b"), 0.9)
            L.paint(L.line([(w - 18, yy), (w - 66 - k * 8, yy + 20 + k * 10)], 1.6), hexc("#8d959b"), 0.9)
        L.paint(L.line([(w - 22, base - 150), (w - 40, base - 40)], 9), hexc("#6a6f74"))
        L.snow_cap(w - 52, w - 26, base - 44, 6, 554, droop=0.2)
    L.snow_cap(0, w, base - 2, 9, 555, droop=0.0)
    return L.finish(), (w / 2, base)


# ---------------------------------------------------------------------------
# L07M · 3 号矿坑（mine）专属道具（v4.2）
# ---------------------------------------------------------------------------
def ore_cart():
    """运矸矿车：2.6m 钢制斗车 + 四轮 + 满载矸石 + 锈水流痕。"""
    w, h = 170, 118
    L = Layer(w, h, 3)
    base, cx = 110, 85
    body = L.poly([(22, base - 78), (148, base - 78), (138, base - 26), (32, base - 26)])
    L.paint(body, L.tex("#4e555c", 0.09, 4, 301))
    L.shade(body, np.clip(1.15 - 0.5 * np.abs(L.X - cx + 8) / 70, 0.5, 1.25))
    L.rust_streaks(body, 302, 0.75, cell=(1.8, 12))
    L.paint(L.poly([(20, base - 82), (150, base - 82), (148, base - 74), (22, base - 74)]),
            hexc("#3a4046"))
    spoil = np.clip(L.ellipse(cx, base - 84, 58, 12) + L.ellipse(cx - 22, base - 90, 26, 8)
                    + L.ellipse(cx + 26, base - 91, 24, 7), 0, 1)
    L.paint(spoil, L.tex("#2c2f34", 0.16, 3, 303))
    L.paint(spoil * smooth(0.55, 0.8, L.noise(2.2, 304)), hexc("#1d2024"), 0.7)
    L.snow_cap(cx - 52, cx + 52, base - 92, 7, 305, droop=0.4)
    for wx in (42, 128):
        L.paint(L.ellipse(wx, base - 12, 15, 13), hexc("#22262b"))
        L.paint(L.ellipse(wx, base - 12, 10, 8.5), L.tex("#4a5057", 0.1, 3, 306))
        L.paint(L.ellipse(wx, base - 12, 3.6, 3), hexc("#191c20"))
    L.paint(L.rect(42, base - 16, 128, base - 10), hexc("#33383e"))
    L.paint(L.rect(24, base - 30, 146, base - 24), hexc("#2c3137"))
    L.snow_cap(30, 142, base - 4, 9, 307, droop=0.0)
    return L.finish(), (cx, base)


def timber_support():
    """坑木 A 架支护：两根斜撑 + 顶梁 + 铁箍 + 雪。"""
    w, h = 150, 188
    L = Layer(w, h, 3)
    base, cx = 180, 75
    for sgn, sx in ((-1, 30), (1, 120)):
        leg = L.line([(sx + sgn * 6, base), (cx + sgn * 4, base - 138)], 13, False)
        L.paint(leg, L.tex("#6b5138", 0.1, 5, 311, cy=14))
        L.shade(leg, L.gx(sx - 8, sx + 10, 1.25, 0.6))
        L.rust_streaks(leg, 312, 0.25, color="#3f2f1e", cell=(1.2, 20))
    beam = L.line([(cx - 34, base - 140), (cx + 34, base - 138)], 14, False)
    L.paint(beam, L.tex("#75593c", 0.1, 5, 313))
    L.shade(beam, L.gy(base - 148, base - 130, 1.2, 0.7))
    for bx in (cx - 22, cx + 20):
        L.paint(L.rect(bx - 3, base - 150, bx + 3, base - 128), hexc("#2e3338"))
    L.snow_cap(cx - 38, cx + 38, base - 148, 8, 314, droop=0.3)
    L.snow_cap(18, 46, base - 2, 10, 315, droop=0.0)
    L.snow_cap(102, 132, base - 2, 10, 316, droop=0.0)
    return L.finish(), (cx, base)


def thermite_charge():
    """铝热剂装药堆：军绿木箱 ×3 + 白色骷髅标 + 引出的起爆电缆。"""
    w, h = 136, 96
    L = Layer(w, h, 3)
    base, cx = 90, 68
    for (x0, y0, x1, y1, seed) in ((22, base - 42, 82, base - 4, 321), (82, base - 40, 132, base - 4, 322),
                                   (34, base - 78, 94, base - 42, 323)):
        box = L.rect(x0, y0, x1, y1, 2)
        L.paint(box, L.tex("#5c6b4e", 0.09, 4, seed))
        L.shade(box, L.gy(y0, y1, 1.18, 0.72))
        L.rust_streaks(box, seed + 40, 0.3, color="#46522f", cell=(1.4, 10))
        L.paint(L.rect(x0, y0, x1, y0 + 3), hexc("#3f4a34"))
        L.paint(L.rect(x0, y1 - 4, x1, y1 - 1), hexc("#3f4a34"))
    mx, my = 64, base - 60
    L.paint(L.ellipse(mx, my - 4, 8, 7), hexc("#d8d1bf"))
    L.paint(L.ellipse(mx - 3, my - 5, 1.8, 2.2), hexc("#20242a"))
    L.paint(L.ellipse(mx + 3, my - 5, 1.8, 2.2), hexc("#20242a"))
    L.paint(L.line([(mx - 9, my + 6), (mx + 9, my + 10)], 2.6), hexc("#d8d1bf"))
    L.paint(L.line([(mx - 9, my + 10), (mx + 9, my + 6)], 2.6), hexc("#d8d1bf"))
    L.paint(L.line([(82, base - 8), (108, base - 4), (128, base - 12)], 3.4), hexc("#22262b"))
    L.paint(L.line([(30, base - 6), (18, base - 2)], 3.0), hexc("#22262b"))
    L.snow_cap(30, 96, base - 80, 6, 324, droop=0.25)
    return L.finish(), (cx, base)


def detonator_rig():
    """起爆器与电缆盘：军用起爆箱（仪表 + 手摇柄）+ 电缆盘 + 斜靠的爆破台账木夹板。"""
    w, h = 124, 92
    L = Layer(w, h, 3)
    base, cx = 86, 62
    L.paint(L.ellipse(96, base - 18, 16, 15), hexc("#33383e"))
    L.paint(L.ellipse(96, base - 18, 11, 10), L.tex("#4a5057", 0.12, 3, 331))
    for k in range(4):
        L.paint(L.ellipse(96, base - 18, 11 - k * 2.4, 10 - k * 2.2), hexc("#20242a"), 0.5)
    L.paint(L.ellipse(96, base - 18, 3.4, 3), hexc("#14171a"))
    box = L.rect(20, base - 52, 72, base - 6, 2)
    L.paint(box, L.tex("#4c5a44", 0.1, 4, 332))
    L.shade(box, L.gy(base - 52, base - 6, 1.2, 0.7))
    L.rust_streaks(box, 333, 0.35, color="#3a4632", cell=(1.3, 12))
    L.paint(L.rect(27, base - 46, 55, base - 28, 1.5), hexc("#d8d1bf"))
    L.paint(L.rect(29, base - 44, 53, base - 30, 1), hexc("#181c20"))
    L.paint(L.line([(41, base - 32), (50, base - 41)], 1.8), hexc("#c0392b"))
    L.paint(L.ellipse(33, base - 18, 3.4, 3.4), hexc("#22262b"))
    L.paint(L.ellipse(48, base - 18, 3.4, 3.4), hexc("#22262b"))
    L.paint(L.line([(62, base - 38), (78, base - 46)], 3.2), hexc("#2a2e33"))
    L.paint(L.ellipse(80, base - 47, 4, 3.4), hexc("#3a4046"))
    clip = L.poly([(12, base - 8), (26, base - 58), (40, base - 55), (28, base - 6)])
    L.paint(clip, L.tex("#8a7250", 0.1, 3, 334))
    L.paint(L.rect(22, base - 52, 33, base - 12), hexc("#e6e0d0"), 0.85)
    for ly in range(int(base) - 48, int(base) - 16, 6):
        L.paint(L.rect(24, ly, 31, ly + 1.4), hexc("#7a7466"), 0.8)
    L.paint(L.ellipse(28, base - 56, 3, 2.4), hexc("#b8b0a0"))
    L.snow_cap(18, 74, base - 54, 6, 335, droop=0.3)
    return L.finish(), (cx, base)


def spore_face():
    """孢子断面：温压爆破炸开的永冻层剖面——千层糕式层理 + 灰黑孢子粉尘层（暗哑微光）。"""
    w, h = 462, 192
    L = Layer(w, h, 3)
    base, cx = 184, 231
    wall = L.poly([(8, base), (18, 40), (70, 18), (180, 8), (300, 12), (400, 22), (452, 48), (456, base)])
    L.paint(wall, L.tex("#4a545e", 0.1, 8, 341))
    L.shade(wall, L.gy(0, base, 0.62, 1.12))
    r = np.random.default_rng(342)
    yy = 16.0
    while yy < base - 10:
        th = r.uniform(9, 22)
        band = wall * ((L.Y >= yy) & (L.Y < yy + th)).astype(np.float32)
        tone = r.uniform(-0.10, 0.10)
        L.paint(band, lerp(hexc("#454f58"), hexc("#5d6670"), 0.5 + tone * 4), 0.55)
        L.paint(band * ((L.Y >= yy) & (L.Y < yy + 1.8)).astype(np.float32), hexc("#2c333a"), 0.6)
        yy += th + r.uniform(2, 6)
    # 孢子粉尘层：灰黑偏绿的暗哑带（全剧真相的核心视觉）——对比要比周围层理更「死」更暗
    sp = wall * smooth(96, 108, L.Y) * smooth(150, 138, L.Y)
    L.tint(sp, hexc("#2f343a"), 0.95)
    L.tint(sp * smooth(0.55, 0.85, L.noise(2.6, 343)), hexc("#1c2024"), 0.75)
    L.paint(sp * ((L.Y >= 94) & (L.Y < 98)).astype(np.float32), hexc("#8b949c"), 0.5)   # 带顶压痕
    # 暗哑微光：只在粉尘带凹处，越深越亮一点点（地质微光，不是魔法）
    L.paint(sp, hexc("#7d8a72"), np.clip((0.55 + 0.6 * L.noise(3.2, 344)) * 0.34, 0, 0.42))
    spill = np.clip(L.ellipse(cx - 60, base - 8, 150, 16) + L.ellipse(cx + 130, base - 6, 110, 12), 0, 1)
    L.paint(spill * (1 - wall), L.tex("#34383e", 0.14, 4, 345))
    L.paint(spill * (1 - wall) * smooth(0.5, 0.8, L.noise(2.4, 346)), hexc("#7d8a72"), 0.22)
    L.snow_cap(20, 440, base - 2, 12, 347, droop=0.0)
    L.snow_cap(60, 240, 14, 10, 348, droop=0.45)
    L.snow_cap(300, 430, 22, 9, 349, droop=0.4)
    L.grime(wall, 350, 0.2, 7)
    return L.finish(), (cx, base)


def dummy_tower():
    """假人哨塔：脚手架铁梯 + 平台 + 穿防化服的塑料模特 + 猪嘴面具 + 扩音器（无灯）。"""
    w, h = 152, 332
    L = Layer(w, h, 3)
    base, cx = 324, 76
    for sx in (38, 114):
        leg = L.line([(sx, base), (sx + (cx - sx) * 0.22, base - 210)], 7, False)
        L.paint(leg, L.tex("#4e555c", 0.08, 4, 361, cy=18))
        L.shade(leg, L.gx(sx - 5, sx + 5, 1.25, 0.65))
        L.rust_streaks(leg, 362, 0.5, cell=(1.1, 24))
    for yy in (base - 70, base - 140):
        L.paint(L.line([(40, yy), (112, yy - 6)], 5), hexc("#454b52"))
    L.paint(L.poly([(22, base - 218), (130, base - 218), (130, base - 208), (22, base - 208)]),
            L.tex("#565c63", 0.08, 3, 363))
    L.paint(L.rect(24, base - 244, 128, base - 238), hexc("#4a5057"))
    for rx in (28, 56, 84, 112):
        L.paint(L.rect(rx - 1.6, base - 244, rx + 1.6, base - 216), hexc("#4a5057"))
    L.paint(L.line([(20, base), (26, base - 212)], 4.5), hexc("#3f454b"))
    L.paint(L.line([(34, base), (38, base - 212)], 4.5), hexc("#3f454b"))
    for k in range(7):
        yy = base - 18 - k * 28
        L.paint(L.line([(21 + k, yy), (35 + k, yy - 2)], 3), hexc("#3f454b"))
    # 塑料模特（穿肥大防化服）：躯干 + 猪嘴面具头盔 + 垂袖
    suit = L.poly([(56, base - 212), (52, base - 286), (66, base - 302), (92, base - 302),
                   (104, base - 288), (100, base - 212)])
    L.paint(suit, L.tex("#7a8087", 0.07, 5, 364))
    L.shade(suit, L.gx(52, 104, 1.3, 0.7))
    L.paint(L.poly([(56, base - 232), (46, base - 208), (54, base - 206), (62, base - 228)]),
            hexc("#6d737a"))
    L.paint(L.poly([(100, base - 230), (110, base - 206), (102, base - 204), (94, base - 228)]),
            hexc("#6d737a"))
    L.paint(L.ellipse(cx + 8, base - 312, 17, 16), L.tex("#5c6268", 0.08, 3, 365))
    L.paint(L.ellipse(cx + 8, base - 304, 9, 7), hexc("#2a2e33"))
    L.paint(L.ellipse(cx + 8, base - 303, 5, 3.4), hexc("#14171a"))
    L.paint(L.ellipse(cx + 2, base - 316, 5, 4), hexc("#181c20"))
    L.paint(L.ellipse(cx + 15, base - 316, 5, 4), hexc("#181c20"))
    L.paint(L.poly([(112, base - 246), (132, base - 258), (136, base - 246), (118, base - 238)]),
            L.tex("#6a7076", 0.08, 3, 366))
    L.paint(L.ellipse(133, base - 252, 4.2, 6), hexc("#2c3137"))
    L.snow_cap(22, 130, base - 220, 8, 367, droop=0.25)
    L.snow_cap(60, 96, base - 310, 5, 368, droop=0.3)      # 头盔上的雪要小——不然模特读成雪人
    L.snow_cap(28, 124, base - 240, 5, 369, droop=0.2)
    L.snow_cap(26, 126, base - 2, 10, 370, droop=0.0)
    return L.finish(), (cx, base)


def shanty_shed():
    """棚户板房：板墙 + 柏油纸顶 + 炉筒 + 钉死的窗——棚户巷的立面骨架。"""
    w, h = 260, 260
    L = Layer(w, h, 3)
    base = 242
    x0, bw, bh = 12, 236, 148
    wall = L.poly([(x0 + 8, base), (x0 + bw - 8, base), (x0 + bw - 2, base - bh),
                   (x0 + 2, base - bh)])
    L.paint(wall, L.tex("#6b5138", 0.11, 6, 41))
    L.shade(wall, L.gy(base - bh, base, 1.06, 0.72))
    for k in range(1, 11):                      # 板缝
        xx = x0 + bw * k / 11
        L.paint(L.rect(xx - 1, base - bh, xx + 1, base), hexc("#4c3826"), 0.55)
    roof = L.poly([(x0 - 6, base - bh + 4), (x0 + bw + 6, base - bh + 4),
                   (x0 + bw - 10, base - bh - 18), (x0 + 10, base - bh - 18)])
    L.paint(roof, L.tex("#3a4048", 0.13, 6, 43))
    L.snow_cap(x0 - 4, x0 + bw + 4, base - bh - 18, 34, 45, droop=0.22)
    # 炉筒
    sx, sy = x0 + bw - 42, base - bh - 18
    L.paint(L.rect(sx, sy - 62, sx + 12, sy), hexc("#2b2f35"))
    L.paint(L.rect(sx + 12, sy - 62, sx + 15, sy), hexc("#1e2126"), 0.7)
    L.paint(L.rect(sx - 3, sy - 66, sx + 15, sy - 58), hexc("#23272c"))
    L.snow_cap(sx - 3, sx + 15, sy - 62, 12, 46, droop=0.4)
    n = 37
    sm = L.ellipse(sx + 22 + n % 16, sy - 56, 24, 10)               # 烟
    L.paint(sm, hexc("#2c3138"), 0.5)
    sm2 = L.ellipse(sx + 40 + n % 18, sy - 68, 15, 6)
    L.paint(sm2, hexc("#232830"), 0.35)
    # 钉死的窗 + 门洞
    wx = x0 + 40
    L.paint(L.rect(wx, base - 118, wx + 58, base - 62), hexc("#221a12"))
    for i in range(3):
        L.paint(L.line([(wx + 2, base - 114 + i * 22), (wx + 56, base - 86 + i * 22)], 5),
                hexc("#5b452c"))
    L.paint(L.rect(x0 + 128, base - 128, x0 + 176, base), hexc("#241c13"))
    L.paint(L.rect(x0 + 132, base - 124, x0 + 172, base - 4), hexc("#33261a"))
    L.paint(L.rect(x0 + 138, base - 120, x0 + 141, base - 8), hexc("#171009"))
    L.grime(wall, 47, 0.28)
    L.rust_streaks(wall, 47, 0.14)
    L.snow_cap(x0 + 8, x0 + bw - 8, base - 2, 12, 48, droop=0.5)
    return L.finish(), (w / 2, base)


def med_shed():
    """药棚 + 铁门：C2 的锁点（门禁磁卡读头 + 可锁死的挂环）。"""
    w, h = 260, 230
    L = Layer(w, h, 3)
    base = 212
    x0, bw, bh = 14, 232, 156
    wall = L.poly([(x0 + 6, base), (x0 + bw - 6, base), (x0 + bw - 2, base - bh),
                   (x0 + 2, base - bh)])
    L.paint(wall, L.tex("#4a5560", 0.1, 6, 51))
    L.shade(wall, L.gy(base - bh, base, 1.05, 0.74))
    for k in range(1, 9):
        xx = x0 + bw * k / 9
        L.paint(L.rect(xx - 1, base - bh, xx + 1, base), hexc("#333c45"), 0.55)
    # 白漆十字（药）——掉了漆的卫生标记
    L.paint(L.rect(x0 + 150, base - 140, x0 + 168, base - 84), hexc("#c9cfd6"), 0.8)
    L.paint(L.rect(x0 + 122, base - 116, x0 + 196, base - 98), hexc("#c9cfd6"), 0.8)
    L.paint(L.rect(x0 + 126, base - 113, x0 + 192, base - 101), hexc("#4a5560"), 0.5)
    roof = L.poly([(x0 - 8, base - bh + 2), (x0 + bw + 8, base - bh + 2),
                   (x0 + bw - 12, base - bh - 20), (x0 + 12, base - bh - 20)])
    L.paint(roof, L.tex("#3a4048", 0.12, 6, 53))
    L.snow_cap(x0 - 6, x0 + bw + 6, base - bh - 20, 36, 55, droop=0.2)
    # 铁门
    dx0, dx1 = x0 + 44, x0 + 118
    L.paint(L.rect(dx0, base - 132, dx1, base), hexc("#3d4650"))
    L.paint(L.rect(dx0 + 4, base - 128, dx1 - 4, base - 4), L.tex("#5b6772", 0.1, 5, 57))
    for yy in (base - 110, base - 78, base - 34):
        L.paint(L.rect(dx0 + 4, yy, dx1 - 4, yy + 3), hexc("#2c333b"))
    L.paint(L.ellipse(dx1 - 16, base - 72, 4, 4), hexc("#20262c"))
    L.paint(L.rect(dx1 - 24, base - 64, dx1 - 12, base - 52), hexc("#20262c"))  # 挂环
    # 磁卡读头
    L.paint(L.rect(dx1 + 6, base - 110, dx1 + 24, base - 82), hexc("#232a31"))
    L.paint(L.rect(dx1 + 9, base - 106, dx1 + 15, base - 98), hexc("#9fd08a"))  # 指示灯
    L.grime(wall, 59, 0.26)
    L.rust_streaks(wall, 59, 0.3)
    L.snow_cap(x0 + 6, x0 + bw - 6, base - 2, 12, 61, droop=0.5)
    return L.finish(), (w / 2, base)


def med_cache():
    """药箱：朴素白瓶（真药）与花哨商标瓶（掺防冻液的假药）同箱对照——辨药三分法的全部信息。"""
    w, h = 150, 108
    L = Layer(w, h, 3)
    base = 100
    x0 = 12
    top, front = obox(L, x0 + 26, base, 84, 22, 30, "#7d6b4c", "#6e5c40", 71)
    L.paint(L.rect(x0 + 30, base - 22, x0 + 106, base - 20), hexc("#4e412c"))
    # 真药：朴素白瓶（左半）
    for i, xx in enumerate((38, 52, 66)):
        L.paint(L.rect(xx, base - 60 + (i % 2) * 4, xx + 9, base - 26), hexc("#e8e4da"))
        L.paint(L.rect(xx + 1, base - 64 + (i % 2) * 4, xx + 8, base - 58 + (i % 2) * 4),
                hexc("#b9b3a6"))
        L.paint(L.rect(xx + 2, base - 50 + (i % 2) * 4, xx + 7, base - 42 + (i % 2) * 4),
                hexc("#8a94a6"), 0.8)
    # 假药：花哨商标瓶（右半，偏绿的甜腻感）
    for i, xx in enumerate((82, 96, 110)):
        L.paint(L.rect(xx, base - 56 + ((i + 1) % 2) * 4, xx + 10, base - 26),
                hexc("#a9c46a"))
        L.paint(L.rect(xx + 1, base - 60 + ((i + 1) % 2) * 4, xx + 9, base - 54 + ((i + 1) % 2) * 4),
                hexc("#d8e6a2"))
        L.paint(L.rect(xx + 2, base - 46 + ((i + 1) % 2) * 4, xx + 8, base - 34 + ((i + 1) % 2) * 4),
                hexc("#e0552c"), 0.85)                # 花哨商标
    L.paint(L.rect(x0 + 2, base - 8, x0 + 12, base), hexc("#4e412c"))
    L.grime(front, 73, 0.24)
    L.snow_cap(x0 + 26, x0 + 110, base - 30, 8, 75, droop=0.4)
    return L.finish(), (w / 2, base)


def quack_forge():
    """烫鳞炭炉：炭炉 + 烧红的马蹄铁（挂在钳子上）+ 折叠凳 + 烫焦的绷带——只有工具和痕迹。"""
    w, h = 180, 158
    L = Layer(w, h, 3)
    base = 148
    # 炭炉（油桶改的炉子）
    x0, bw, bh = 14, 74, 52
    body = L.poly([(x0, base), (x0 + bw, base), (x0 + bw - 2, base - bh), (x0 + 2, base - bh)])
    L.paint(body, L.tex("#4a4038", 0.12, 5, 81))
    L.shade(body, L.gy(base - bh, base, 1.05, 0.72))
    L.paint(L.rect(x0 + 12, base - bh + 12, x0 + bw - 12, base - bh + 36), hexc("#2a211a"))
    L.paint(L.ellipse(x0 + bw / 2, base - bh + 24, 16, 9), hexc("#e0442e"))      # 炭火
    L.paint(L.ellipse(x0 + bw / 2, base - bh + 24, 9, 5), hexc("#f08a3a"))
    L.paint(L.ellipse(x0 + bw / 2, base - bh + 24, 4, 2), hexc("#ffd9a0"))
    L.rust_streaks(body, 83, 0.42)
    L.grime(body, 83, 0.34)
    L.paint(L.rect(x0 - 3, base - bh - 3, x0 + bw + 3, base - bh + 2), hexc("#2e2822"))
    # 钳子与烧红的马蹄铁
    L.paint(L.line([(x0 + bw - 4, base - bh + 16), (x0 + bw + 46, base - bh + 46)], 5),
            hexc("#3a3f45"))
    hs_x, hs_y = x0 + bw + 52, base - bh + 52
    L.paint(L.arc(hs_x, hs_y, 15, 15, 190, 350, 7), hexc("#8a2f22"))
    L.paint(L.arc(hs_x, hs_y, 15, 15, 195, 345, 4), hexc("#e0442e"))
    L.paint(L.arc(hs_x, hs_y, 15, 15, 205, 335, 2), hexc("#f08a3a"))
    # 折叠凳
    sx, sb = 128, base - 2
    L.paint(L.line([(sx, sb), (sx + 26, sb - 40)], 4), hexc("#5b452c"))
    L.paint(L.line([(sx + 34, sb), (sx + 8, sb - 40)], 4), hexc("#5b452c"))
    L.paint(L.rect(sx + 2, sb - 44, sx + 36, sb - 36), hexc("#6b5138"))
    # 烫焦的绷带与人形灰印（痕迹，不画人）
    L.paint(L.ellipse(46, base + 2, 30, 8), hexc("#2b2723"), 0.55)
    L.paint(L.line([(30, base + 4), (62, base + 1)], 5), hexc("#8a7f6f"), 0.75)
    L.paint(L.line([(34, base + 1), (40, base + 7)], 4), hexc("#5a5148"), 0.8)
    L.paint(L.ellipse(150, base + 4, 12, 5), hexc("#8a7f6f"), 0.6)                # 焦黑绷带
    L.paint(L.line([(142, base + 4), (158, base + 2)], 3), hexc("#4a423a"), 0.8)
    return L.finish(), (w / 2, base)


def radio666():
    """6.66 电台棚：板棚柜台 + 老式短波收音机（指针钉死 + 电子管微绿）+ 天线 + 假药瓶。"""
    w, h = 240, 236
    L = Layer(w, h, 3)
    base = 224
    # 棚板
    x0, bw, bh = 10, 220, 128
    wall = L.poly([(x0 + 6, base), (x0 + bw - 6, base), (x0 + bw - 2, base - bh),
                   (x0 + 2, base - bh)])
    L.paint(wall, L.tex("#5b4a36", 0.11, 6, 91))
    L.shade(wall, L.gy(base - bh, base, 1.05, 0.74))
    roof = L.poly([(x0 - 10, base - bh + 2), (x0 + bw + 10, base - bh + 2),
                   (x0 + bw - 14, base - bh - 22), (x0 + 14, base - bh - 22)])
    L.paint(roof, L.tex("#3a4048", 0.12, 6, 93))
    L.snow_cap(x0 - 8, x0 + bw + 8, base - bh - 22, 38, 95, droop=0.22)
    # 天线（棚顶斜杆 + 拉线）
    ax = x0 + 30
    L.paint(L.line([(ax, base - bh - 20), (ax + 26, base - bh - 88)], 4), hexc("#3a3f45"))
    L.paint(L.line([(ax + 26, base - bh - 88), (x0 + bw - 30, base - bh - 20)], 1.6),
            hexc("#5a6068"), 0.8)
    L.paint(L.ellipse(ax + 26, base - bh - 88, 3, 3), hexc("#5a6068"))
    # 柜台
    L.paint(L.rect(x0 + 18, base - 46, x0 + bw - 18, base - 38), hexc("#6b5138"))
    L.paint(L.rect(x0 + 18, base - 38, x0 + bw - 18, base), hexc("#4c3826"))
    for k in range(4):
        xx = x0 + 30 + k * 48
        L.paint(L.rect(xx, base - 34, xx + 3, base - 4), hexc("#33261a"), 0.7)
    # 收音机（柜台右段）
    rx0, ry0, rw, rh = x0 + 128, base - 118, 82, 72
    L.paint(L.rect(rx0, ry0, rx0 + rw, ry0 + rh), hexc("#4c3826"))
    L.paint(L.rect(rx0 + 4, ry0 + 4, rx0 + rw - 4, ry0 + rh - 4), hexc("#6b5138"))
    L.paint(L.rect(rx0 + 10, ry0 + 12, rx0 + 52, ry0 + 46), hexc("#2b2f2a"))       # 刻度窗
    L.paint(L.rect(rx0 + 6, ry0 + 8, rx0 + 56, ry0 + 50), hexc("#b8c98a"), 0.16)   # 病绿辉光晕
    L.paint(L.rect(rx0 + 13, ry0 + 15, rx0 + 49, ry0 + 43), hexc("#cfe8a6"), 0.95)  # 电子管微绿
    for k in range(6):                              # 刻度
        xx = rx0 + 16 + k * 6.6
        L.paint(L.rect(xx, ry0 + 18, xx + 1, ry0 + 40), hexc("#2b2f2a"), 0.8)
    L.paint(L.rect(rx0 + 38, ry0 + 15, rx0 + 41, ry0 + 43), hexc("#e0552c"))       # 指针钉死
    L.paint(L.ellipse(rx0 + 66, ry0 + 22, 7, 7), hexc("#3a2f22"))                  # 喇叭
    L.paint(L.ellipse(rx0 + 66, ry0 + 22, 4, 4), hexc("#241c13"))
    L.paint(L.ellipse(rx0 + 22, ry0 + 58, 5, 5), hexc("#2b2f2a"))                  # 旋钮
    L.paint(L.ellipse(rx0 + 44, ry0 + 58, 5, 5), hexc("#2b2f2a"))
    L.paint(L.line([(rx0 + 62, ry0 + 52), (rx0 + 76, ry0 + 52)], 3), hexc("#8a7f6f"))
    # 柜台上的假药瓶（花哨商标）
    for i, xx in enumerate((x0 + 30, x0 + 52, x0 + 72)):
        L.paint(L.rect(xx, base - 72 + (i % 2) * 5, xx + 11, base - 46), hexc("#a9c46a"))
        L.paint(L.rect(xx + 2, base - 60 + (i % 2) * 5, xx + 9, base - 48 + (i % 2) * 5),
                hexc("#e0552c"), 0.85)
    L.grime(wall, 97, 0.24)
    L.rust_streaks(wall, 97, 0.12)
    L.snow_cap(x0 + 6, x0 + bw - 6, base - 2, 10, 99, droop=0.5)
    return L.finish(), (w / 2, base)


def card_terminal():
    """磁卡终端：读卡器 + 血红显示屏（在册人数 0 的载体）+ 键盘——全图唯一的红。"""
    w, h = 170, 176
    L = Layer(w, h, 3)
    base = 168
    # 立柱 + 机箱
    L.paint(L.rect(66, 92, 104, base), L.tex("#4e555c", 0.09, 4, 21))
    L.paint(L.ellipse(85, base - 2, 26, 7), hexc("#3a4046"))
    body = L.rect(30, 26, 140, 100, 3)
    L.paint(body, L.tex("#5a6169", 0.09, 4, 23))
    L.shade(body, L.gy(26, 100, 1.1, 0.78))
    L.paint(L.rect(36, 32, 134, 94, 2), hexc("#3f464d"))
    # 血红显示屏（辉光晕 + 红字块——不写字，避免乱码）
    L.paint(L.rect(44, 38, 126, 72), hexc("#2a1210"))
    L.paint(L.rect(40, 34, 130, 76), hexc("#e0442e"), 0.14)     # 辉光晕
    L.paint(L.rect(48, 42, 122, 68), hexc("#e0442e"), 0.9)
    for k in range(4):                                          # 「红字」行
        L.paint(L.rect(52, 45 + k * 6, 52 + (96 if k < 3 else 58), 48 + k * 6),
                hexc("#2a1210"), 0.85)
    # 读卡槽 + 键盘 + 指示灯
    L.paint(L.rect(44, 78, 126, 84), hexc("#22262b"))
    L.paint(L.rect(44, 78, 74, 82), hexc("#0d0f12"))
    for r in range(2):
        for c in range(6):
            L.paint(L.rect(48 + c * 12, 88 + r * 6, 56 + c * 12, 92 + r * 6), hexc("#2b3036"))
    L.paint(L.ellipse(128, 40, 2.4, 2.4), hexc("#9fd08a"))
    # 霜挂
    L.paint(L.rect(30, 26, 140, 30), hexc("#dfe8f0"), 0.5)
    L.paint(L.rect(32, 96, 60, 100), hexc("#dfe8f0"), 0.4)
    L.grime(body, 27, 0.2)
    L.rust_streaks(body, 27, 0.3)
    return L.finish(), (w / 2, base)


def vault_column():
    """冷库立柱：混凝土方柱 + 柱号牌 + 霜挂——3 号柱是全关的证人席。"""
    w, h = 110, 182
    L = Layer(w, h, 3)
    base = 174
    col = L.rect(32, 10, 78, base - 6)
    L.paint(col, L.tex("#7a8590", 0.1, 4, 31))
    L.shade(col, L.gy(10, base - 6, 1.12, 0.74))
    L.paint(L.rect(32, 10, 38, base - 6), hexc("#95a2ad"), 0.5)      # 亮面
    L.paint(L.rect(72, 10, 78, base - 6), hexc("#4c565f"), 0.5)      # 暗面
    # 柱帽 / 柱脚
    L.paint(L.rect(24, 6, 86, 16), hexc("#68737d"))
    L.paint(L.rect(22, base - 14, 88, base - 4), hexc("#68737d"))
    L.paint(L.ellipse(55, base - 2, 34, 7), hexc("#5b6670"))
    # 柱号牌（无字底牌 + 红框——3 号柱由摆位区分）
    L.paint(L.rect(42, 40, 68, 66), hexc("#22262b"))
    L.paint(L.rect(45, 43, 65, 63), hexc("#c9c2a8"))
    L.paint(L.rect(48, 46, 62, 60), hexc("#a03428"), 0.75)
    L.paint(L.rect(51, 49, 59, 57), hexc("#c9c2a8"))
    # 霜挂
    L.paint(L.rect(32, 10, 78, 22), hexc("#dfe8f0"), 0.55)
    for xx in (38, 52, 66, 74):
        L.paint(L.rect(xx, base - 22, xx + 3, base - 8), hexc("#dfe8f0"), 0.4)
    L.grime(col, 33, 0.16)
    return L.finish(), (w / 2, base)


def sealed_med_crate():
    """封存医疗耗材箱：封条 + 红十字 + 霜——「据说封着一批医疗耗材」。"""
    w, h = 150, 118
    L = Layer(w, h, 3)
    base = 110
    top, front = obox(L, 26, base, 88, 24, 32, "#7d8590", "#69727c", 41)
    L.paint(L.rect(30, base - 24, 110, base - 22), hexc("#4e565e"))
    # 封条（十字贴）
    L.paint(L.rect(34, base - 52, 106, base - 44), hexc("#c9c2a8"))
    L.paint(L.rect(64, base - 78, 76, base - 26), hexc("#c9c2a8"))
    L.paint(L.rect(38, base - 50, 102, base - 46), hexc("#a03428"), 0.8)
    L.paint(L.rect(66, base - 74, 74, base - 30), hexc("#a03428"), 0.8)
    # 红十字（漆）
    L.paint(L.rect(44, base - 96, 58, base - 76), hexc("#a03428"))
    L.paint(L.rect(38, base - 90, 64, base - 82), hexc("#a03428"))
    # 霜
    L.paint(L.rect(30, base - 30, 110, base - 24), hexc("#dfe8f0"), 0.35)
    L.grime(front, 43, 0.22)
    L.rust_streaks(front, 43, 0.12)
    L.snow_cap(26, 114, base - 32, 8, 45, droop=0.4)
    return L.finish(), (w / 2, base)


def cold_vault_door():
    """冷库铁门：保温双扇滑门 + 滑轨 + 冰壳——wedge 机关的载体（LOCS：可以撬棍卡死）。"""
    w, h = 300, 226
    L = Layer(w, h, 3)
    base = 218
    # 门框
    L.paint(L.rect(16, 18, 284, base - 2), L.tex("#5a636c", 0.09, 5, 51))
    # 双扇门
    for x0, x1 in ((22, 150), (150, 278)):
        door = L.rect(x0, 26, x1, base - 6)
        L.paint(door, L.tex("#7a8894", 0.11, 5, 53))
        L.shade(door, L.gy(26, base - 6, 1.1, 0.76))
        L.paint(L.rect(x0 + 6, 32, x1 - 6, base - 12), hexc("#8b99a6"), 0.5)
    L.paint(L.rect(146, 26, 154, base - 6), hexc("#4c565f"))           # 中缝
    # 滑轨 + 滑轮
    L.paint(L.rect(10, 12, 290, 22), hexc("#3f464d"))
    for xx in (60, 120, 180, 240):
        L.paint(L.ellipse(xx, 22, 7, 7), hexc("#2b3036"))
        L.paint(L.ellipse(xx, 22, 3, 3), hexc("#6a747d"))
    # 拉手 + 撬棍卡口（wedge 的痕迹位）
    L.paint(L.rect(120, 110, 132, 150), hexc("#3a4046"))
    L.paint(L.rect(168, 110, 180, 150), hexc("#3a4046"))
    L.paint(L.rect(132, 122, 168, 132), hexc("#22262b"))
    L.paint(L.rect(134, 118, 166, 124), hexc("#8a2f22"))               # 卡口的锈痕
    # 冰壳
    L.paint(L.rect(16, 18, 284, 34), hexc("#dfe8f0"), 0.55)
    for xx in range(24, 284, 34):
        L.paint(L.rect(xx, base - 16, xx + 8, base - 4), hexc("#dfe8f0"), 0.35)
    L.rust_streaks(L.rect(16, 18, 284, base - 2), 55, 0.14)
    L.snow_cap(10, 290, base - 4, 10, 57, droop=0.5)
    return L.finish(), (w / 2, base)


def drain_slit():
    """12cm 排水窄缝：墙脚黑缝 + 霜 + 被刮烂的铝饭盒——只有痕迹，不画胳膊。"""
    w, h = 240, 96
    L = Layer(w, h, 3)
    base = 88
    # 墙脚压条
    L.paint(L.rect(8, 18, 232, base - 2), L.tex("#5f6a74", 0.1, 4, 61))
    L.paint(L.rect(8, 18, 232, 26), hexc("#48525b"))
    # 窄缝（12cm 的黑暗）
    L.paint(L.rect(30, 46, 150, 62), hexc("#0c0e11"))
    L.paint(L.rect(30, 42, 150, 48), hexc("#2b3239"))
    # 缝边刮痕（那只胳膊留下的）
    for k in range(4):
        L.paint(L.line([(36 + k * 28, 44), (52 + k * 28, 30)], 2.2), hexc("#95a2ad"), 0.7)
    # 刮烂的铝饭盒
    L.paint(L.rect(170, 52, 216, 80), hexc("#8a919a"))
    L.paint(L.rect(174, 56, 212, 64), hexc("#b9c2cb"))
    L.paint(L.rect(170, 66, 216, 70), hexc("#5b646d"))
    L.paint(L.line([(176, 58), (210, 78)], 2.4), hexc("#4e565e"))
    L.paint(L.line([(184, 54), (206, 76)], 2.0), hexc("#4e565e"))
    L.paint(L.ellipse(193, 66, 4, 3), hexc("#3a4046"))
    # 霜
    L.paint(L.rect(8, base - 12, 232, base - 2), hexc("#dfe8f0"), 0.5)
    L.paint(L.ellipse(90, 70, 60, 8), hexc("#dfe8f0"), 0.35)
    L.grime(L.rect(8, 18, 232, base - 2), 63, 0.22)
    return L.finish(), (w / 2, base)


def cleaver_board():
    """油腻砧板 + 宽背生锈砍骨刀插在上面——「东街锁骨里的砍骨刀」，全关唯一的冷铁高光。"""
    w, h = 170, 124
    L = Layer(w, h, 3)
    base = 116
    # 砧板墩
    L.paint(L.rect(26, base - 34, 144, base - 6), L.tex("#6b4a2c", 0.14, 4, 71))
    L.paint(L.rect(26, base - 40, 144, base - 32), L.tex("#7d5832", 0.12, 4, 73))
    L.paint(L.ellipse(85, base - 4, 60, 8), hexc("#4e381f"))
    # 油腻（深渍 + 反光油斑）
    L.paint(L.ellipse(70, base - 36, 26, 6), hexc("#3c2a16"), 0.7)
    L.paint(L.ellipse(108, base - 35, 14, 4), hexc("#2e2113"), 0.6)
    L.paint(L.ellipse(58, base - 37, 8, 3), hexc("#8a6a3c"), 0.5)
    # 宽背生锈砍骨刀（刀刃向下插进墩面）
    L.paint(L.poly([(66, base - 96), (104, base - 100), (108, base - 40), (70, base - 36)]),
            L.tex("#7a5236", 0.2, 3, 77))                       # 锈板
    L.paint(L.poly([(70, base - 44), (104, base - 48), (102, base - 38), (72, base - 34)]),
            hexc("#9aa4ad"))                                     # 刃口冷光
    L.paint(L.line([(72, base - 42), (102, base - 46)], 2.2), hexc("#c8d2da"))
    L.paint(L.rect(78, 5, 92, base - 92), hexc("#3a2a1a"))  # 木柄
    L.paint(L.rect(80, 7, 90, 11), hexc("#5a442c"))
    L.paint(L.ellipse(85, 9, 3, 3), hexc("#241a10"))
    # 干渍（麦糊与血的混合）
    L.paint(L.ellipse(120, base - 40, 10, 4), hexc("#5a2c1c"), 0.55)
    L.grime(L.rect(26, base - 40, 144, base - 6), 40, 0.3)
    L.rust_streaks(L.rect(26, base - 40, 144, base - 6), 41, 0.14)
    return L.finish(), (w / 2, base)


def canteen_stove():
    """铸铁食堂灶：灶台 + 两口大锅 + 火口——费奥多尔守着的那口气。"""
    w, h = 220, 186
    L = Layer(w, h, 3)
    base = 178
    body = L.rect(24, 66, 196, base - 6)
    L.paint(body, L.tex("#4a4e54", 0.12, 5, 81))
    L.shade(body, L.gy(66, base - 6, 1.1, 0.76))
    # 灶面
    L.paint(L.rect(16, 56, 204, 70), hexc("#5b6067"))
    L.paint(L.rect(16, 56, 204, 60), hexc("#6d747c"))
    # 两口锅
    for cx, r in ((66, 30), (140, 26)):
        L.paint(L.ellipse(cx, 52, r, 12), hexc("#2b3036"))
        L.paint(L.ellipse(cx, 46, r - 4, 10), hexc("#3f464d"))
        L.paint(L.ellipse(cx, 42, r - 10, 7), hexc("#8a6a3c"))      # 锅里的糊
        L.paint(L.ellipse(cx - r + 6, 40, 5, 4), hexc("#5b6067"))   # 锅耳
        L.paint(L.ellipse(cx + r - 6, 40, 5, 4), hexc("#5b6067"))
    # 火口（暖光核心——sprite 自带，灯光由 rig 补）
    L.paint(L.rect(60, 96, 150, 132), hexc("#181a1d"))
    L.paint(L.ellipse(105, 118, 34, 12), hexc("#c96a24"))
    L.paint(L.ellipse(105, 116, 22, 8), hexc("#e8a44e"))
    L.paint(L.ellipse(105, 114, 10, 4), hexc("#f6d9a0"))
    # 炉门 / 灰坑 / 烟囱
    L.paint(L.rect(32, 138, 96, 168), hexc("#2b3036"))
    for k in range(3):
        L.paint(L.rect(38, 144 + k * 8, 90, 148 + k * 8), hexc("#101214"))
    L.paint(L.rect(160, 6, 190, 60), hexc("#3a4046"))
    L.paint(L.rect(160, 6, 166, 60), hexc("#555c63"))
    # 油污渍
    L.grime(body, 85, 0.3)
    L.paint(L.ellipse(150, base - 12, 22, 5), hexc("#2e2113"), 0.5)
    return L.finish(), (w / 2, base)


def _canteen_table(with_bowls: bool):
    """长条桌 + 长凳。with_bowls=True → 一排 19 只搪瓷碗（「十九只碗」的载体 = 主桌）；
    False → 光板桌（另两条桌——碗都端在主桌那一排）。"""
    w, h = 340, 132
    L = Layer(w, h, 3)
    base = 124
    # 长凳（北侧一条在桌后、南侧一条在桌前 + 南凳腿）
    L.paint(L.rect(18, base - 68, 322, base - 60), L.tex("#6b4a2c", 0.13, 4, 91))
    L.paint(L.rect(18, base - 22, 322, base - 14), L.tex("#6b4a2c", 0.13, 4, 91))
    for lx in (34, 160, 296):
        L.paint(L.rect(lx, base - 14, lx + 10, base), hexc("#4e381f"))
    # 桌面
    top = L.rect(10, base - 58, 330, base - 30)
    L.paint(top, L.tex("#7d5832", 0.12, 4, 93))
    L.shade(top, L.gy(base - 58, base - 30, 1.08, 0.82))
    L.paint(L.rect(10, base - 58, 330, base - 54), hexc("#8a6438"))
    for lx in (34, 160, 296):
        L.paint(L.rect(lx, base - 30, lx + 10, base), hexc("#5b4226"))
    if with_bowls:
        # 搪瓷碗一排 19 只（缺口朝外）——「账面已清空的老楼，可里面还有十九只碗」
        for i in range(19):
            bx = 18 + i * 17
            L.paint(L.ellipse(bx, base - 44, 7, 5), hexc("#c9c2a8"))
            L.paint(L.ellipse(bx, base - 46, 5, 3), hexc("#2b3036"))
            L.paint(L.ellipse(bx, base - 46, 5, 3), hexc("#5a4a34"), 0.85)   # 碗里的糊
            L.paint(L.rect(bx - 7, base - 45, bx - 5, base - 42), hexc("#2b3036"))  # 缺口
    L.grime(top, 55, 0.18)
    L.snow_cap(10, 330, base - 58, 6, 95, droop=0.2)
    return L.finish(), (w / 2, base)


def canteen_table():
    """十九只碗的长条桌（主桌 Table2——碗全在这一排）。"""
    return _canteen_table(True)


def canteen_bench_table():
    """光板长条桌 + 长凳（Table1 / Table3——十九只碗都端在主桌那一排）。"""
    return _canteen_table(False)


# ---------------------------------------------------------------------------
# sanitarium：旧传染病疗养院 · 地下室（PRP_IronCage / PRP_CageBed / PRP_CageGate /
# PRP_MedCabinet / PRP_XrayLightbox / PRP_ChemDrum）
# ---------------------------------------------------------------------------

def iron_cage():
    """钢筋铁笼（灰鳞病回退区的关人笼）：竖栏 + 顶框 + 底座 + 挂链锁。"""
    w, h = 176, 136
    L = Layer(w, h, 3)
    base = 128
    # 底座
    L.paint(L.rect(10, base - 12, 166, base), hexc("#3c4148"))
    L.paint(L.rect(14, base - 8, 162, base - 4), hexc("#2b3036"))
    # 顶框
    L.paint(L.rect(10, base - 116, 166, base - 104), hexc("#5a636c"))
    L.paint(L.rect(10, base - 116, 166, base - 112), hexc("#8a919a"))
    # 竖栏
    for bx in range(18, 166, 14):
        L.paint(L.rect(bx, base - 104, bx + 5, base - 12), hexc("#6a747d"))
        L.paint(L.rect(bx + 4, base - 104, bx + 5, base - 12), hexc("#48525b"))
    # 中横撑
    L.paint(L.rect(10, base - 72, 166, base - 66), hexc("#5a636c"))
    # 门缝（中开双扇）
    L.paint(L.rect(84, base - 104, 92, base - 12), hexc("#3c4148"))
    # 挂链锁
    L.paint(L.rect(86, base - 58, 98, base - 44), hexc("#8a919a"))
    L.paint(L.rect(88, base - 56, 96, base - 46), hexc("#241a10"))
    for cy in (base - 44, base - 38, base - 32):
        L.paint(L.ellipse(92, cy, 4, 3), hexc("#6a747d"))
    # 锈痕
    for rx in (30, 72, 120, 150):
        L.paint(L.rect(rx, base - 100, rx + 6, base - 40), hexc("#5c4432"), 0.28)
    L.grime(L.rect(10, base - 12, 166, base), 40, 0.3)
    L.snow_cap(10, 166, base - 116, 5, 90, droop=0.12)
    return L.finish(), (w / 2, base)


def cage_bed():
    """铁架床 + 两根旧皮带（安娜 0419 把自己捆在这里熬过神经风暴）。"""
    w, h = 190, 124
    L = Layer(w, h, 3)
    base = 116
    # 床头竖栏（北）
    L.paint(L.rect(14, base - 84, 24, base - 20), hexc("#6a747d"))
    L.paint(L.rect(166, base - 70, 176, base - 20), hexc("#6a747d"))
    for bx in (30, 46, 62):
        L.paint(L.rect(bx, base - 80, bx + 5, base - 46), hexc("#5a636c"))
    for bx in (126, 142, 158):
        L.paint(L.rect(bx, base - 66, bx + 5, base - 46), hexc("#5a636c"))
    # 床架 + 垫
    L.paint(L.rect(14, base - 46, 176, base - 32), hexc("#48525b"))
    L.paint(L.rect(18, base - 58, 172, base - 42), L.tex("#7a7466", 0.14, 4, 41))
    L.paint(L.rect(18, base - 58, 172, base - 52), hexc("#8a8474"))
    # 破毯
    L.paint(L.rect(60, base - 62, 120, base - 44), hexc("#4a3f36"))
    L.paint(L.poly([(110, base - 62), (132, base - 54), (126, base - 44), (104, base - 46)]),
            hexc("#3c332c"))
    # 床腿
    for lx in (18, 168):
        L.paint(L.rect(lx, base - 32, lx + 8, base), hexc("#5a636c"))
    # ★ 两根旧皮带（捆在栏杆上——钱道具的细节）
    for sx, sy in ((40, base - 62), (40, base - 52)):
        L.paint(L.rect(sx, sy, sx + 46, sy + 6), hexc("#6b4a2c"))
        L.paint(L.rect(sx + 42, sy - 1, sx + 50, sy + 7), hexc("#8a6438"))  # 扣头
    L.paint(L.rect(36, base - 66, 48, base - 48), hexc("#7a5634"))         # 缠绕的带头
    L.paint(L.rect(84, base - 68, 96, base - 50), hexc("#7a5634"))
    L.grime(L.rect(14, base - 46, 176, base - 32), 36, 0.22)
    return L.finish(), (w / 2, base)


def cage_gate():
    """笼区铁栅门（wedge 机关载体）：对开栅门 + 插销 + 撬棍卡口。"""
    w, h = 220, 150
    L = Layer(w, h, 3)
    base = 142
    # 门框
    L.paint(L.rect(8, base - 132, 24, base), hexc("#48525b"))
    L.paint(L.rect(196, base - 132, 212, base), hexc("#48525b"))
    L.paint(L.rect(8, base - 132, 212, base - 118), hexc("#5a636c"))
    # 栅扇
    for bx in range(32, 196, 16):
        L.paint(L.rect(bx, base - 118, bx + 6, base - 8), hexc("#6a747d"))
        L.paint(L.rect(bx + 5, base - 118, bx + 6, base - 8), hexc("#48525b"))
    # 中缝双扇
    L.paint(L.rect(104, base - 118, 116, base - 8), hexc("#3c4148"))
    # 横撑两道
    L.paint(L.rect(24, base - 92, 196, base - 86), hexc("#5a636c"))
    L.paint(L.rect(24, base - 40, 196, base - 34), hexc("#5a636c"))
    # 插销 + 锁
    L.paint(L.rect(88, base - 84, 132, base - 72), hexc("#8a919a"))
    L.paint(L.rect(92, base - 82, 128, base - 74), hexc("#241a10"))
    L.paint(L.rect(112, base - 100, 128, base - 86), hexc("#8a919a"))
    # 撬棍卡口（底横梁上的缺口）
    L.paint(L.poly([(150, base - 22), (174, base - 22), (168, base - 8), (156, base - 8)]),
            hexc("#241a10"))
    L.paint(L.poly([(152, base - 20), (172, base - 20), (167, base - 11), (157, base - 11)]),
            hexc("#5c4432"))
    L.grime(L.rect(8, base - 8, 212, base), 30, 0.3)
    L.snow_cap(8, 212, base - 132, 5, 90, droop=0.12)
    return L.finish(), (w / 2, base)


def med_cabinet():
    """药柜（guaranteed asp）：钢药柜 + 开着的柜门 + 药瓶层板 + 红十字。"""
    w, h = 150, 156
    L = Layer(w, h, 3)
    base = 148
    # 柜体
    L.paint(L.rect(16, base - 128, 134, base), L.tex("#8a919a", 0.09, 4, 61))
    L.shade(L.rect(16, base - 128, 134, base), L.gy(base - 128, base, 1.06, 0.78))
    # 顶檐
    L.paint(L.rect(12, base - 134, 138, base - 126), hexc("#6a747d"))
    # 左门（关）+ 红十字
    L.paint(L.rect(20, base - 122, 66, base - 8), hexc("#9aa1a8"))
    L.paint(L.rect(40, base - 100, 48, base - 60), hexc("#b0472c"))
    L.paint(L.rect(30, base - 88, 58, base - 72), hexc("#b0472c"))
    L.paint(L.rect(58, base - 62, 64, base - 56), hexc("#241a10"))   # 拉手
    # 右门（开）+ 内层板与药瓶
    L.paint(L.poly([(70, base - 122), (128, base - 114), (128, base - 2), (70, base - 8)]),
            hexc("#2b3036"))
    for py_ in (base - 108, base - 74, base - 40):
        L.paint(L.rect(74, py_, 124, py_ + 4), hexc("#48525b"))
        for bx in (80, 96, 112):
            L.paint(L.rect(bx, py_ - 12, bx + 9, py_), hexc("#c9c2a8"), 0.9)   # 药瓶
            L.paint(L.rect(bx + 2, py_ - 11, bx + 7, py_ - 5), hexc("#d8b25a"), 0.8)
            L.paint(L.rect(bx + 2, py_ - 4, bx + 7, py_ - 1), hexc("#b0472c"), 0.7)
    L.paint(L.poly([(128, base - 114), (142, base - 108), (142, base + 2), (128, base - 2)]),
            hexc("#7c828a"))                                              # 开着的门板
    L.grime(L.rect(16, base - 12, 134, base), 30, 0.26)
    L.snow_cap(12, 138, base - 134, 4, 88, droop=0.1)
    return L.finish(), (w / 2, base)


def xray_lightbox():
    """读片灯箱（briefcase 类 intel 容器）：灯箱 + 挂着的胸片 + 卡夹 + 病历。"""
    w, h = 180, 148
    L = Layer(w, h, 3)
    base = 140
    # 箱体
    L.paint(L.rect(14, base - 116, 166, base - 22), hexc("#48525b"))
    L.paint(L.rect(22, base - 108, 158, base - 30), hexc("#dfe8f0"))
    L.paint(L.rect(22, base - 108, 158, base - 68), hexc("#f2f7fb"), 0.7)
    # 胸片（挂在灯箱上：肋骨条 + 脊柱）
    L.paint(L.rect(48, base - 102, 132, base - 38), hexc("#2b3036"), 0.92)
    L.paint(L.rect(52, base - 98, 128, base - 42), hexc("#5a6570"), 0.95)
    for ry_ in range(base - 94, base - 48, 8):
        L.paint(L.rect(56, ry_, 124, ry_ + 2), hexc("#8a919a"), 0.8)
    L.paint(L.rect(84, base - 98, 96, base - 42), hexc("#aab0b6"), 0.85)
    # 卡夹 + 病历纸
    L.paint(L.rect(84, base - 116, 96, base - 106), hexc("#8a919a"))
    L.paint(L.rect(24, base - 30, 70, base - 22), hexc("#c9c2a8"))
    L.paint(L.rect(24, base - 38, 60, base - 30), hexc("#d8cdb4"))
    # 支脚
    for lx in (28, 148):
        L.paint(L.rect(lx, base - 22, lx + 8, base), hexc("#3c4148"))
    L.grime(L.rect(14, base - 22, 166, base - 14), 24, 0.24)
    return L.finish(), (w / 2, base)


def chem_drum():
    """石灰 / 消毒桶：鼓身 + 石灰渍 + 铁勺 + 撒粉。"""
    w, h = 130, 138
    L = Layer(w, h, 3)
    base = 130
    # 鼓身
    L.paint(L.rect(24, base - 102, 106, base), L.tex("#6a747d", 0.11, 4, 71))
    L.shade(L.rect(24, base - 102, 106, base), L.gy(base - 102, base, 1.1, 0.72))
    # 桶沿 + 环箍
    L.paint(L.ellipse(65, base - 102, 42, 10), hexc("#8a919a"))
    L.paint(L.ellipse(65, base - 102, 36, 7), hexc("#c9c2a8"))       # 石灰面
    L.paint(L.ellipse(65, base - 100, 22, 4), hexc("#eef3f8"), 0.8)
    for hy_ in (base - 78, base - 40):
        L.paint(L.rect(24, hy_, 106, hy_ + 5), hexc("#48525b"))
    # 字标（色块，不写可读字）
    L.paint(L.rect(38, base - 70, 52, base - 52), hexc("#b0472c"), 0.85)
    L.paint(L.rect(43, base - 66, 47, base - 56), hexc("#e8e0cc"), 0.9)
    # 铁勺 + 撒粉
    L.paint(L.rect(88, base - 118, 94, base - 96), hexc("#8a919a"))
    L.paint(L.ellipse(91, base - 120, 8, 5), hexc("#c9c2a8"))
    L.paint(L.ellipse(40, base - 8, 18, 6), hexc("#eef3f8"), 0.75)
    L.paint(L.ellipse(96, base - 6, 12, 4), hexc("#eef3f8"), 0.6)
    L.grime(L.rect(24, base - 20, 106, base), 26, 0.28)
    return L.finish(), (w / 2, base)


def narrow_door():
    """杂物间单向窄门：门框新裂 + 门板内倾——wedge 机关的载体（「窄门会被冲开」）。"""
    w, h = 180, 196
    L = Layer(w, h, 3)
    base = 188
    # 门框（裂）
    L.paint(L.rect(22, 12, 158, base - 4), L.tex("#5b4226", 0.14, 4, 97))
    L.paint(L.rect(22, 12, 34, base - 4), hexc("#4e381f"))
    L.paint(L.rect(146, 12, 158, base - 4), hexc("#4e381f"))
    L.paint(L.poly([(22, 12), (158, 12), (152, 22), (28, 22)]), hexc("#3c2a16"))
    # 门板（向内倾 = 被撞过）
    door = L.rect(40, 24, 140, base - 10)
    L.paint(door, L.tex("#6b4a2c", 0.16, 4, 99))
    L.shade(door, L.gy(24, base - 10, 1.06, 0.8))
    for k in range(3):
        L.paint(L.line([(44, 44 + k * 42), (136, 40 + k * 42)], 3), hexc("#4e381f"), 0.7)
    # 裂缝 + 破洞（撞出来的）
    L.paint(L.line([(96, 26), (88, 90), (100, 120), (92, base - 12)], 3), hexc("#241a10"))
    L.paint(L.ellipse(104, 96, 16, 12), hexc("#181a1d"))
    L.paint(L.ellipse(104, 96, 12, 9), hexc("#0c0e11"))
    # 门闩（已被撬棍卡过的位置）
    L.paint(L.rect(118, 92, 146, 102), hexc("#3a4046"))
    L.paint(L.rect(118, 92, 124, 102), hexc("#22262b"))
    L.grime(door, 60, 0.26)
    L.rust_streaks(door, 61, 0.12)
    L.snow_cap(22, 158, base - 4, 8, 101, droop=0.5)
    return L.finish(), (w / 2, base)


def rye_vat():
    """黑麦糊大桶：木桶 + 铁箍 + 长柄勺——十九个人的晚饭，还温着。"""
    w, h = 140, 148
    L = Layer(w, h, 3)
    base = 140
    body = L.rect(30, 36, 110, base - 6)
    L.paint(body, L.tex("#6b4a2c", 0.14, 4, 103))
    L.shade(body, L.gy(36, base - 6, 1.1, 0.78))
    for y0 in (52, 96):
        L.paint(L.rect(26, y0, 114, y0 + 8), hexc("#3a4046"))
        L.paint(L.rect(26, y0, 114, y0 + 3), hexc("#555c63"))
    # 桶口（糊面）
    L.paint(L.ellipse(70, 38, 42, 13), hexc("#4e381f"))
    L.paint(L.ellipse(70, 34, 36, 10), hexc("#2b2418"))
    L.paint(L.ellipse(70, 32, 30, 8), hexc("#5a4a34"))
    L.paint(L.ellipse(58, 30, 9, 4), hexc("#6b5a3e"))     # 糊面反光
    # 长柄勺
    L.paint(L.line([(96, 30), (122, 8)], 5), hexc("#5b4226"))
    L.paint(L.ellipse(124, 8, 8, 6), hexc("#3a4046"))
    # 热气痕（画两笔淡雾）
    L.paint(L.ellipse(60, 14, 12, 6), hexc("#c9c2a8"), 0.18)
    L.paint(L.ellipse(84, 10, 10, 5), hexc("#c9c2a8"), 0.14)
    L.grime(body, 75, 0.24)
    L.snow_cap(30, 110, base - 6, 7, 105, droop=0.4)
    return L.finish(), (w / 2, base)


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
    "PRP_Shanty_Shed": shanty_shed,
    "PRP_MedShed": med_shed,
    "PRP_MedCache": med_cache,
    "PRP_QuackForge": quack_forge,
    "PRP_Radio666": radio666,
    "PRP_CardTerminal": card_terminal,
    "PRP_VaultColumn": vault_column,
    "PRP_SealedMedCrate": sealed_med_crate,
    "PRP_ColdVaultDoor": cold_vault_door,
    "PRP_DrainSlit": drain_slit,
    "PRP_CleaverBoard": cleaver_board,
    "PRP_Canteen_Stove": canteen_stove,
        "PRP_Canteen_Table": canteen_table,
        "PRP_Canteen_BenchTable": canteen_bench_table,
        "PRP_IronCage": iron_cage,
        "PRP_CageBed": cage_bed,
        "PRP_CageGate": cage_gate,
        "PRP_MedCabinet": med_cabinet,
        "PRP_XrayLightbox": xray_lightbox,
        "PRP_ChemDrum": chem_drum,
    "PRP_NarrowDoor": narrow_door,
    "PRP_RyeVat": rye_vat,
    "PRP_Buran_Boxcar03": boxcar,
    "PRP_WaterTower": water_tower,
    "PRP_Watchtower_Searchlight": watchtower,
    "PRP_SignalPost_Red": signal_post,
    "PRP_TinCan": tin_can,
    "PRP_BrakeVan_Dead": brake_van,
    "PRP_SwitchStand": switch_stand,
    "PRP_DispatchBoard_Tin": dispatch_board,
    "PRP_Pine_Snow": pine_snow,
    "PRP_ColdStore_Chest": cold_chest,
    "PRP_Forklift_Parked": forklift,
    "PRP_Incinerator_Feed": incinerator_feed,
    "PRP_OreCart_Rusty": ore_cart,
    "PRP_Timber_Support": timber_support,
    "PRP_Thermite_Charge": thermite_charge,
    "PRP_Detonator_Rig": detonator_rig,
    "PRP_SporeFace": spore_face,
    "PRP_DummyTower_Mannequin": dummy_tower,
}
FENCES = {"a": "PRP_Fence_ChainLink_A", "b": "PRP_Fence_ChainLink_B", "torn": "PRP_Fence_ChainLink_Torn",
          "torn_l": "PRP_Fence_ChainLink_TornL",
          "elec": "PRP_Fence_Electric_A", "elec_cut": "PRP_Fence_Electric_Cut"}
