"""角色精灵表（CHR_01 阿列克谢 / CHR_05 内务清杀兵 ОСК）— 角色重绘版（参考图锁定）。

造型定案来源：用户提供的两张定妆参考图 + 《角色重绘 · 可直接出图的 Prompt》§一/§二：
  阿列克谢：褪色深蓝-黑铁路长大衣（长及小腿）+ 大羊羔毛翻领 + 灰色 ушанка（耳罩放下）+
    圆框金属眼镜（**角色右镜片蛛网裂 + 黑胶布缠右镜腿**）+ 冻伤红手（右手背紫蓝印章、
    指端冻伤发紫）+ 高过肩的旧帆布背包 + 腰带挂**钥匙串与马灯** + 右手低垂握**长铸铁撬棍**
    （带撬头）+ 灰毡筒靴，消瘦微驼、疲惫。
  ОСК：密封铅灰偏绿哑光橡胶防护服（深褶皱、老化裂纹、污渍）+ GP-5 防毒面具
    （双圆玻璃目镜 + **下颚橄榄色圆形滤罐**）+ **波纹呼吸软管接背负气瓶** + 帆布束带
    （挎包/水壶）+ **胸前矩形壳体高流明黄白探照灯**（挂左胸）+ 消音 AKM（长圆柱消音器）
    **枪口朝左髋下挎** + 厚橡胶手套与绝缘靴；无脸、沉重——像一堵会走路的墙。

引擎硬规格（保持不变，否则场景要重排）：
  每帧 72×112、pivot 脚底中心 (36,108)、行序 S/E/N、
  列序 0 待机 · 1-4 行走 · 5 蹲待机 · 6-7 蹲走；W = E 水平翻转（引擎 flip_h）。
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
    trousers="#3c4250", trousers_dk="#2a2f3a",      # 旧保暖裤
    boots="#78736a", boot_shaft="#938d81",          # 灰色毡筒靴 valenki（雪蚀发白）
    coat="#282e3d", coat_dk="#171c27",              # 褪色深蓝-黑铁路长大衣
    collar="#cfc3a9",                               # 大羊羔毛翻领（参考图：浅米灰）
    hat="#686d74", hat_lt="#8b9095",                # 灰色 ушанка
    skin="#b08a72",
    pack="#6f5d42", pack_dk="#4a3c2a",              # 旧帆布背包（高过肩）
    hand="#9c6256", stamp="#544a92",                # 冻伤红手 / 紫蓝印章
    iron="#24262b", rust="#6a4a30",                 # 铸铁撬棍
    belt="#2e2620", buckle="#8b8272",               # 皮带/带扣
    lantern="#2f3338", lantern_glass="#7a6a4c",     # 马灯
)
OSK = dict(
    kind="osk",
    trousers="#525a56", trousers_dk="#3c4340",      # 铅灰偏绿橡胶连体服
    boots="#1b1e22", boot_shaft="#282c31",          # 厚重绝缘靴
    coat="#5a625e", coat_dk="#424a47",
    collar=None,
    hat="#5f6864", hat_lt="#7e8783",
    skin=None,                                      # 无脸
    pack=None,
    hand="#1d2023", stamp=None,
    iron="#23262a", rust="#4a3826",                 # 消音 AKM 金属 / 木件
    filter="#6b7264", hose="#3a4043", tank="#4d5551",   # 滤罐/呼吸软管/背气瓶
    web="#7a7259", pouch="#6e6a52",                 # 帆布束带/挎包
    leg_w=12.0, boot_w=7.2, boot_shaft_w=6.0, boot_snow_w=4.6,   # 厚重绝缘靴
)


# ---------------------------------------------------------------------------
# 共享底层（gen_rabid 也用：_limb / _legs 签名与语义保持不变）
# ---------------------------------------------------------------------------
def _limb(L, pts, w, col, dk=None):
    m = L.line(pts, w)
    L.paint(m, hexc(col))
    L.shade(m, L.gx(min(p[0] for p in pts) - w / 2, max(p[0] for p in pts) + w / 2, 1.12, 0.78))
    if dk:
        L.rim(m, 1.2, 0, dk, 0.5)
    return m


def _legs(L, P, view, s, c, hip, crouch):
    # 腿/靴几何：默认值与旧版逐像素一致（CHR_03 依赖此行为）；OSK 用 P 里的 leg_w/boot_w 加重。
    lw = P.get("leg_w", 10.5)
    shaft = P.get("boot_shaft_w", 5.0)
    bw = P.get("boot_w", 6.5 if view == "E" else 5.5)
    snow_w = P.get("boot_snow_w", 4.0)
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
        m = _limb(L, [hipp, knee, (foot[0], foot[1] - 4)], lw, P["trousers"], P["trousers_dk"])
        L.shade(m, dim)
        bx = foot[0] + (3 if view == "E" else 0)
        L.paint(L.rect(foot[0] - shaft, foot[1] - 10, foot[0] + shaft, foot[1] - 1, 2),
                hexc(P["boot_shaft"]) * dim)
        L.paint(L.ellipse(bx, foot[1], bw, 3.8), hexc(P["boots"]) * dim)
        L.paint(L.ellipse(bx, foot[1] - 0.5, snow_w, 1.6), hexc("#d9e3ec"), 0.35)  # 鞋面上的雪


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


# ---------------------------------------------------------------------------
# 阿列克谢（参考图锁定）
# ---------------------------------------------------------------------------
def _al_torso(L, P, view, hip, sh, crouch):
    """深蓝-黑铁路长大衣（长及小腿）+ 腰带 + 大扣。消瘦微驼：肩背略圆。"""
    lean = 7.0 if (crouch and view == "E") else 0.0
    hem = hip + (17 if crouch else 26)          # 长大衣下摆（参考图：到小腿）
    if view == "E":
        pts = [(CX - 8 + lean, sh - 1), (CX + 7 + lean, sh + 1), (CX + 10, sh + 8),
               (CX + 11, hem), (CX - 11, hem), (CX - 10, sh + 8)]
    else:
        pts = [(CX - 11, sh - 1), (CX - 6, sh - 3), (CX + 6, sh - 3), (CX + 11, sh - 1),
               (CX + 13, sh + 8), (CX + 15, hem), (CX - 15, hem), (CX - 13, sh + 8)]
    m = L.poly(pts)
    L.paint(m, L.tex(P["coat"], 0.075, 2.6, 7))
    L.shade(m, L.gx(CX - 15, CX + 15, 1.16, 0.74))
    L.shade(m, L.gy(sh, hem, 1.06, 0.8))
    # 衣襟缝线 / 大扣 / 折痕
    if view == "S":
        L.paint(L.rect(CX - 0.7, sh + 2, CX + 0.7, hem) * m, hexc(P["coat_dk"]), 0.9)
        for by in (sh + 6, sh + 14, sh + 22, sh + 30, sh + 38):
            if by < hem - 2:
                L.paint(L.ellipse(CX + 3.4, by, 1.3, 1.3) * m, hexc("#10141b"))
                L.paint(L.ellipse(CX + 3.0, by - 0.4, 0.5, 0.5) * m, hexc("#5a6478"), 0.7)
    for fy in np.arange(sh + 10, hem - 3, 8.5):
        L.paint(L.rect(CX - 13, fy, CX + 13, fy + 0.9) * m, hexc(P["coat_dk"]), 0.45)
    # 腰带（参考图：束腰皮带 + 带扣）
    by0 = hip - 3
    belt = L.rect(CX - 15, by0, CX + 15, by0 + 3.6, 1) * m
    L.paint(belt, hexc(P["belt"]))
    L.paint(L.rect(CX - 3.2, by0 - 0.4, CX + 3.2, by0 + 4.0, 1) * m, hexc(P["buckle"]) * 0.85)
    L.paint(L.rect(CX - 1.6, by0 + 0.7, CX + 1.6, by0 + 2.9, 0.6) * m, hexc(P["belt"]))
    # 肩头积雪
    if view != "E":
        L.paint(L.rect(CX - 12, sh - 2, CX - 5, sh + 1.5) * m, hexc("#d9e3ec"), 0.42)
        L.paint(L.rect(CX + 5, sh - 2, CX + 12, sh + 1.5) * m, hexc("#d9e3ec"), 0.42)
    else:
        L.paint(L.rect(CX - 6 + lean, sh - 2, CX + 6 + lean, sh + 1.5) * m, hexc("#d9e3ec"), 0.38)
    L.rim(m, 0, -1.2, "#0b0f14", 0.32)
    L.rim(m, -1.4, 0, "#46506b", 0.4)
    return lean, hem


def _al_collar(L, P, hx, head, view):
    """大羊羔毛翻领（参考图：浅米灰、覆盖双肩上部）。"""
    col = L.tex(P["collar"], 0.14, 1.3, 21)
    if view == "N":
        m = L.rect(hx - 11.5, head + 9, hx + 11.5, head + 16.5, 2.6)
        L.paint(m, col)
        L.shade(m, L.gy(head + 9, head + 16.5, 1.08, 0.82))
        for kx in (-6, 0, 6):
            L.paint(L.rect(hx + kx - 0.8, head + 10, hx + kx + 0.8, head + 15.5) * m, hexc("#b3a78d"), 0.5)
        return
    xs = (-1,) if view == "E" else (-1, 1)
    for sx in xs:
        x0, x1 = (hx - 11.5, hx - 2.4) if sx < 0 else (hx + 2.4, hx + 11.5)
        m = L.rect(x0, head + 9.5, x1, head + 18, 2.6)
        L.paint(m, col)
        L.shade(m, L.gx(hx - 11, hx + 11, 1.12, 0.8))
        L.paint(L.rect(x0, head + 16, x1, head + 17.8, 1.4) * m, hexc("#ab9f85"), 0.7)  # 毛边阴影
    if view == "E":
        m = L.rect(hx - 10, head + 9.5, hx + 2, head + 15, 2.4)
        L.paint(m, col * 0.78)


def _al_head(L, P, view, head, lean):
    """瘦削脸 + 圆框眼镜（右镜片蛛网裂 + 黑胶布缠右镜腿）+ 灰色 ушанка 耳罩放下。"""
    hx = CX + (lean * 1.4 if view == "E" else 0)
    hat = L.tex(P["hat"], 0.15, 1.3, 31)
    hat_lt = L.tex(P["hat_lt"], 0.18, 1.1, 32)
    skin = hexc(P["skin"])
    if view == "S":
        face = L.ellipse(hx, head + 2.5, 6.8, 8.4)
        L.paint(face, skin)
        L.shade(face, L.gx(hx - 7, hx + 7, 1.12, 0.76))
        # 颧骨凹陷 + 疲惫
        L.paint(L.ellipse(hx - 3.8, head + 4.4, 2.5, 1.9) * face, hexc("#7c5a48"), 0.4)
        L.paint(L.ellipse(hx + 3.8, head + 4.4, 2.5, 1.9) * face, hexc("#7c5a48"), 0.4)
        for ex in (-2.9, 2.9):
            L.paint(L.ellipse(hx + ex, head + 1.6, 1.6, 1.2), hexc("#1e1817"))          # 眼
            L.paint(L.ellipse(hx + ex, head + 3.4, 2.0, 0.85), hexc("#6b4e42"), 0.6)    # 眼袋
            L.paint(L.rect(hx + ex - 2.0, head - 0.7, hx + ex + 2.0, head + 0.1, 0.6), hexc("#3c2e28"), 0.7)  # 眉
        L.paint(L.rect(hx - 0.8, head + 2.8, hx + 0.8, head + 5.0, 0.6), hexc("#7c5a48"), 0.65)   # 鼻影
        L.paint(L.rect(hx - 2.3, head + 6.8, hx + 2.3, head + 7.6, 0.5), hexc("#5c4034"), 0.85)   # 嘴
        L.paint(face * smooth(0.55, 0.85, L.noise(1.6, 25)), hexc("#5c4c42"), 0.3)      # 胡茬
        # —— 圆框金属眼镜（深色镜框，浅色反光）——
        gl = hexc("#454c55")
        for ex in (-2.9, 2.9):
            L.paint(L.arc(hx + ex, head + 1.6, 2.85, 2.7, 0, 360, 1.25), gl)
            L.paint(L.ellipse(hx + ex - 1.0, head + 0.4, 0.7, 0.5), hexc("#c9d4de"), 0.75)  # 镜片反光
        L.paint(L.line([(hx - 0.2, head + 1.4), (hx + 0.2, head + 1.4)], 1.1, False), gl)
        L.paint(L.line([(hx - 5.7, head + 1.4), (hx - 7.1, head + 1.9)], 1.1, False), gl)
        L.paint(L.line([(hx + 5.7, head + 1.4), (hx + 7.1, head + 1.9)], 1.1, False), gl)
        # 角色右镜片（观众视角左）：蛛网裂
        rx, ry = hx - 2.9, head + 1.6
        for ang in (35, 115, 205, 290):
            a = math.radians(ang)
            L.paint(L.line([(rx, ry), (rx + 2.6 * math.cos(a), ry + 2.4 * math.sin(a))], 0.55, False),
                    hexc("#e8f0f6"), 0.9)
        L.paint(L.arc(rx, ry, 1.6, 1.5, 0, 360, 0.5), hexc("#e8f0f6"), 0.75)
        # 黑胶布缠右镜腿
        L.paint(L.rect(hx - 7.6, head + 0.6, hx - 5.2, head + 2.7, 0.9), hexc("#12151a"))
    elif view == "E":
        face = L.ellipse(hx + 2, head + 2.5, 6.3, 8.2)
        L.paint(face, skin)
        L.paint(L.ellipse(hx + 8.3, head + 3.8, 1.5, 2.1), skin * 0.9)     # 鼻
        L.paint(L.ellipse(hx + 5.0, head + 1.6, 1.5, 1.2), hexc("#1e1817"))
        L.paint(L.ellipse(hx + 4.2, head + 3.4, 1.8, 0.85), hexc("#6b4e42"), 0.55)
        L.paint(L.rect(hx + 5.0, head + 6.9, hx + 8.0, head + 7.6, 0.5), hexc("#5c4034"), 0.85)
        L.paint(face * smooth(0.55, 0.85, L.noise(1.6, 26)), hexc("#5c4c42"), 0.28)
        # 眼镜（侧面）：一只镜圈 + 镜腿（缠胶布）
        L.paint(L.arc(hx + 4.6, head + 1.6, 2.65, 2.5, 0, 360, 1.25), hexc("#454c55"))
        L.paint(L.ellipse(hx + 3.8, head + 0.5, 0.7, 0.5), hexc("#c9d4de"), 0.75)
        L.paint(L.line([(hx + 2.1, head + 1.5), (hx - 4.8, head + 1.8)], 1.1, False), hexc("#454c55"))
        L.paint(L.line([(hx + 3.0, head + 1.2), (hx + 3.8, head + 2.5)], 0.55, False), hexc("#e8f0f6"), 0.85)
        L.paint(L.rect(hx - 2.8, head + 0.8, hx - 0.5, head + 2.6, 0.9), hexc("#12151a"))
    else:
        pass  # N：后脑，眼镜不可见
    # —— 灰色 ушанка（耳罩放下）——
    if view != "N":
        dome = L.ellipse(hx + (1 if view == "E" else 0), head - 5.8, 10.0, 6.2)
        L.paint(dome, hat)
        L.shade(dome, L.gx(hx - 10, hx + 10, 1.15, 0.75))
        band = L.rect(hx - 10.0, head - 8.2, hx + 10.0, head - 4.4, 2)
        L.paint(band, hat_lt)
        if view == "E":
            L.paint(L.rect(hx - 5.2, head - 2.5, hx + 0.6, head + 9.5, 2.2), hat * 0.95)
            flaps = [(-10.0, -4.4)]
        else:
            flaps = [(-11.4, -5.8), (5.8, 11.4)]
        for a, b in flaps:
            m = L.rect(hx + a, head - 2.5, hx + b, head + 9.5, 2.2)
            L.paint(m, hat)
            L.shade(m, L.gx(hx - 11, hx + 11, 1.12, 0.8))
            L.paint(L.rect(hx + a, head + 6.2, hx + b, head + 8.8, 1.6) * m, hat_lt, 0.8)  # 毛边
    else:
        dome = L.ellipse(hx, head - 1.5, 10.0, 9.0)
        L.paint(dome, hat)
        L.shade(dome, L.gx(hx - 10, hx + 10, 1.15, 0.75))
        for sx in (-1, 1):
            L.paint(L.rect(hx + sx * 9.6 - 3, head - 1, hx + sx * 9.6 + 3, head + 9.5, 2.2), hat * 0.95)
        L.paint(L.rect(hx - 1.0, head - 8, hx + 1.0, head + 6), hexc("#4c5057"), 0.7)  # 后缝
    L.snow_cap(hx - 8, hx + 8, head - 11.5, 4, 35, droop=0.1)


def _al_hand(L, P, x, y, right_hand, dim=1.0):
    """冻伤红手：指端发紫；right_hand=True 时手背盖紫蓝印章（参考图）。"""
    m = L.ellipse(x, y + 1, 3.5, 3.9)
    L.paint(m, hexc(P["hand"]) * dim)
    L.shade(m, L.gy(y - 3, y + 5, 1.12, 0.8) * dim)
    L.paint(L.ellipse(x, y + 3.2, 2.8, 1.6) * m, hexc(P["stamp"]), 0.38 * dim)   # 指端冻伤发紫
    if right_hand:
        L.paint(L.ellipse(x + 0.3, y - 0.3, 1.8, 1.2), hexc(P["stamp"]), 1.0)    # 印章
    L.paint(L.rect(x - 2.6, y + 3.3, x + 2.6, y + 4.1, 1), hexc("#6b3832"), 0.5 * dim)


def _al_arm(L, P, pts, right_hand, dim=1.0, swing=0.0):
    m = _limb(L, pts, 8.2, P["coat"], P["coat_dk"])
    L.shade(m, dim)
    hx, hy = pts[-1]
    # 袖口束带（把袖子与大衣在视觉上分开）
    c0 = pts[-2]
    cx_, cy_ = c0[0] + (hx - c0[0]) * 0.7, c0[1] + (hy - c0[1]) * 0.7
    cuff = L.line([(cx_, cy_), (hx, hy)], 9.2)
    L.paint(cuff * m, hexc(P["coat"]) * 1.28, 0.85)
    _al_hand(L, P, hx, hy + 1, right_hand, dim)
    return m


def _al_crowbar(L, P, x, y, angle_deg, length=36.0, dim=1.0):
    """长铸铁撬棍（参考图：杆长、握把上方仍露出一截、底端撬头弯脚）。"""
    a = math.radians(angle_deg)
    x2, y2 = x + math.sin(a) * length, y + math.cos(a) * length
    x1, y1 = x - math.sin(a) * 13, y - math.cos(a) * 13      # 握把上方露出的杆头
    under = L.line([(x1, y1), (x2, y2)], 4.2)                # 深色垫底，从剪影里分离出来
    L.paint(under, hexc("#0d1014"))
    m = L.line([(x1, y1), (x2, y2)], 3.1)
    L.paint(m, hexc(P["iron"]) * dim)
    L.rim(m, -1.1, 0, "#6a747f", 0.55 * dim)
    L.paint(m * smooth(0.55, 0.85, L.noise(2.2, 44)), hexc(P["rust"]), 0.5 * dim)
    # 撬头（弯脚）
    hook = L.line([(x2, y2), (x2 + math.copysign(3.8, math.sin(a) if abs(math.sin(a)) > 0.2 else -1), y2 + 3.6)], 3.2)
    L.paint(hook, hexc(P["iron"]) * dim)
    L.paint(L.ellipse(x1, y1, 1.9, 1.9), hexc(P["iron"]) * dim)  # 顶端


def _al_pack(L, P, view, sh, hip, lean):
    """旧帆布背包（参考图：高过肩、翻盖 + 扣带）。"""
    if view == "N":
        m = L.rect(CX - 11, sh - 5, CX + 11, hip + 3, 4)
    elif view == "E":
        m = L.rect(CX - 18 + lean * 0.5, sh - 5, CX - 6 + lean * 0.5, hip - 3, 4)
    else:
        # S：只露出两条背带
        for sx in (-7.5, 7.5):
            L.paint(L.rect(CX + sx - 1.8, sh - 2, CX + sx + 1.8, sh + 17, 1.2), hexc(P["pack"]))
            L.paint(L.ellipse(CX + sx, sh + 13, 1.7, 1.3), hexc(P["pack_dk"]))
        return
    L.paint(m, L.tex(P["pack"], 0.09, 2.2, 21))
    L.shade(m, L.gy(sh - 5, hip + 3, 1.1, 0.78))
    if view == "N":
        flap = L.rect(CX - 11, sh - 5, CX + 11, sh + 6, 3)
        L.paint(flap, L.tex(P["pack"], 0.1, 1.8, 22) * 1.08)
        L.paint(L.rect(CX - 11, sh + 5.4, CX + 11, sh + 6.8), hexc(P["pack_dk"]))
        for x in (CX - 8, CX + 8):
            L.paint(L.rect(x - 1.6, sh - 5, x + 1.6, hip + 1, 1), hexc(P["pack_dk"]))
            L.paint(L.ellipse(x, sh + 12, 1.6, 1.3), hexc("#8b8272"))
        L.paint(L.rect(CX - 5, sh + 14, CX + 5, sh + 20, 2), hexc(P["pack"]) * 0.92)  # 副袋
    else:
        L.paint(L.rect(CX - 18 + lean * 0.5, sh - 5, CX - 6 + lean * 0.5, sh + 5, 2.5) * m,
                hexc(P["pack"]) * 1.1)
        L.paint(L.rect(CX - 15 + lean * 0.5, sh + 12, CX - 9 + lean * 0.5, sh + 18, 1.5) * m,
                hexc(P["pack_dk"]))
    L.paint(L.rect((CX - 11) if view == "N" else (CX - 18 + lean * 0.5), sh - 6,
                   (CX + 11) if view == "N" else (CX - 6 + lean * 0.5), sh - 2.4), hexc("#dce6ef"), 0.55)  # 顶雪


def _al_belt_gear(L, P, view, hip, lean):
    """腰带挂件（参考图）：右髋钥匙串、左髋马灯。S=观众左右镜像，N 相反，E 挂前侧。"""
    keys = hexc(P["buckle"]) * 0.8
    if view == "S":
        kx, lx = CX - 8, CX + 9
    elif view == "N":
        kx, lx = CX + 8, CX - 9
    else:
        kx, lx = CX - 5 + lean * 0.5, CX + 8 + lean * 0.5
    # 钥匙串：环 + 两把钥匙
    L.paint(L.arc(kx, hip + 1.5, 1.8, 1.8, 0, 360, 0.7), keys)
    for dx in (-1.2, 1.2):
        L.paint(L.rect(kx + dx - 0.5, hip + 3, kx + dx + 0.5, hip + 7.5, 0.5), keys)
        L.paint(L.ellipse(kx + dx, hip + 8.2, 1.0, 1.2), keys * 0.9)
    # 马灯：提梁 + 灯体 + 灯罩
    L.paint(L.arc(lx, hip + 1.0, 2.6, 2.2, 180, 360, 0.9), hexc(P["buckle"]) * 0.7)
    L.paint(L.rect(lx - 2.2, hip + 1.2, lx + 2.2, hip + 3.0, 0.8), hexc(P["lantern"]))
    L.paint(L.rect(lx - 2.8, hip + 3.0, lx + 2.8, hip + 10.5, 1.6), hexc(P["lantern"]))
    L.paint(L.rect(lx - 2.0, hip + 4.4, lx + 2.0, hip + 9.2, 1.2), hexc(P["lantern_glass"]), 0.85)
    L.paint(L.rect(lx - 2.2, hip + 10.2, lx + 2.2, hip + 11.8, 0.8), hexc(P["lantern"]))


# ---------------------------------------------------------------------------
# 内务清杀兵 ОСК（参考图锁定）
# ---------------------------------------------------------------------------
def _hose(L, pts, w, color, ring="#24292c"):
    """波纹呼吸软管：主管 + 一圈圈波纹。"""
    m = L.line(pts, w)
    L.paint(m, hexc(color))
    L.rim(m, -1, -0.6, "#7c868c", 0.4)
    # 沿路径打波纹环
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        d = math.hypot(x1 - x0, y1 - y0)
        n = max(1, int(d / 2.6))
        for k in range(n + 1):
            t = k / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            L.paint(L.ellipse(x, y, w * 0.62, w * 0.62) * m, hexc(ring), 0.55)
    return m


def _osk_torso(L, P, view, hip, sh, crouch):
    """铅灰偏绿厚重橡胶防护服：宽廓形 + 深褶皱 + 老化裂纹 + 污渍。像一堵墙。"""
    lean = 6.0 if (crouch and view == "E") else 0.0
    hem = hip + (14 if crouch else 19)
    if view == "E":
        pts = [(CX - 11 + lean, sh - 1), (CX + 8 + lean, sh - 1), (CX + 12, sh + 7),
               (CX + 12, hem), (CX - 12, hem), (CX - 13, sh + 7)]
    else:
        pts = [(CX - 13, sh - 2), (CX - 7, sh - 4), (CX + 7, sh - 4), (CX + 13, sh - 2),
               (CX + 16, sh + 8), (CX + 16, hem), (CX - 16, hem), (CX - 16, sh + 8)]
    m = L.poly(pts)
    L.paint(m, L.tex(P["coat"], 0.055, 3.2, 7))
    L.shade(m, L.gx(CX - 16, CX + 16, 1.14, 0.72))
    L.shade(m, L.gy(sh, hem, 1.05, 0.8))
    # 深褶皱（竖向）
    folds = (-11, -5.5, 0.5, 6.5, 12) if view != "E" else (-8, -2, 4, 9)
    for fx in folds:
        L.paint(L.line([(CX + fx + lean * 0.4, sh + 6), (CX + fx * 1.06 + lean * 0.2, hem - 2)], 1.1, False) * m,
                hexc(P["coat_dk"]), 0.55)
    # 老化裂纹
    r = np.random.default_rng(52)
    for _ in range(4):
        x0 = CX + r.uniform(-12, 12) + lean * 0.5
        y0 = r.uniform(sh + 5, hem - 6)
        L.paint(L.line([(x0, y0), (x0 + r.uniform(-3, 3), y0 + r.uniform(3, 7)),
                        (x0 + r.uniform(-5, 5), y0 + r.uniform(7, 12))], 0.6, False) * m,
                hexc("#2c3138"), 0.7)
    L.grime(m, 8, 0.3, 4.5)
    L.rust_streaks(m, 9, 0.18, "#5a4a38", (2.2, 12))
    # 腰带 + 帆布束带（参考图：竖背带 + 横胸带 + 腰包/水壶）
    L.paint(L.rect(CX - 16, hip - 3, CX + 16, hip + 1.2) * m, hexc("#24282c"))
    L.paint(L.rect(CX - 16, hip - 3, CX + 16, hip - 1.8) * m, hexc("#5c6068"), 0.5)
    web = hexc(P["web"])
    if view == "S":
        for sx in (-8, 8):
            L.paint(L.rect(CX + sx - 1.8, sh + 1, CX + sx + 1.8, hip - 2, 1) * m, web, 0.95)   # 竖背带
        L.paint(L.rect(CX - 14, sh + 12, CX + 14, sh + 15.4) * m, web, 0.9)                    # 横胸带
        L.paint(L.rect(CX - 2.4, sh + 11.6, CX + 2.4, sh + 15.8, 0.8) * m, hexc("#8b8272"))    # 扣
        # 两个胸挎包（参考图）
        for px in (-11, 11):
            L.paint(L.rect(CX + px - 3.4, sh + 17, CX + px + 3.4, sh + 24, 1.4) * m, hexc(P["pouch"]))
            L.paint(L.rect(CX + px - 3.4, sh + 16.2, CX + px + 3.4, sh + 18.4, 1.2) * m, hexc(P["pouch"]) * 0.82)
    elif view == "E":
        L.paint(L.line([(CX + 10 + lean, sh + 3), (CX - 10, hip - 3)], 3.0) * m, web, 0.9)
        L.paint(L.rect(CX - 14, sh + 12, CX + 11, sh + 15.2) * m, web, 0.85)
    else:
        for sx in (-8, 8):
            L.paint(L.rect(CX + sx - 1.8, sh + 1, CX + sx + 1.8, hip - 2, 1) * m, web, 0.95)
        L.paint(L.line([(CX + 12, sh + 1), (CX - 8, hip - 3)], 3.0) * m, web, 0.9)
    # 腰间水壶（左髋）与杂物包（右髋）
    if view == "S":
        L.paint(L.rect(CX + 9, hip + 1, CX + 15, hip + 11, 2), hexc(P["pouch"]))
        L.paint(L.rect(CX + 10, hip - 1, CX + 14, hip + 2, 1), hexc(P["pouch"]) * 0.8)   # 壶盖
        L.paint(L.rect(CX - 15, hip + 1, CX - 9, hip + 9, 1.5), hexc(P["pouch"]) * 0.9)
    elif view == "E":
        L.paint(L.rect(CX + 6, hip + 1, CX + 12, hip + 11, 2), hexc(P["pouch"]))
    else:
        L.paint(L.rect(CX - 15, hip + 1, CX - 9, hip + 11, 2), hexc(P["pouch"]))
        L.paint(L.rect(CX + 9, hip + 1, CX + 15, hip + 9, 1.5), hexc(P["pouch"]) * 0.9)
    L.rim(m, -1.5, 0, "#9aa3ab", 0.5)
    L.rim(m, 0, -1.2, "#0b0f14", 0.32)
    return lean, hem


def _osk_lamp(L, x, y, dim=1.0):
    """胸前高流明探照灯（参考图：矩形壳体 + 大圆灯罩，挂左胸）。"""
    L.paint(L.rect(x - 4.6, y - 4.2, x + 4.6, y + 4.2, 1.6), hexc("#2a2e33") * dim)   # 壳体
    L.paint(L.rect(x - 4.6, y - 4.2, x + 4.6, y - 2.6, 1) * 1.0, hexc("#454b52") * dim)
    for rx in (-2.6, 0, 2.6):                                                        # 壳体棱线
        L.paint(L.rect(x + rx - 0.5, y + 2.6, x + rx + 0.5, y + 3.9) * 1.0, hexc("#454b52") * dim)
    L.paint(L.ellipse(x, y - 0.3, 3.1, 3.1), hexc("#fff2c8") * dim)                  # 灯罩
    L.paint(L.ellipse(x - 0.8, y - 1.1, 1.2, 1.2), hexc("#ffffff") * dim)
    L.paint(L.ellipse(x, y, 5.6, 5.6), hexc("#ffe9b0"), 0.16 * dim)                  # 微光晕


def _osk_head(L, P, view, head, lean):
    """GP-5 面具（参考图）：双圆玻璃目镜 + 下颚橄榄色圆形滤罐；波纹软管接到背气瓶。"""
    hx = CX + (lean * 1.2 if view == "E" else 0)
    hood = L.ellipse(hx + (1 if view == "E" else 0), head, 9.8, 10.2)
    L.paint(hood, L.tex(P["hat"], 0.05, 2.4, 41))
    L.shade(hood, L.gx(hx - 10, hx + 10, 1.18, 0.7))
    L.rim(hood, -1.5, -1, "#a3acb4", 0.5)
    filt = hexc(P["filter"])
    if view == "S":
        plate = L.ellipse(hx, head + 1.6, 7.6, 8.4)
        L.paint(plate, L.tex(P["hat_lt"], 0.05, 2.0, 42) * 0.8)
        for ex in (-3.3, 3.3):                       # 双圆玻璃目镜
            L.paint(L.ellipse(hx + ex, head - 1.2, 3.15, 3.15), hexc("#2c3238"))
            L.paint(L.ellipse(hx + ex, head - 1.2, 2.55, 2.55), hexc("#16202a"))
            L.paint(L.ellipse(hx + ex - 0.8, head - 2.1, 1.0, 0.7), hexc("#cfe0ee"), 0.95)  # 冷反光
            L.paint(L.rect(hx + ex - 1.7, head - 1.2, hx + ex + 1.7, head - 0.7), hexc("#243642"), 0.5)
        # 下颚滤罐（参考图：橄榄色圆罐，略向下）
        L.paint(L.ellipse(hx, head + 6.8, 3.9, 3.5), hexc(P["coat_dk"]))
        L.paint(L.ellipse(hx, head + 7.2, 3.3, 3.0), filt)
        L.paint(L.arc(hx, head + 7.2, 2.2, 2.0, 0, 360, 0.7), hexc("#4c5247"))
        L.paint(L.ellipse(hx, head + 7.2, 0.8, 0.8), hexc("#33382f"))
        L.paint(L.ellipse(hx - 1.1, head + 6.0, 1.1, 0.6), hexc("#9aa394"), 0.55)   # 罐体高光
    elif view == "E":
        L.paint(L.ellipse(hx + 4.4, head - 1.2, 2.9, 2.9), hexc("#2c3238"))
        L.paint(L.ellipse(hx + 4.4, head - 1.2, 2.3, 2.3), hexc("#16202a"))
        L.paint(L.ellipse(hx + 3.8, head - 2.0, 0.9, 0.6), hexc("#cfe0ee"), 0.95)
        # 下颚滤罐向前下突出
        L.paint(L.ellipse(hx + 8.2, head + 6.2, 3.0, 3.2), filt)
        L.paint(L.ellipse(hx + 9.2, head + 6.6, 2.1, 2.5), filt * 0.88)
        L.paint(L.ellipse(hx + 8.8, head + 5.2, 1.0, 0.6), hexc("#9aa394"), 0.5)
    else:
        L.paint(L.rect(hx - 1.0, head - 7, hx + 1.0, head + 6), hexc("#2c3138"), 0.8)   # 后脑中缝
        L.paint(L.rect(hx - 8, head + 2, hx + 8, head + 3.4, 1) * hood, hexc("#2c3138"), 0.7)
        L.paint(L.ellipse(hx, head + 8.2, 2.6, 1.5), filt, 0.9)                        # 滤罐下缘
    for sx in (-1, 1):                              # 面罩绑带
        if view != "E" or sx > 0:
            L.paint(L.rect(hx + sx * 8.6 - 1.2, head - 1, hx + sx * 8.6 + 1.2, head + 5, 1), hexc("#2c3138"), 0.85)
    L.snow_cap(hx - 6, hx + 6, head - 8.5, 3.2, 42, droop=0.1)
    return hx


def _osk_hoses(L, P, view, hx, head, sh, lean):
    """波纹呼吸软管：面颊两侧 → 肩后 → 背气瓶（参考图）。"""
    h = hexc(P["hose"])
    if view == "S":
        for sx in (-1, 1):
            _hose(L, [(hx + sx * 6.2, head + 5.5), (hx + sx * 10.5, head + 11),
                      (hx + sx * 12.2, sh + 1.5)], 2.6, "#3a4043")
    elif view == "E":
        _hose(L, [(hx + 8.2, head + 6.5), (hx + 4, head + 12), (CX - 11 + lean, sh - 2)], 2.6, "#3a4043")
    else:
        for sx in (-1, 1):
            _hose(L, [(hx + sx * 9.0, head + 6.5), (hx + sx * 11.5, sh - 2),
                      (hx + sx * 6.0, sh - 5)], 2.6, "#3a4043")


def _osk_back(L, P, view, sh, hip, lean):
    """背负气瓶 + 调压阀（参考图）：N 全貌，E 侧面露出。"""
    if view not in ("N", "E"):
        return
    tank = hexc(P["tank"])
    if view == "N":
        m = L.rect(CX - 6, sh - 5, CX + 6, sh + 15, 4)
        L.paint(m, L.tex("#4d5551", 0.06, 2.4, 51))
        L.shade(m, L.gx(CX - 6, CX + 6, 1.18, 0.72))
        L.paint(L.rect(CX - 6, sh - 6.5, CX + 6, sh - 3.5, 1.6), hexc("#3a423e"))      # 瓶肩
        L.paint(L.rect(CX + 1, sh - 10, CX + 7, sh - 5, 1.4), hexc("#3a423e"))        # 调压阀
        L.paint(L.rect(CX + 2, sh - 9, CX + 4, sh - 7.5, 0.6), hexc("#8b948f"), 0.7)
        for sy in (sh + 2, sh + 8):                                                   # 固定带
            L.paint(L.rect(CX - 7, sy, CX + 7, sy + 2.2), hexc(P["web"]), 0.95)
        L.rim(m, -1.3, 0, "#7c868c", 0.45)
    else:
        m = L.rect(CX - 18 + lean * 0.5, sh - 4, CX - 11 + lean * 0.5, sh + 14, 3)
        L.paint(m, L.tex("#4d5551", 0.06, 2.4, 51))
        L.shade(m, L.gx(CX - 18, CX - 11, 1.15, 0.75))
        L.paint(L.rect(CX - 18 + lean * 0.5, sh - 5.5, CX - 11 + lean * 0.5, sh - 3, 1.2), hexc("#3a423e"))
        L.paint(L.rect(CX - 18 + lean * 0.5, sh + 4, CX - 11 + lean * 0.5, sh + 6), hexc(P["web"]), 0.9)


def _osk_rifle(L, P, view, sh, hip, lean):
    """消音 AKM 横挎（参考图）：枪托在他右肩（S 观众左），枪口/消音器垂向他左髋（S 观众右）。
    E 向：微下斜横过胸前，消音器向前下方突出；N 向：背带斜过背，消音器在左髋侧。"""
    gun, wood = hexc(P["iron"]), hexc(P["rust"])
    dark = hexc("#101318")
    if view == "S":
        a, b = (CX - 11, sh + 4), (CX + 7, hip + 3)           # 枪托（他右肩）→ 枪口（他左髋）
        L.paint(L.line([a, b], 5.0), dark)
        L.paint(L.line([a, b], 3.6), gun)
        L.rim(L.line([a, b], 3.6), -1, -0.6, "#6a747f", 0.5)
        L.paint(L.line([(CX - 5, sh + 12), (CX + 1, sh + 18)], 4.6), wood)            # 木护木
        L.paint(L.line([(CX - 1, sh + 15), (CX - 3, sh + 23), (CX - 6, sh + 26)], 3.0, False), dark)
        L.paint(L.line([(CX - 1, sh + 15), (CX - 3, sh + 23), (CX - 6, sh + 26)], 2.2, False), gun)  # 弹匣
        L.paint(L.ellipse(CX - 11, sh + 4, 3.4, 3.4), hexc("#2c3036"))                # 枪托底
        # 长圆柱消音器
        L.paint(L.line([b, (CX + 14, hip + 11)], 5.6), dark)
        sil = L.line([b, (CX + 14, hip + 11)], 4.2)
        L.paint(sil, gun * 0.92)
        L.rim(sil, -1, 0, "#6a747f", 0.55)
        L.paint(L.ellipse(CX + 14, hip + 11, 2.1, 2.1), hexc("#0e1114"))
    elif view == "E":
        x0 = CX - 11 + lean
        L.paint(L.line([(x0, sh + 13), (x0 + 9, sh + 15)], 6.6), dark)
        L.paint(L.line([(x0, sh + 13), (x0 + 9, sh + 15)], 5.2), wood)                # 枪托
        L.paint(L.line([(x0 + 8, sh + 15), (x0 + 22, sh + 18)], 5.0), dark)
        L.paint(L.line([(x0 + 8, sh + 15), (x0 + 22, sh + 18)], 3.6), gun)           # 机匣
        L.paint(L.line([(x0 + 14, sh + 17), (x0 + 20, sh + 19)], 4.2), wood)         # 木护木
        L.paint(L.line([(x0 + 13, sh + 18), (x0 + 14, sh + 26), (x0 + 17, sh + 29)], 3.0, False), dark)
        L.paint(L.line([(x0 + 13, sh + 18), (x0 + 14, sh + 26), (x0 + 17, sh + 29)], 2.2, False), gun)
        # 消音器向前下方突出（微下斜）
        L.paint(L.line([(x0 + 21, sh + 18.2), (x0 + 33, sh + 21.5)], 5.8), dark)
        sil = L.line([(x0 + 21, sh + 18.2), (x0 + 33, sh + 21.5)], 4.4)
        L.paint(sil, gun * 0.92)
        L.rim(sil, 0, -1, "#6a747f", 0.55)
        L.paint(L.ellipse(x0 + 33, sh + 21.5, 2.2, 2.2), hexc("#0e1114"))
    else:
        # N：同一把枪（他右肩 → 他左髋）。他面朝北时右肩在观众右侧、左髋在观众左侧。
        L.paint(L.line([(CX + 11, sh + 2), (CX - 7, hip + 1)], 3.2), dark)           # 枪背带
        L.paint(L.line([(CX + 11, sh + 2), (CX - 7, hip + 1)], 2.2), hexc("#2c3138"))
        L.paint(L.line([(CX + 8, sh + 6), (CX - 4, hip - 1)], 4.6), dark)            # 枪身
        L.paint(L.line([(CX + 8, sh + 6), (CX - 4, hip - 1)], 3.2), gun)
        L.paint(L.line([(CX + 9, sh + 5), (CX + 13, sh + 12)], 5.4), hexc("#2c3036"))  # 枪托（他右肩=观众右）
        L.paint(L.line([(CX - 5, hip), (CX - 11, hip + 7)], 5.2), dark)               # 消音器（他左髋=观众左）
        L.paint(L.line([(CX - 5, hip), (CX - 11, hip + 7)], 3.8), gun * 0.92)
        L.paint(L.ellipse(CX - 11, hip + 7, 2.0, 2.0), hexc("#0e1114"))


def _osk_arm(L, P, pts, dim=1.0):
    m = _limb(L, pts, 9.8, P["coat"], P["coat_dk"])
    L.shade(m, dim)
    L.paint(m * smooth(0.55, 0.8, L.noise(3.0, 46)), hexc(P["coat_dk"]), 0.5)
    hx, hy = pts[-1]
    L.paint(L.ellipse(hx, hy + 1.5, 4.8, 5.0), hexc(P["hand"]) * dim)   # 厚橡胶手套
    L.paint(L.ellipse(hx, hy - 0.6, 5.0, 2.0), hexc("#2c3238") * dim)   # 喇叭袖口
    L.paint(L.ellipse(hx, hy + 0.6, 3.4, 1.4), hexc("#17191c") * dim)


# ---------------------------------------------------------------------------
# 组帧
# ---------------------------------------------------------------------------
def frame(P, view, phase, crouch, walking):
    L = Layer(FW, FH, 4)
    s, c, hip, sh, head = _pose(view, phase, crouch, walking)
    osk = P["kind"] == "osk"
    sw = s * (2.4 if osk else 3.2)          # ОСК 步幅更沉
    if osk:
        s = s * 0.8
    if view == "E":
        lean = 6.0 if (osk and crouch) else (7.0 if crouch else 0.0)
        hunch = 0.0 if osk else 2.2         # 阿列克谢微驼（头前探）
        if osk:
            _osk_arm(L, P, [(CX - 4 + lean, sh + 5), (CX - 6 - s * 4 + lean * 0.5, sh + 16),
                            (CX - 5 - s * 7, sh + 27)], 0.8)            # 远臂
            _legs(L, P, view, s, c, hip, crouch)
            lean_t, hem = _osk_torso(L, P, view, hip, sh, crouch)
            _osk_back(L, P, view, sh, hip, lean_t)
            _osk_rifle(L, P, view, sh, hip, lean_t)
            _osk_arm(L, P, [(CX + 2 + lean_t, sh + 5), (CX + 4 + s * 4 + lean_t * 0.5, sh + 16),
                            (CX + 3 + s * 7, sh + 27)])
            _osk_lamp(L, CX + 8 + lean_t * 0.6, sh + 10)
            hx = _osk_head(L, P, view, head, lean_t)
            _osk_hoses(L, P, view, hx, head, sh, lean_t)
        else:
            # 远臂（右）握撬棍：臂在身后，撬棍画在腿前、大衣后——任何朝向都读得出来
            _al_arm(L, P, [(CX - 1 + lean, sh + 4), (CX - 3 - s * 4, sh + 18),
                           (CX - 4 - s * 5, sh + 33)], True, 0.8)
            _legs(L, P, view, s, c, hip, crouch)
            _al_crowbar(L, P, CX - 4 - s * 5, sh + 33, -8 - s * 6, 34, 0.85)
            lean_t, hem = _al_torso(L, P, view, hip, sh, crouch)
            _al_pack(L, P, view, sh, hip, lean_t)
            _al_belt_gear(L, P, view, hip, lean_t)
            _al_head(L, P, view, head + hunch, lean_t)
            _al_collar(L, P, CX + lean_t * 1.4, head + hunch, view)
            _al_arm(L, P, [(CX + 1 + lean_t, sh + 4), (CX + 2 + s * 4 + lean_t * 0.4, sh + 19),
                           (CX + 3 + s * 7 + lean_t * 0.6, sh + 33)], False)
    else:
        _legs(L, P, view, s, c, hip, crouch)
        if osk:
            lean_t, hem = _osk_torso(L, P, view, hip, sh, crouch)
            if view == "N":
                _osk_back(L, P, view, sh, hip, 0)
            _osk_rifle(L, P, view, sh, hip, 0)
            if view == "S":
                _osk_arm(L, P, [(CX - 13, sh + 5), (CX - 15, sh + 17), (CX - 14, sh + 28)], 0.9)
                _osk_arm(L, P, [(CX + 13, sh + 5), (CX + 15, sh + 17), (CX + 14, sh + 28)])
                _osk_lamp(L, CX + 5.5, sh + 11)                 # 左胸（观众右）
            else:
                _osk_arm(L, P, [(CX - 13, sh + 5), (CX - 15, sh + 17 + sw), (CX - 14, sh + 28 + sw)], 0.9)
                _osk_arm(L, P, [(CX + 13, sh + 5), (CX + 15, sh + 17 - sw), (CX + 14, sh + 28 - sw)])
            hx = _osk_head(L, P, view, head, 0)
            _osk_hoses(L, P, view, hx, head, sh, 0)
        else:
            lean_t, hem = _al_torso(L, P, view, hip, sh, crouch)
            if view == "N":
                _al_pack(L, P, view, sh, hip, 0)
            _al_belt_gear(L, P, view, hip, 0)
            # 右臂（观众左 / N 观众右）低垂握长撬棍
            if view == "S":
                _al_arm(L, P, [(CX - 13, sh + 4), (CX - 15, sh + 19 + sw), (CX - 15, sh + 34 + sw)], True)
                _al_crowbar(L, P, CX - 15, sh + 34 + sw, -5 - sw * 1.2, 36)
                _al_arm(L, P, [(CX + 13, sh + 4), (CX + 15, sh + 19 - sw), (CX + 15, sh + 34 - sw)], False)
            else:
                _al_arm(L, P, [(CX + 13, sh + 4), (CX + 15, sh + 19 - sw), (CX + 15, sh + 34 - sw)], True)
                _al_crowbar(L, P, CX + 15, sh + 34 - sw, 5 + sw * 1.2, 36)
                _al_arm(L, P, [(CX - 13, sh + 4), (CX - 15, sh + 19 + sw), (CX - 15, sh + 34 + sw)], False)
            _al_head(L, P, view, head, 0)
            _al_collar(L, P, CX, head, view)
    return L.finish(outline="#06080b", outline_a=0.9)


def sheet(P) -> Image.Image:
    img = Image.new("RGBA", (FW * 8, FH * 3), (0, 0, 0, 0))
    for row, view in enumerate(("S", "E", "N")):
        cells = [(0.0, False, False)] + [(k / 4, False, True) for k in range(4)] + \
                [(0.0, True, False), (0.25, True, True), (0.75, True, True)]
        for col, (ph, cr, wk) in enumerate(cells):
            img.alpha_composite(frame(P, view, ph, cr, wk), (col * FW, row * FH))
    return img
