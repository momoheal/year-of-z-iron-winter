"""武器 / 弹药 / 靶场道具 + 战斗 VFX（P5 战斗切片）。

设计口径与 gen_props 一致：
  * 1 逻辑米 = 64 px（立面不压缩），精灵 pivot 由各函数返回；
  * 阴天中性冷光上色，夜色交给引擎的 CanvasModulate + 2D 灯光；
  * 「苏联重工业」质感：烤蓝钢 + 旧木 + 铆钉 + 雪 + 锈，不许出现塑料感。

新增资产（命名遵循《美术资源生成 Prompt 规格书》§3.3）：
    PRP_Crowbar_Rail        铸铁道钉撬棍（阿列克谢的起手武器）
    PRP_Pistol_TT           ТТ-33 手枪
    PRP_Rifle_Mosin         莫辛纳甘步枪
    PRP_Shotgun_Sawn        截短双管猎枪
    PRP_Ammo_Box_Open       掀开的弹药箱（可搜刮：必出步枪弹）
    PRP_Sandbag_Line        沙袋掩体（低矮掩体，蹲下挡视线）
    PRP_WeaponRack          武器架（卫兵室 / 靶场）
    PRP_Target_Silhouette   木靶人（靶场 / 灰盒标定）
    VFX_MuzzleFlash_Sheet   枪口焰 4 帧
    VFX_Bullet_Tracer       曳光
    VFX_Impact_Spark        弹着火星
    VFX_Shell_Casing        弹壳
    VFX_Blood_Mist          血雾
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image

from artlib import GY, PPM, Layer, hexc, lerp, vnoise

STEEL = "#3b4044"          # 烤蓝钢
STEEL_LIT = "#5d6467"
STEEL_DARK = "#2a2e31"
RUST = "#6a4a2a"
WOOD = "#6b4a30"
WOOD_DARK = "#4a3320"
BRASS = "#b08a44"
SNOW = "#dfe8f0"


# ---------------------------------------------------------------------------
# 小工具
# ---------------------------------------------------------------------------
def _fit(img: Image, piv, target_w: float):
    """把精灵缩到真实世界尺寸：1m = 64px。pivot 按同一比例缩放。"""
    k = target_w / float(img.width)
    out = img.resize((max(1, int(round(img.width * k))), max(1, int(round(img.height * k)))), Image.LANCZOS)
    return out, (piv[0] * k, piv[1] * k)


def _soft(L: Layer, cx: float, cy: float, r: float, col, amp: float = 1.0, rings: int = 7) -> None:
    """由外向内叠半透明椭圆：没有高斯模糊也能出柔和的光。"""
    for i in range(rings, 0, -1):
        k = i / float(rings)
        L.paint(L.ellipse(cx, cy, r * k, r * k), col, amp * (1.0 - k) * 0.55 + amp * 0.06)


def _grip(L: Layer, x0, y0, x1, y1, w, col_a, col_b, seed=0) -> None:
    """带木纹的一段枪身。"""
    m = L.poly([(x0, y0), (x1, y1), (x1, y1 + w), (x0, y0 + w)])
    L.paint(m, L.tex(col_a, 0.07, 4, seed))
    L.shade(m, L.gy(min(y0, y1), max(y0, y1) + w, 1.06, 0.82))
    L.tint(m, hexc(col_b), 0.18)


# ---------------------------------------------------------------------------
# 武器
# ---------------------------------------------------------------------------
def crowbar():
    """铸铁道钉撬棍：一根 1.3m 的方钢，一头锻成钩爪，另一头是扁凿。"""
    w, h = 108, 82
    L = Layer(w, h, 3)
    a, b = (12, 68), (86, 20)
    L.paint(L.line([a, b], 7.4), L.tex(STEEL, 0.09, 5, 3))
    L.paint(L.line([a, b], 3.0), hexc(STEEL_LIT), 0.35)
    # 扁凿（左下）
    L.paint(L.poly([(10, 74), (18, 62), (26, 66), (16, 78)]), L.tex(STEEL_DARK, 0.08, 3, 5))
    # 钩爪（右上）：弯钩 + 起钉口
    L.paint(L.arc(86, 20, 13, 11, -70, 150, 7.0), L.tex(STEEL, 0.1, 4, 7))
    L.paint(L.arc(86, 20, 13, 11, -70, 150, 3.2), hexc(STEEL_LIT), 0.4)
    L.paint(L.poly([(96, 8), (104, 4), (106, 9), (99, 13)]), L.tex(STEEL_DARK, 0.08, 3, 8))
    # 铁锈 + 崩口
    L.rust_streaks(L.rect(8, 10, 108, 80), seed=11, amt=0.35, color=RUST, cell=(9, 5))
    for (x, y) in [(34, 56), (58, 40), (70, 30)]:
        L.paint(L.ellipse(x, y, 2.6, 1.6), hexc(RUST), 0.7)
    L.paint(L.line([(46, 46), (66, 32)], 1.2), hexc("#8b9094"), 0.35)
    return L.finish(), (54, h - 6)


def pistol_tt():
    """ТТ-33：短行程枪管、单排弹匣、棕胶木握把。"""
    w, h = 104, 68
    L = Layer(w, h, 3)
    base_y = h - 6
    # 套筒（前后等宽，前端削一点）
    slide = L.poly([(20, 16), (94, 15), (100, 19), (100, 28), (20, 29)])
    L.paint(slide, L.tex(STEEL, 0.06, 4, 21))
    L.shade(slide, L.gy(15, 29, 1.16, 0.84))
    L.paint(L.rect(22, 18, 96, 21), hexc(STEEL_LIT), 0.18)                 # 顶部高光
    L.paint(L.rect(94, 19, 101, 27), L.tex(STEEL_DARK, 0.05, 3, 22))       # 枪口套
    L.paint(L.ellipse(100, 23, 2.2, 2.6), hexc("#101416"), 0.95)           # 枪口
    L.paint(L.rect(88, 13, 92, 17), hexc(STEEL_LIT), 0.55)                 # 准星
    # 后照门 + 防滑纹
    L.paint(L.rect(30, 13, 40, 16), hexc(STEEL_DARK), 0.9)
    for k in range(5):
        x = 34 + k * 4
        L.paint(L.line([(x, 24), (x + 2, 28)], 1.1), hexc(STEEL_DARK), 0.55)
    # 机匣 / 扳机 / 护圈
    L.paint(L.rect(26, 29, 80, 38), L.tex(STEEL_DARK, 0.07, 4, 23))
    L.paint(L.arc(52, 38, 13, 9, 0, 180, 3.6), hexc(STEEL), 0.95)
    L.paint(L.poly([(48, 33), (56, 33), (55, 42), (47, 42)]), hexc("#191d1f"), 0.95)
    # 握把（后倾）
    grip = L.poly([(26, 36), (48, 35), (41, base_y), (17, base_y)])
    L.paint(grip, L.tex("#5b3a22", 0.08, 4, 24))
    L.shade(grip, L.gy(35, base_y, 1.14, 0.76))
    L.paint(L.poly([(26, 36), (30, 36), (23, base_y), (17, base_y)]), hexc("#432a18"), 0.7)
    for k in range(4):
        y = 44 + k * 5
        L.paint(L.line([(23 + k * 0.5, y), (45 - k * 0.5, y - 1)], 1.1), hexc("#3a2414"), 0.75)
    L.paint(L.arc(34, 60, 5, 4, 200, 340, 1.6), hexc("#2b1a10"), 0.7)      # 握把底
    L.grime(L.rect(18, 12, 101, base_y), seed=25, amt=0.22, cell=6)
    return L.finish(), (30, base_y)


def rifle_mosin():
    """莫辛纳甘 M91/30：长木托 + 直拉机柄，枪身 1.23m。"""
    w, h = 208, 48
    L = Layer(w, h, 3)
    base_y = h - 6
    # 枪托：托底高、往里收，前段是细护木
    butt = L.poly([(8, 23), (17, 22), (18, 42), (8, 41)])
    L.paint(butt, L.tex(WOOD_DARK, 0.08, 4, 30))
    stock = L.poly([(16, 22), (128, 24), (152, 26), (152, 32), (124, 32),
                    (96, 34), (92, 42), (64, 42), (18, 40)])
    L.paint(stock, L.tex(WOOD, 0.08, 5, 31))
    L.shade(stock, L.gy(19, 42, 1.14, 0.74))
    L.rim(stock, 0, -1.0, "#8d6a44", 0.35)
    # 枪管（从护木上沿一直伸到枪口）
    L.paint(L.rect(60, 16, 200, 22), L.tex(STEEL_DARK, 0.06, 4, 32))
    L.paint(L.rect(62, 16, 196, 18), hexc(STEEL), 0.55)
    L.paint(L.rect(196, 15, 204, 23), L.tex(STEEL_DARK, 0.05, 3, 33))      # 枪口套
    L.paint(L.ellipse(203, 19, 1.8, 2.4), hexc("#0f1315"), 0.95)
    # 上护木（枪管上方一圈木）
    L.paint(L.poly([(118, 13), (168, 13), (168, 17), (118, 17)]), L.tex(WOOD, 0.07, 4, 34))
    # 表尺 + 准星
    L.paint(L.rect(150, 9, 162, 14), hexc(STEEL_DARK), 0.92)
    L.paint(L.rect(190, 11, 194, 16), hexc(STEEL_LIT), 0.75)
    # 机匣 / 直拉机柄 / 弹仓 / 扳机护圈
    L.paint(L.rect(88, 20, 124, 31), L.tex(STEEL, 0.06, 4, 35))
    L.paint(L.line([(112, 26), (126, 33)], 3.2), hexc(STEEL_LIT), 0.9)
    L.paint(L.ellipse(127, 34, 3.4, 3.4), hexc(STEEL_LIT), 0.95)
    L.paint(L.rect(96, 31, 118, 38), hexc(STEEL_DARK), 0.95)
    L.paint(L.arc(88, 38, 9, 6, 0, 180, 2.8), hexc(STEEL), 0.9)
    L.paint(L.poly([(86, 34), (92, 34), (90, 41), (85, 41)]), hexc("#16191b"), 0.9)
    # 背带 + 托底钢板
    L.paint(L.line([(20, 34), (146, 29)], 2.6), hexc("#3a3026"), 0.8)
    L.paint(L.rect(6, 20, 9, 42), hexc(STEEL_DARK), 0.85)
    L.grime(L.rect(4, 8, 208, base_y), seed=36, amt=0.2, cell=7)
    return L.finish(), (88, base_y)


def shotgun_sawn():
    """截短双管：枪管锯到 30cm，木握把，近距离一枪能把人掀翻。"""
    w, h = 132, 58
    L = Layer(w, h, 3)
    base_y = h - 8
    # 双管
    L.paint(L.rect(44, 14, 124, 34), L.tex(STEEL, 0.07, 4, 41))
    L.shade(L.rect(44, 14, 124, 34), L.gy(14, 34, 1.15, 0.82))
    L.paint(L.line([(46, 24), (122, 24)], 1.6), hexc(STEEL_DARK), 0.9)
    L.paint(L.ellipse(122, 19, 3.0, 3.4), hexc("#14181a"), 0.95)             # 两个枪口
    L.paint(L.ellipse(122, 29, 3.0, 3.4), hexc("#14181a"), 0.95)
    L.paint(L.rect(44, 16, 122, 18), hexc(STEEL_LIT), 0.28)
    # 铰链 + 护木
    L.paint(L.rect(40, 12, 56, 36), L.tex(STEEL_DARK, 0.06, 4, 42))
    L.paint(L.rect(30, 20, 48, 34), L.tex(WOOD, 0.08, 4, 43))
    # 握把
    L.paint(L.poly([(26, 28), (44, 26), (36, base_y), (14, base_y)]), L.tex(WOOD, 0.08, 4, 44))
    L.shade(L.poly([(26, 28), (44, 26), (36, base_y), (14, base_y)]), L.gy(26, base_y, 1.1, 0.8))
    # 扳机
    L.paint(L.arc(34, 36, 6, 5, 0, 200, 2.4), hexc(STEEL_LIT), 0.9)
    L.grime(L.rect(12, 10, 126, base_y), seed=45, amt=0.22, cell=6)
    return L.finish(), (28, base_y)


# ---------------------------------------------------------------------------
# 弹药 / 靶场道具
# ---------------------------------------------------------------------------
def ammo_box_open():
    """掀开的军用弹药箱：木箱 + 铁包角，里面立着几排步枪弹。"""
    w, h = 104, 84
    L = Layer(w, h, 3)
    base = h - 6
    x0, bw, d, bh = 10, 84, 26, 34
    # 箱体
    top, front = _obox_simple(L, x0, base, bw, d, bh, "#55603f", "#4a5334", 51)
    # 掀开的箱盖（向后翻）
    lid = L.poly([(x0 + 2, base - bh - d + 2), (x0 + bw, base - bh - d + 6),
                  (x0 + bw - 6, base - bh - d - 20), (x0 - 2, base - bh - d - 16)])
    L.paint(lid, L.tex("#4c5638", 0.08, 5, 52))
    L.paint(L.line([(x0 + 4, base - bh - d + 4), (x0 + bw - 4, base - bh - d + 8)], 2.2), hexc("#2f3524"), 0.8)
    # 箱口阴影
    L.paint(L.rect(x0 + 4, base - bh - d + 2, x0 + bw - 4, base - bh + 3), hexc("#1a1e14"), 0.55)
    # 立着的子弹
    for i in range(7):
        bx = x0 + 10 + i * 9.4
        L.paint(L.rect(bx, base - bh - 8, bx + 4.2, base - bh + 2), hexc(BRASS), 0.95)
        L.paint(L.poly([(bx, base - bh - 8), (bx + 4.2, base - bh - 8), (bx + 2.1, base - bh - 15)]),
                hexc("#8a6a3a"), 0.95)
    # 铁包角 + 印刷标记
    for cx in (x0 + 2, x0 + bw - 12):
        L.paint(L.rect(cx, base - bh, cx + 10, base), L.tex("#6d7a63", 0.08, 4, 53))
    L.paint(L.rect(x0 + 26, base - 22, x0 + 58, base - 18), hexc("#c9ccc0"), 0.62)
    L.paint(L.rect(x0 + 26, base - 14, x0 + 44, base - 11), hexc("#c9ccc0"), 0.5)
    L.grime(front, 54, 0.25)
    L.snow_cap(x0 - 1, x0 + bw + 1, base - bh - d - 2, 8, 55, droop=0.25)
    L.snow_cap(x0 - 2, x0 + bw + 2, base - 1, 6, 56, droop=0.15)
    return _fit(L.finish(), (w / 2, base), 0.9 * PPM)          # 弹药箱 ≈ 0.9m 宽


def _bag(L: Layer, x, y, w, h, col, seed) -> None:
    """一只鼓起来的沙袋：圆角矩形 + 中间一道缝合线 + 底部压出的暗边。"""
    m = L.rect(x, y, x + w, y + h, r=h * 0.46)
    L.paint(m, L.tex(col, 0.10, 5, seed))
    L.shade(m, L.gy(y, y + h, 1.16, 0.70))
    L.tint(m, hexc("#7a6a4c"), 0.12)
    L.paint(L.line([(x + 4, y + h * 0.46), (x + w - 4, y + h * 0.44)], 1.3), hexc("#57492f"), 0.55)
    L.paint(L.ellipse(x + w * 0.5, y + 3.5, w * 0.30, h * 0.16), hexc("#e6eef5"), 0.35)   # 顶上薄雪
    L.shade(L.rect(x, y + h - 3, x + w, y + h), 0.72)


def sandbag_line():
    """沙袋掩体：底层一排、二层错缝、顶层压边，前沿结着冰。"""
    w, h = 208, 118
    L = Layer(w, h, 3)
    base = h - 8
    rows = [(base - 30, 5, 0.0), (base - 58, 4, 19.0), (base - 84, 3, 38.0)]
    seed = 60
    for (y, n, off) in rows:
        bw, bh = 44, 32
        total = n * (bw - 5)
        start = (w - total) * 0.5 + off * 0.0
        for i in range(n):
            rnd = np.random.default_rng(seed * 7 + i)
            x = start + i * (bw - 5)
            seed += 1
            _bag(L, x + rnd.uniform(-1.6, 1.6), y + rnd.uniform(-1.4, 1.4),
                 bw + rnd.uniform(-2.0, 3.0), bh + rnd.uniform(-2.0, 2.4),
                 "#7c6c4e" if (i + int(y)) % 2 == 0 else "#6f6146", seed)
    # 前沿：化了的雪又冻上一层
    L.paint(L.rect(6, base - 5, w - 6, base + 1), hexc("#8fa6b6"), 0.35)
    L.snow_cap(8, w - 8, base - 84, 9, 63, droop=0.22)
    L.paint(L.rect(4, base, w - 4, base + 3), hexc("#2c3238"), 0.35)
    return L.finish(), (w / 2, base)


def weapon_rack():
    """武器架：墙上的角钢架子，横档上靠着步枪 / 猎枪 / 撬棍。"""
    w, h = 176, 172
    L = Layer(w, h, 3)
    base = h - 8
    rail_y = [base - 128, base - 70, base - 16]
    for x in (16, w - 26):
        L.paint(L.rect(x, base - 148, x + 9, base), L.tex(STEEL_DARK, 0.07, 4, 71))
        L.paint(L.rect(x + 1, base - 148, x + 4, base), hexc(STEEL_LIT), 0.30)
        for yy in range(base - 140, base, 26):                     # 铆钉
            L.paint(L.ellipse(x + 4.5, yy, 1.8, 1.8), hexc(STEEL_LIT), 0.7)
    for y in rail_y:
        L.paint(L.rect(16, y, w - 17, y + 7), L.tex(STEEL, 0.06, 4, 72))
        L.paint(L.rect(16, y, w - 17, y + 2), hexc(STEEL_LIT), 0.35)
    # 靠在架子上的步枪（枪托在下、枪口朝上，略斜）
    def gun(x0, ytop, ybot, wood, metal):
        mid = ybot - (ybot - ytop) * 0.5
        stock = L.poly([(x0 - 4, ybot), (x0 + 16, ybot), (x0 + 24, mid), (x0 + 4, mid)])
        L.paint(stock, L.tex(wood, 0.08, 4, 73))
        L.shade(stock, L.gx(x0 - 4, x0 + 24, 1.16, 0.84))
        L.paint(L.poly([(x0 + 6, mid), (x0 + 20, mid), (x0 + 24, ytop), (x0 + 12, ytop)]),
                L.tex(metal, 0.06, 4, 74))
        L.paint(L.rect(x0 + 15, ytop + 6, x0 + 21, ytop + 26), hexc(STEEL_LIT), 0.25)   # 枪管反光
        L.paint(L.rect(x0 + 14, ytop, x0 + 22, ytop + 6), hexc(STEEL_LIT), 0.55)        # 枪口
        L.paint(L.line([(x0 + 1, ybot - 7), (x0 + 16, ybot - 5)], 2.2), hexc("#2f2318"), 0.85)
    gun(48, base - 142, base - 14, WOOD, STEEL_DARK)
    gun(96, base - 138, base - 16, "#4a5054", STEEL_DARK)
    # 挂在最上一档的撬棍
    L.paint(L.line([(126, base - 132), (150, base - 76)], 5.0), L.tex(STEEL, 0.08, 4, 75))
    L.paint(L.arc(151, base - 72, 8, 7, -40, 200, 4.6), hexc(STEEL), 0.95)
    # 挂钩 + 皮带
    for x in (30, w - 42):
        L.paint(L.arc(x, base - 128, 6, 6, 0, 180, 3.0), hexc(STEEL_LIT), 0.9)
    L.paint(L.line([(100, base - 128), (104, base - 96), (98, base - 60)], 3.0), hexc("#3a3026"), 0.85)
    L.grime(L.rect(12, base - 150, w - 12, base), seed=76, amt=0.26, cell=6)
    L.snow_cap(12, w - 12, base - 2, 7, 77, droop=0.2)
    return _fit(L.finish(), (w / 2, base), 1.5 * PPM)          # 枪架 ≈ 1.5m 宽


def target_silhouette():
    """木靶人：两块木板支起一块胶合板靶，画着黑漆人形 + 白环。"""
    w, h = 104, 172
    L = Layer(w, h, 3)
    base = h - 8
    # 支腿
    for x in (18, w - 26):
        L.paint(L.poly([(x, base), (x + 7, base), (x + 12, base - 96), (x + 5, base - 96)]),
                L.tex(WOOD_DARK, 0.08, 4, 81))
    # 靶板
    board = L.rect(10, base - 168, w - 10, base - 74, r=2)
    L.paint(board, L.tex("#8a7350", 0.08, 5, 82))
    L.shade(board, L.gy(base - 168, base - 74, 1.08, 0.9))
    L.rim(board, 1.2, 1.2, "#c9b48c", 0.35)
    # 人形剪影
    mid = w / 2
    L.paint(L.ellipse(mid, base - 146, 11, 12), hexc("#24282a"), 0.92)                 # 头
    L.paint(L.poly([(mid - 16, base - 100), (mid + 16, base - 100), (mid + 13, base - 132),
                    (mid - 13, base - 132)]), hexc("#24282a"), 0.92)                  # 身
    L.paint(L.rect(mid - 3, base - 90, mid + 3, base - 78), hexc("#24282a"), 0.9)
    # 白环 + 弹孔
    for (cy, r) in ((base - 128, 15), (base - 120, 8)):
        L.paint(L.arc(mid, cy, r, r * 1.1, 0, 360, 1.4), hexc("#d8d1bf"), 0.55)
    rng = np.random.default_rng(83)
    for _ in range(9):
        hx, hy = mid + rng.uniform(-26, 26), base - 140 + rng.uniform(0, 56)
        L.paint(L.ellipse(hx, hy, 2.2, 2.2), hexc("#12100e"), 0.9)
        L.paint(L.ellipse(hx - 1, hy - 1, 0.8, 0.8), hexc("#6a6355"), 0.5)
    L.grime(board, 84, 0.25, 5)
    L.snow_cap(8, w - 8, base - 76, 6, 85, droop=0.15)
    L.paint(L.rect(6, base - 3, w - 6, base), hexc(SNOW), 0.5)
    return _fit(L.finish(), (w / 2, base), 1.2 * PPM)         # 靶板 ≈ 1.2m 宽


def _obox_simple(L: Layer, x, base, w, d, h, top_col, front_col, seed):
    """本文件用的简化斜俯视箱体（不引 gen_props，避免循环 import）。"""
    front = L.rect(x, base - h, x + w, base)
    top = L.rect(x, base - h - d, x + w, base - h)
    L.paint(top, L.tex(top_col, 0.07, 5, seed))
    L.paint(front, L.tex(front_col, 0.08, 5, seed + 1))
    L.shade(front, L.gy(base - h, base, 1.08, 0.8))
    L.shade(top, L.gy(base - h - d, base - h, 1.08, 0.95))
    L.paint(L.rect(x, base - h - 0.6, x + w, base - h + 0.8), hexc(top_col) * 1.2, 0.55)
    return top, front


# ---------------------------------------------------------------------------
# 战斗 VFX
# ---------------------------------------------------------------------------
def muzzle_flash_sheet(frames: int = 4):
    """枪口焰 4 帧：一颗过热的白核 + 放射状尖 + 一圈烟。"""
    fw = fh = 96
    sheet = Image.new("RGBA", (fw * frames, fh), (0, 0, 0, 0))
    rng = np.random.default_rng(91)
    for f in range(frames):
        L = Layer(fw, fh, 3)
        cx, cy = fw * 0.42, fh * 0.5
        k = 1.0 - 0.22 * f
        # 烟
        _soft(L, cx + 10, cy, 30 * k, hexc("#8f8a7c"), 0.22, 6)
        # 尖锥
        for i in range(7):
            a0 = -0.55 + i * 0.18 + rng.uniform(-0.05, 0.05)
            ln = (20 + rng.uniform(0, 16)) * k
            tip = (cx + math.cos(a0) * ln, cy + math.sin(a0) * ln * 0.85)
            L.paint(L.poly([(cx - 4, cy - 5), (cx - 4, cy + 5), tip]), hexc("#ffd9a0"), 0.85)
        # 焰体
        _soft(L, cx, cy, 26 * k, hexc("#ffb347"), 0.85, 7)
        _soft(L, cx, cy, 15 * k, hexc("#fff3d0"), 1.0, 6)
        L.paint(L.ellipse(cx, cy, 7 * k, 7 * k), hexc("#ffffff"), 1.0)
        img = L.finish(outline=None)
        sheet.alpha_composite(img, (f * fw, 0))
    return sheet, (fw * 0.42, fh * 0.5)


def bullet_tracer():
    """曳光：一条两端渐隐的暖白细线（Sprite2D 沿飞行方向拉伸）。"""
    w, h = 128, 16
    L = Layer(w, h, 3)
    for i in range(9, 0, -1):
        k = i / 9.0
        L.paint(L.rect(8, h / 2 - 3.2 * k, w - 8, h / 2 + 3.2 * k), hexc("#ffd9a0"), 0.10 + 0.06 * (1 - k))
    L.paint(L.rect(14, h / 2 - 1.2, w - 14, h / 2 + 1.2), hexc("#fff6e0"), 0.9)
    return L.finish(outline=None), (w / 2, h / 2)


def impact_spark():
    """弹着火星：打在钢板上的一小簇黄白火花 + 一点灰烟。"""
    w = h = 64
    L = Layer(w, h, 3)
    _soft(L, w / 2, h / 2, 9, hexc("#9a9384"), 0.3, 5)
    rng = np.random.default_rng(93)
    for i in range(9):
        a = rng.uniform(0, math.tau)
        ln = rng.uniform(6, 22)
        tip = (w / 2 + math.cos(a) * ln, h / 2 + math.sin(a) * ln)
        L.paint(L.line([(w / 2, h / 2), tip], rng.uniform(1.0, 2.0)), hexc("#ffc46b"), 0.85)
    _soft(L, w / 2, h / 2, 8, hexc("#fff0c4"), 1.0, 5)
    return L.finish(outline=None), (w / 2, h / 2)


def shell_casing():
    """弹壳：抛出来的一枚 7.62 黄铜壳。"""
    w, h = 22, 12
    L = Layer(w, h, 3)
    L.paint(L.rect(4, 3, 17, 9), hexc(BRASS), 0.95)
    L.paint(L.rect(4, 3, 17, 4.4), hexc("#d9b465"), 0.7)
    L.paint(L.rect(17, 3, 19, 9), hexc("#8a6a34"), 0.95)
    L.paint(L.rect(3, 4, 5, 8), hexc("#6f5528"), 0.9)
    return L.finish(outline=None), (w / 2, h / 2)


def blood_mist():
    """血雾：近处被打中时炸开的一团，落地后由 VFX_Blood_Splat 接棒。"""
    w = h = 72
    L = Layer(w, h, 3)
    rng = np.random.default_rng(95)
    for i in range(16):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0, 20)
        _soft(L, w / 2 + math.cos(a) * r, h / 2 + math.sin(a) * r,
              rng.uniform(5, 12), hexc("#7f1d18"), 0.55, 4)
    _soft(L, w / 2, h / 2, 14, hexc("#a5241c"), 0.6, 5)
    return L.finish(outline=None), (w / 2, h / 2)


# ---------------------------------------------------------------------------
# 注册表
# ---------------------------------------------------------------------------
ALL = {
    "PRP_Crowbar_Rail": crowbar,
    "PRP_Pistol_TT": pistol_tt,
    "PRP_Rifle_Mosin": rifle_mosin,
    "PRP_Shotgun_Sawn": shotgun_sawn,
    "PRP_Ammo_Box_Open": ammo_box_open,
    "PRP_Sandbag_Line": sandbag_line,
    "PRP_WeaponRack": weapon_rack,
    "PRP_Target_Silhouette": target_silhouette,
}

VFX = {
    "VFX_Bullet_Tracer": bullet_tracer,
    "VFX_Impact_Spark": impact_spark,
    "VFX_Shell_Casing": shell_casing,
    "VFX_Blood_Mist": blood_mist,
}
