"""角色精灵表（CHR_01 阿列克谢 / CHR_05 内务清杀兵 ОСК）— 写实笔触版。

风格目标（依据两张定妆参考图的实测色板）：暗部主导（44–60% 像素明度 < 0.25，
高光只占 3–5%）、中性偏蓝窄色阶、斑驳磨损、无卡通描边。渲染管线：
  多层斑驳上色（大笔触明暗斑 + 中频磨损）→ 成对褶皱（亮棱+暗谷）→
  接触阴影（帽檐/翻领/背带/枪械压出的暗部）→ 磨白亮边 → 胶片颗粒 →
  填充色压暗的软描边（不再用均匀黑描边）。

造型定案来源：用户提供的两张定妆参考图 + 《角色重绘 · 可直接出图的 Prompt》§一/§二。
  阿列克谢：深蓝-黑铁路长大衣（长及小腿）+ 大羊羔毛翻领 + 灰色 ушанка（耳罩放下）+
    圆框眼镜（角色右镜片蛛网裂 + 黑胶布缠右镜腿）+ 冻伤红手（右手背紫蓝印章）+
    高过肩旧帆布背包 + 腰带挂钥匙串与马灯 + 右手低垂长铸铁撬棍 + 灰毡筒靴，消瘦微驼。
  ОСК：密封铅灰偏绿橡胶防护服 + GP-5 面具（双圆玻璃目镜 + 下颚橄榄色圆滤罐）+
    波纹呼吸软管接背负气瓶 + 帆布束带（挎包/水壶）+ 左胸矩形壳体探照灯 +
    消音 AKM（长圆柱消音器）右肩→左髋斜挎 + 厚橡胶手套与绝缘靴；无脸、像一堵墙。

引擎硬规格（保持不变，否则场景要重排）：
  每帧 72×112、pivot 脚底中心 (36,108)、行序 S/E/N、
  列序 0 待机 · 1-4 行走 · 5 蹲待机 · 6-7 蹲走；W = E 水平翻转（引擎 flip_h）。
"""
from __future__ import annotations

import math
import numpy as np
from PIL import Image, ImageFilter

from artlib import Layer, hexc, smooth, blur

FW, FH = 72, 112
GY_ = 108
CX = 36

ALEKSEI = dict(
    kind="aleksei",
    trousers="#232a35", trousers_dk="#141a22",      # 旧保暖裤（暗）
    boots="#4e4b44", boot_shaft="#666156",          # 灰色毡筒靴 valenki（压暗，别抢脸）
    coat="#141b26", coat_dk="#0a0e15", coat_lt="#2b3646",   # 深蓝-黑长大衣（参考图明度）
    collar="#a8a08c", collar_dk="#6f6a5c", collar_lt="#d3cdbd",  # 大羊羔毛翻领
    hat="#454b52", hat_dk="#2a2f35", hat_lt="#686e75",      # 灰色 ушанка
    skin="#8f6c58", skin_dk="#5d4234", skin_lt="#b58f74",
    pack="#57492f", pack_dk="#352b1c", pack_lt="#7c6a47",  # 旧帆布背包
    hand="#7c4a3f", stamp="#4a4380",                # 冻伤红手 / 紫蓝印章
    iron="#202329", iron_lt="#454c56", rust="#5c4128",     # 铸铁撬棍
    belt="#241d17", buckle="#6b6455",               # 皮带/带扣
    lantern="#262a30", lantern_glass="#6b5c40",     # 马灯
)
OSK = dict(
    kind="osk",
    trousers="#28323a", trousers_dk="#161e25",      # 铅灰偏蓝橡胶连体服（参考图明度）
    boots="#14171b", boot_shaft="#20262b",          # 厚重绝缘靴
    coat="#2d383e", coat_dk="#182128", coat_lt="#6c7a83",
    collar=None,
    hat="#39434a", hat_dk="#202a30", hat_lt="#74828c",
    skin=None,                                      # 无脸
    pack=None,
    hand="#16191d", stamp=None,
    iron="#23282e", iron_lt="#4c545c", rust="#3c2e1c",     # 消音 AKM 金属 / 木件
    filter="#565c4d", filter_dk="#33382c", filter_lt="#7d8472",   # 下颚滤罐
    hose="#39434b", tank="#39424a", tank_dk="#232b31", tank_lt="#6b7880",
    web="#575244", pouch="#514c3e", buckle="#6e685a",   # 帆布束带/挎包/扣件
    leg_w=12.0, boot_w=7.2, boot_shaft_w=6.0, boot_snow_w=4.6,
)


# ---------------------------------------------------------------------------
# 写实笔触层（本文件专用；gen_rabid 不经过这里）
# ---------------------------------------------------------------------------
def _fill(L, mask, base, dark, light, seed, streak=True):
    """多层斑驳上色：底色 → 大笔触明暗斑 → 中频磨损。拒绝平涂。"""
    L.paint(mask, hexc(base))
    n1 = L.noise(6.5, seed, cy=11.0 if streak else 6.5)
    L.paint(mask * smooth(0.42, 0.72, n1), hexc(light), 0.5)
    L.paint(mask * smooth(0.58, 0.26, n1), hexc(dark), 0.38)
    n2 = L.noise(2.7, seed + 17)
    L.paint(mask * smooth(0.52, 0.88, n2), hexc(light), 0.25)
    L.paint(mask * smooth(0.55, 0.18, n2), hexc(dark), 0.22)


def _fold_pair(L, pts, w, hi, lo, a=1.0):
    """布褶成对：亮棱（受光侧）+ 暗谷（背光侧）。"""
    L.paint(L.line([(x - 0.7, y - 0.7) for x, y in pts], w * 0.7), hexc(hi), 0.5 * a)
    L.paint(L.line([(x + 0.8, y + 0.8) for x, y in pts], w), hexc(lo), 0.55 * a)


def _contact(L, mask, dx=0.5, dy=1.8, r=1.5, alpha=0.42):
    """接触阴影：上层物体压在下层上的暗部（写实的关键）。"""
    sh = np.roll(np.roll(mask, int(round(dy * L.ss)), 0), int(round(dx * L.ss)), 1)
    sh = blur(sh, r * L.ss) * (1.0 - np.clip(mask * 1.2, 0, 1))
    L.paint(sh, hexc("#05070b"), alpha)


def _edge_wear(L, mask, color, seed, alpha=0.3):
    """磨白/掉漆亮边。"""
    e = np.clip(mask - np.roll(np.roll(mask, L.ss, 0), L.ss, 1), 0, 1)
    L.paint(e * (L.noise(1.8, seed) > 0.45), hexc(color), alpha)


def _outline_soft(img, strength=0.8, darken=0.45, tint="#0a0d12"):
    """填充色压暗的软描边：替代均匀黑描边，去掉贴纸感。"""
    a = np.asarray(img, np.float32)
    alpha = a[..., 3]
    m = (alpha > 10).astype(np.uint8) * 255
    dil = np.asarray(Image.fromarray(m, "L").filter(ImageFilter.MaxFilter(3)), np.float32) / 255.0
    ring = np.clip(dil - m / 255.0, 0, 1)
    rgb = a[..., :3] / 255.0
    fillc = np.stack([blur(rgb[..., i], 1.5) for i in range(3)], -1)
    ec = fillc * darken + hexc(tint)[None, None, :] * (1 - darken)
    w = (ring * strength)[..., None]
    out_rgb = np.clip(rgb * (1 - w) + ec * w, 0, 1) * 255.0
    out_a = np.clip(alpha + ring * strength * 255.0, 0, 255)
    return Image.fromarray(np.dstack([out_rgb, out_a]).astype(np.uint8), "RGBA")


def _grain(img, amt=4.0, seed=99):
    """胶片颗粒（只作用于不透明像素）。"""
    a = np.asarray(img, np.float32)
    rng = np.random.default_rng(seed)
    n = rng.normal(0.0, amt, a.shape[:2])[..., None]
    m = (a[..., 3:] > 0)
    a[..., :3] = np.clip(a[..., :3] + n * m, 0, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


# ---------------------------------------------------------------------------
# 共享底层（gen_rabid 也用：_limb / _legs 签名与行为保持逐像素不变）
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
# 阿列克谢（写实笔触）
# ---------------------------------------------------------------------------
def _al_torso(L, P, view, hip, sh, crouch):
    """深蓝-黑铁路长大衣：斑驳布面 + 成对褶皱 + 腰带 + 磨边。"""
    lean = 7.0 if (crouch and view == "E") else 0.0
    hem = hip + (17 if crouch else 26)
    if view == "E":
        pts = [(CX - 8 + lean, sh - 1), (CX + 7 + lean, sh + 1), (CX + 10, sh + 8),
               (CX + 11, hem), (CX - 11, hem), (CX - 10, sh + 8)]
    else:
        pts = [(CX - 11, sh - 1), (CX - 6, sh - 3), (CX + 6, sh - 3), (CX + 11, sh - 1),
               (CX + 13, sh + 8), (CX + 15, hem), (CX - 15, hem), (CX - 13, sh + 8)]
    m = L.poly(pts)
    _fill(L, m, P["coat"], P["coat_dk"], P["coat_lt"], 7)
    L.shade(m, L.gx(CX - 15, CX + 15, 1.32, 0.7))        # 光自左上来（受光面提亮）
    L.shade(m, L.gy(sh, hem, 1.14, 0.74))
    # 成对褶皱（竖向，随摆幅略展）
    folds = (-9.5, -2.5, 5.5, 11.5) if view != "E" else (-6, 0.5, 7.5)
    for fx in folds:
        _fold_pair(L, [(CX + fx + lean * 0.3, sh + 7), (CX + fx * 1.06 + lean * 0.15, hem - 4)],
                   1.1, P["coat_lt"], P["coat_dk"], 0.85)
    # 衣襟缝线 / 大扣（扣子带高光点）
    if view == "S":
        L.paint(L.rect(CX - 0.7, sh + 2, CX + 0.7, hem) * m, hexc(P["coat_dk"]), 0.85)
        for by in (sh + 6, sh + 14, sh + 22, sh + 30, sh + 38):
            if by < hem - 2:
                L.paint(L.ellipse(CX + 3.4, by, 1.3, 1.3) * m, hexc("#0b0f15"))
                L.paint(L.ellipse(CX + 3.0, by - 0.5, 0.55, 0.55) * m, hexc("#6a7488"), 0.8)
    # 腰带（接触阴影 + 带扣）
    by0 = hip - 3
    _contact(L, L.rect(CX - 15, by0, CX + 15, by0 + 3.6, 1), 0, 1.6, 1.2, 0.5)
    belt = L.rect(CX - 15, by0, CX + 15, by0 + 3.6, 1) * m
    L.paint(belt, hexc(P["belt"]))
    L.paint(L.rect(CX - 3.2, by0 - 0.4, CX + 3.2, by0 + 4.0, 1) * m, hexc(P["buckle"]) * 0.8)
    L.paint(L.rect(CX - 1.6, by0 + 0.7, CX + 1.6, by0 + 2.9, 0.6) * m, hexc(P["belt"]))
    L.paint(L.rect(CX - 3.2, by0 - 0.4, CX - 1.8, by0 + 0.8) * m, hexc(P["buckle"]), 0.7)  # 扣面高光
    _edge_wear(L, m, "#33405a", 12, 0.26)               # 磨白
    L.rim(m, -1.3, -0.9, "#55678a", 0.65)               # 顶棱冷高光（受光面）
    L.rim(m, 0, -1.1, "#05070b", 0.35)
    return lean, hem


def _al_collar(L, P, hx, head, view, base_mask=None):
    """大羊羔毛翻领：绒毛斑驳 + 压在大衣上的接触阴影。"""
    if base_mask is not None:
        _contact(L, base_mask, 0.4, 2.2, 2.0, 0.5)
    col_d, col_l = P["collar_dk"], P["collar_lt"]
    if view == "N":
        m = L.rect(hx - 11.5, head + 9, hx + 11.5, head + 16.5, 2.6)
        _fill(L, m, P["collar"], col_d, col_l, 21, streak=False)
        L.shade(m, L.gy(head + 9, head + 16.5, 1.1, 0.72))
        for kx in (-6, 0, 6):   # 绒毛分簇
            L.paint(L.rect(hx + kx - 0.8, head + 10, hx + kx + 0.8, head + 15.5) * m, hexc(col_d), 0.5)
        return
    xs = (-1,) if view == "E" else (-1, 1)
    masks = []
    for sx in xs:
        x0, x1 = (hx - 11.5, hx - 2.4) if sx < 0 else (hx + 2.4, hx + 11.5)
        m = L.rect(x0, head + 9.5, x1, head + 18, 2.6)
        masks.append(m)
        _fill(L, m, P["collar"], col_d, col_l, 23, streak=False)
        L.shade(m, L.gx(hx - 11, hx + 11, 1.14, 0.72))
        L.paint(L.rect(x0, head + 15.6, x1, head + 17.8, 1.4) * m, hexc(col_d), 0.6)  # 绒毛根部
        n = L.noise(1.5, 27)
        L.paint(m * smooth(0.62, 0.85, n), hexc(col_l), 0.5)                          # 绒毛尖
    if view == "E":
        m = L.rect(hx - 10, head + 9.5, hx + 2, head + 15, 2.4)
        _fill(L, m, P["collar"], col_d, col_l, 24, streak=False)
        L.shade(m, 0.72)
    return masks


def _al_head(L, P, view, head, lean):
    """瘦削脸（暗部主导）+ 圆框眼镜（右镜蛛网裂 + 黑胶布）+ ушанка（含帽檐接触阴影）。"""
    hx = CX + (lean * 1.4 if view == "E" else 0)
    hat_d, hat_l = P["hat_dk"], P["hat_lt"]
    if view == "S":
        face = L.ellipse(hx, head + 2.5, 6.8, 8.4)
        _fill(L, face, P["skin"], P["skin_dk"], P["skin_lt"], 25, streak=False)
        L.shade(face, L.gx(hx - 7, hx + 7, 1.16, 0.7))
        L.paint(L.ellipse(hx - 3.8, head + 4.4, 2.5, 1.9) * face, hexc(P["skin_dk"]), 0.5)   # 颧凹
        L.paint(L.ellipse(hx + 3.8, head + 4.4, 2.5, 1.9) * face, hexc(P["skin_dk"]), 0.5)
        for ex in (-2.9, 2.9):
            L.paint(L.ellipse(hx + ex, head + 1.6, 1.9, 1.4) * face, hexc("#241a15"), 0.75)   # 眼窝
            L.paint(L.ellipse(hx + ex, head + 1.7, 1.15, 0.85), hexc("#120d0b"))              # 眼
            L.paint(L.ellipse(hx + ex, head + 3.4, 2.0, 0.85), hexc(P["skin_dk"]), 0.7)       # 眼袋
            L.paint(L.rect(hx + ex - 2.0, head - 0.8, hx + ex + 2.0, head + 0.1, 0.6),
                    hexc("#2c211a"), 0.8)                                                     # 眉
        L.paint(L.rect(hx - 0.9, head + 2.8, hx + 0.6, head + 5.2, 0.6), hexc(P["skin_dk"]), 0.7)  # 鼻影
        L.paint(L.rect(hx - 0.3, head + 2.6, hx + 0.6, head + 4.6), hexc(P["skin_lt"]), 0.45)      # 鼻梁
        L.paint(L.rect(hx - 2.3, head + 6.9, hx + 2.3, head + 7.7, 0.5), hexc("#3c2a20"), 0.85)    # 嘴
        L.paint(face * smooth(0.55, 0.85, L.noise(1.6, 25)), hexc("#463629"), 0.35)                # 胡茬
        # —— 圆框金属眼镜 ——
        gl = hexc("#3c434c")
        for ex in (-2.9, 2.9):
            L.paint(L.arc(hx + ex, head + 1.6, 2.85, 2.7, 0, 360, 1.3), gl)
            L.paint(L.ellipse(hx + ex - 1.0, head + 0.3, 0.75, 0.55), hexc("#aeb9c4"), 0.8)
        L.paint(L.line([(hx - 0.2, head + 1.4), (hx + 0.2, head + 1.4)], 1.1, False), gl)
        L.paint(L.line([(hx - 5.7, head + 1.4), (hx - 7.1, head + 1.9)], 1.1, False), gl)
        L.paint(L.line([(hx + 5.7, head + 1.4), (hx + 7.1, head + 1.9)], 1.1, False), gl)
        # 角色右镜片（观众左）：蛛网裂
        rx, ry = hx - 2.9, head + 1.6
        for ang in (35, 115, 205, 290):
            a = math.radians(ang)
            L.paint(L.line([(rx, ry), (rx + 2.6 * math.cos(a), ry + 2.4 * math.sin(a))], 0.55, False),
                    hexc("#d5dee7"), 0.85)
        L.paint(L.arc(rx, ry, 1.6, 1.5, 0, 360, 0.5), hexc("#d5dee7"), 0.7)
        L.paint(L.rect(hx - 7.6, head + 0.6, hx - 5.2, head + 2.7, 0.9), hexc("#0d1014"))   # 黑胶布
    elif view == "E":
        face = L.ellipse(hx + 2, head + 2.5, 6.3, 8.2)
        _fill(L, face, P["skin"], P["skin_dk"], P["skin_lt"], 26, streak=False)
        L.shade(face, L.gx(hx - 5, hx + 9, 1.14, 0.68))
        L.paint(L.ellipse(hx + 8.3, head + 3.8, 1.5, 2.1), hexc(P["skin"]) * 0.85)   # 鼻
        L.paint(L.ellipse(hx + 5.0, head + 1.6, 1.8, 1.4) * face, hexc("#241a15"), 0.7)
        L.paint(L.ellipse(hx + 5.1, head + 1.7, 1.1, 0.85), hexc("#120d0b"))
        L.paint(L.ellipse(hx + 4.2, head + 3.4, 1.8, 0.85), hexc(P["skin_dk"]), 0.65)
        L.paint(L.rect(hx + 5.0, head + 7.0, hx + 8.0, head + 7.8, 0.5), hexc("#3c2a20"), 0.85)
        L.paint(face * smooth(0.55, 0.85, L.noise(1.6, 26)), hexc("#463629"), 0.32)
        L.paint(L.arc(hx + 4.6, head + 1.6, 2.65, 2.5, 0, 360, 1.3), hexc("#3c434c"))
        L.paint(L.ellipse(hx + 3.8, head + 0.4, 0.75, 0.55), hexc("#aeb9c4"), 0.8)
        L.paint(L.line([(hx + 2.1, head + 1.5), (hx - 4.8, head + 1.8)], 1.1, False), hexc("#3c434c"))
        L.paint(L.line([(hx + 3.0, head + 1.2), (hx + 3.8, head + 2.5)], 0.55, False), hexc("#d5dee7"), 0.8)
        L.paint(L.rect(hx - 2.8, head + 0.8, hx - 0.5, head + 2.6, 0.9), hexc("#0d1014"))
    # —— 帽檐接触阴影（写实关键：眼周压暗）——
    if view != "N":
        brim = L.rect(hx - 10.2, head - 8.2, hx + 10.2, head - 3.6, 2)
    else:
        brim = L.ellipse(hx, head - 1.5, 10.0, 9.0)
    _contact(L, brim, 0.3, 2.4, 1.8, 0.55)
    # —— ушанка ——
    if view != "N":
        dome = L.ellipse(hx + (1 if view == "E" else 0), head - 5.8, 10.0, 6.2)
        _fill(L, dome, P["hat"], hat_d, hat_l, 31, streak=False)
        L.shade(dome, L.gx(hx - 10, hx + 10, 1.18, 0.62))
        band = L.rect(hx - 10.0, head - 8.2, hx + 10.0, head - 4.4, 2)
        _fill(L, band, P["hat_lt"], P["hat"], "#8d939a", 32, streak=False)
        if view == "E":
            m = L.rect(hx - 5.2, head - 2.5, hx + 0.6, head + 9.5, 2.2)
            _fill(L, m, P["hat"], hat_d, hat_l, 33, streak=False)
            flaps = [(-10.0, -4.4)]
        else:
            flaps = [(-11.4, -5.8), (5.8, 11.4)]
        for a, b in flaps:
            m = L.rect(hx + a, head - 2.5, hx + b, head + 9.5, 2.2)
            _fill(L, m, P["hat"], hat_d, hat_l, 34, streak=False)
            L.shade(m, L.gx(hx - 11, hx + 11, 1.14, 0.66))
            L.paint(L.rect(hx + a, head + 6.4, hx + b, head + 8.8, 1.6) * m, hexc(hat_l), 0.7)  # 毛边
            n = L.noise(1.4, 35)
            L.paint(m * smooth(0.66, 0.9, n), hexc(hat_l), 0.45)                                 # 绒毛
    else:
        dome = L.ellipse(hx, head - 1.5, 10.0, 9.0)
        _fill(L, dome, P["hat"], hat_d, hat_l, 36, streak=False)
        L.shade(dome, L.gx(hx - 10, hx + 10, 1.18, 0.62))
        for sx in (-1, 1):
            m = L.rect(hx + sx * 9.6 - 3, head - 1, hx + sx * 9.6 + 3, head + 9.5, 2.2)
            _fill(L, m, P["hat"], hat_d, hat_l, 37, streak=False)
        L.paint(L.rect(hx - 1.0, head - 8, hx + 1.0, head + 6), hexc(P["hat_dk"]), 0.8)
    L.snow_cap(hx - 8, hx + 8, head - 11.5, 4, 35, droop=0.1)


def _al_hand(L, P, x, y, right_hand, dim=1.0):
    """冻伤红手：指端发紫；right_hand=True 时手背盖紫蓝印章。"""
    m = L.ellipse(x, y + 1, 3.5, 3.9)
    L.paint(m, hexc(P["hand"]) * dim)
    L.shade(m, L.gy(y - 3, y + 5, 1.06, 0.7) * dim)
    L.paint(L.ellipse(x, y + 3.2, 2.8, 1.6) * m, hexc(P["stamp"]), 0.42 * dim)   # 指端冻伤发紫
    L.paint(L.ellipse(x - 1.4, y - 0.4, 1.6, 1.1) * m, hexc("#a86455"), 0.5 * dim)  # 指节
    if right_hand:
        L.paint(L.ellipse(x + 0.3, y - 0.3, 1.8, 1.2), hexc(P["stamp"]), 1.0)    # 印章
    L.paint(L.rect(x - 2.6, y + 3.3, x + 2.6, y + 4.1, 1), hexc("#4e2822"), 0.55 * dim)


def _al_arm(L, P, pts, right_hand, dim=1.0, swing=0.0):
    """袖子：暗布面 + 腕部成对褶皱 + 袖口束带。"""
    m = L.line(pts, 8.2)
    _fill(L, m, P["coat"], P["coat_dk"], P["coat_lt"], 41)
    L.shade(m, L.gx(min(p[0] for p in pts) - 5, max(p[0] for p in pts) + 5, 1.16, 0.7) * dim)
    hx, hy = pts[-1]
    c0 = pts[-2]
    cx_, cy_ = c0[0] + (hx - c0[0]) * 0.7, c0[1] + (hy - c0[1]) * 0.7
    cuff = L.line([(cx_, cy_), (hx, hy)], 9.2)
    L.paint(cuff * m, hexc(P["coat_lt"]), 0.5)
    _fold_pair(L, [(cx_, cy_), (hx, hy)], 1.1, P["coat_lt"], P["coat_dk"], 0.8)  # 腕褶
    _al_hand(L, P, hx, hy + 1, right_hand, dim)
    return m


def _al_crowbar(L, P, x, y, angle_deg, length=36.0, dim=1.0):
    """长铸铁撬棍：杆 + 撬头，锈迹斑斑、棱上有一线冷高光。"""
    a = math.radians(angle_deg)
    x2, y2 = x + math.sin(a) * length, y + math.cos(a) * length
    x1, y1 = x - math.sin(a) * 13, y - math.cos(a) * 13
    under = L.line([(x1, y1), (x2, y2)], 4.4)
    L.paint(under, hexc("#07090d"))
    m = L.line([(x1, y1), (x2, y2)], 3.1)
    _fill(L, m, P["iron"], "#0e1116", P["iron_lt"], 44, streak=False)
    L.rim(m, -1.1, -0.5, P["iron_lt"], 0.6 * dim)                # 棱线冷高光
    L.paint(m * smooth(0.55, 0.85, L.noise(2.2, 44)), hexc(P["rust"]), 0.55 * dim)   # 锈
    hook = L.line([(x2, y2), (x2 + math.copysign(3.8, math.sin(a) if abs(math.sin(a)) > 0.2 else -1),
                   y2 + 3.6)], 3.2)
    L.paint(hook, hexc(P["iron"]) * dim)
    L.rim(hook, -1, 0, P["iron_lt"], 0.5 * dim)
    L.paint(L.ellipse(x1, y1, 1.9, 1.9), hexc(P["iron"]) * dim)


def _al_pack(L, P, view, sh, hip, lean):
    """旧帆布背包：斑驳帆布 + 扣带 + 压在大衣上的接触阴影。"""
    if view == "N":
        m = L.rect(CX - 11, sh - 5, CX + 11, hip + 3, 4)
    elif view == "E":
        m = L.rect(CX - 18 + lean * 0.5, sh - 5, CX - 6 + lean * 0.5, hip - 3, 4)
    else:
        for sx in (-7.5, 7.5):
            L.paint(L.rect(CX + sx - 1.8, sh - 2, CX + sx + 1.8, sh + 17, 1.2), hexc(P["pack"]))
            L.paint(L.ellipse(CX + sx, sh + 13, 1.7, 1.3), hexc(P["pack_dk"]))
        return
    _contact(L, m, 0.6, 2.4, 2.2, 0.55)                  # 压在大衣上的影
    _fill(L, m, P["pack"], P["pack_dk"], P["pack_lt"], 21)
    L.shade(m, L.gy(sh - 5, hip + 3, 1.14, 0.62))
    if view == "N":
        flap = L.rect(CX - 11, sh - 5, CX + 11, sh + 6, 3)
        _fill(L, flap, P["pack_lt"], P["pack_dk"], "#93815c", 22, streak=False)
        L.shade(flap, L.gy(sh - 5, sh + 6, 1.1, 0.75))
        L.paint(L.rect(CX - 11, sh + 5.4, CX + 11, sh + 6.8), hexc(P["pack_dk"]))
        for x in (CX - 8, CX + 8):
            L.paint(L.rect(x - 1.6, sh - 5, x + 1.6, hip + 1, 1), hexc(P["pack_dk"]))
            L.paint(L.ellipse(x, sh + 12, 1.6, 1.3), hexc(P["buckle"]) * 0.7)
        sub = L.rect(CX - 5, sh + 14, CX + 5, sh + 20, 2)
        _fill(L, sub, P["pack"], P["pack_dk"], P["pack_lt"], 23, streak=False)
    else:
        flap = L.rect(CX - 18 + lean * 0.5, sh - 5, CX - 6 + lean * 0.5, sh + 5, 2.5) * m
        _fill(L, flap, P["pack_lt"], P["pack_dk"], "#93815c", 24, streak=False)
        L.paint(L.rect(CX - 15 + lean * 0.5, sh + 12, CX - 9 + lean * 0.5, sh + 18, 1.5) * m,
                hexc(P["pack_dk"]))
    _edge_wear(L, m, "#8a7852", 25, 0.3)
    L.paint(L.rect((CX - 11) if view == "N" else (CX - 18 + lean * 0.5), sh - 6,
                   (CX + 11) if view == "N" else (CX - 6 + lean * 0.5), sh - 2.4), hexc("#c9d3dc"), 0.6)  # 顶雪


def _al_belt_gear(L, P, view, hip, lean):
    """腰带挂件：右髋钥匙串、左髋马灯（均带接触阴影）。"""
    keys = hexc(P["buckle"]) * 0.75
    if view == "S":
        kx, lx = CX - 8, CX + 9
    elif view == "N":
        kx, lx = CX + 8, CX - 9
    else:
        kx, lx = CX - 5 + lean * 0.5, CX + 8 + lean * 0.5
    gear = L.rect(kx - 3, hip, kx + 3, hip + 10, 2) + L.rect(lx - 3.4, hip, lx + 3.4, hip + 13, 2)
    _contact(L, gear, 0.4, 1.8, 1.4, 0.5)
    # 钥匙串
    L.paint(L.arc(kx, hip + 1.5, 1.8, 1.8, 0, 360, 0.8), keys)
    for dx in (-1.2, 1.2):
        L.paint(L.rect(kx + dx - 0.5, hip + 3, kx + dx + 0.5, hip + 7.5, 0.5), keys)
        L.paint(L.ellipse(kx + dx, hip + 8.2, 1.0, 1.2), keys * 0.85)
    # 马灯
    L.paint(L.arc(lx, hip + 1.0, 2.6, 2.2, 180, 360, 0.9), hexc(P["buckle"]) * 0.65)
    L.paint(L.rect(lx - 2.2, hip + 1.2, lx + 2.2, hip + 3.0, 0.8), hexc(P["lantern"]))
    body = L.rect(lx - 2.8, hip + 3.0, lx + 2.8, hip + 10.5, 1.6)
    L.paint(body, hexc(P["lantern"]))
    L.shade(body, L.gx(lx - 3, lx + 3, 1.35, 0.6))
    L.paint(L.rect(lx - 2.0, hip + 4.4, lx + 2.0, hip + 9.2, 1.2), hexc(P["lantern_glass"]), 0.9)
    L.paint(L.rect(lx - 1.6, hip + 4.8, lx - 0.6, hip + 8.8), hexc("#8c7a52"), 0.5)   # 玻璃反光
    L.paint(L.rect(lx - 2.2, hip + 10.2, lx + 2.2, hip + 11.8, 0.8), hexc(P["lantern"]))


# ---------------------------------------------------------------------------
# 内务清杀兵 ОСК（写实笔触）
# ---------------------------------------------------------------------------
def _hose(L, pts, w, color, ring="#161c21"):
    """波纹呼吸软管：主管 + 波纹环。"""
    m = L.line(pts, w)
    L.paint(m, hexc(color))
    L.shade(m, L.gy(min(p[1] for p in pts) - 2, max(p[1] for p in pts) + 2, 1.3, 0.6))
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        d = math.hypot(x1 - x0, y1 - y0)
        n = max(1, int(d / 2.6))
        for k in range(n + 1):
            t = k / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            L.paint(L.ellipse(x, y, w * 0.62, w * 0.62) * m, hexc(ring), 0.6)
    return m


def _osk_torso(L, P, view, hip, sh, crouch):
    """铅灰橡胶防护服：斑驳橡胶 + 竖褶皱成对 + 裂纹 + 束带/挎包/水壶。"""
    lean = 6.0 if (crouch and view == "E") else 0.0
    hem = hip + (14 if crouch else 19)
    if view == "E":
        pts = [(CX - 11 + lean, sh - 1), (CX + 8 + lean, sh - 1), (CX + 12, sh + 7),
               (CX + 12, hem), (CX - 12, hem), (CX - 13, sh + 7)]
    else:
        pts = [(CX - 13, sh - 2), (CX - 7, sh - 4), (CX + 7, sh - 4), (CX + 13, sh - 2),
               (CX + 16, sh + 8), (CX + 16, hem), (CX - 16, hem), (CX - 16, sh + 8)]
    m = L.poly(pts)
    _fill(L, m, P["coat"], P["coat_dk"], P["coat_lt"], 7)
    L.shade(m, L.gx(CX - 16, CX + 16, 1.38, 0.66))
    L.shade(m, L.gy(sh, hem, 1.12, 0.72))
    # 竖褶皱成对
    folds = (-11, -5.5, 0.5, 6.5, 12) if view != "E" else (-8, -2, 4, 9)
    for fx in folds:
        _fold_pair(L, [(CX + fx + lean * 0.35, sh + 6), (CX + fx * 1.06 + lean * 0.2, hem - 3)],
                   1.1, P["coat_lt"], P["coat_dk"], 0.85)
    # 老化裂纹（亮暗成对）
    r = np.random.default_rng(52)
    for _ in range(4):
        x0 = CX + r.uniform(-12, 12) + lean * 0.5
        y0 = r.uniform(sh + 5, hem - 6)
        pts = [(x0, y0), (x0 + r.uniform(-3, 3), y0 + r.uniform(3, 7)),
               (x0 + r.uniform(-5, 5), y0 + r.uniform(7, 12))]
        L.paint(L.line(pts, 0.6, False) * m, hexc("#0d1216"), 0.75)
        L.paint(L.line([(x - 0.7, y - 0.6) for x, y in pts], 0.5, False) * m, hexc(P["coat_lt"]), 0.35)
    L.grime(m, 8, 0.22, 4.5)
    L.rust_streaks(m, 9, 0.14, "#4a3c2c", (2.2, 12))
    _edge_wear(L, m, "#7c8a92", 10, 0.3)                # 橡胶磨亮边
    # 腰带 + 帆布束带
    L.paint(L.rect(CX - 16, hip - 3, CX + 16, hip + 1.2) * m, hexc("#12171c"))
    L.paint(L.rect(CX - 16, hip - 3, CX + 16, hip - 1.8) * m, hexc("#49525a"), 0.5)
    web = hexc(P["web"])
    web_lt = hexc(P["pouch"]) * 1.18
    def strap(x0, y0, x1, y1, w):
        sm = L.line([(x0, y0), (x1, y1)], w)
        _contact(L, sm, 0.4, 1.4, 1.1, 0.45)
        L.paint(sm, web)
        L.paint(L.line([(x0 - 0.6, y0 - 0.6), (x1 - 0.6, y1 - 0.6)], w * 0.35), web_lt, 0.4)
    if view == "S":
        for sx in (-8, 8):
            strap(CX + sx, sh + 1, CX + sx, hip - 2, 3.2)
        strap(CX - 14, sh + 13, CX + 14, sh + 13, 3.2)
        L.paint(L.rect(CX - 2.4, sh + 11.6, CX + 2.4, sh + 15.8, 0.8) * m, hexc(P["buckle"]) * 0.7)
        for px in (-11, 11):
            pm = L.rect(CX + px - 3.4, sh + 17, CX + px + 3.4, sh + 24, 1.4)
            _contact(L, pm, 0.4, 1.6, 1.3, 0.5)
            _fill(L, pm, P["pouch"], "#3a3629", "#7d7762", 55, streak=False)
            L.paint(L.rect(CX + px - 3.4, sh + 16.2, CX + px + 3.4, sh + 18.4, 1.2), hexc("#3a3629"))
    elif view == "E":
        strap(CX + 10 + lean, sh + 3, CX - 10, hip - 3, 3.0)
        strap(CX - 14, sh + 13, CX + 11, sh + 13, 3.0)
    else:
        for sx in (-8, 8):
            strap(CX + sx, sh + 1, CX + sx, hip - 2, 3.2)
        strap(CX + 12, sh + 1, CX - 8, hip - 3, 3.0)
    # 腰间水壶（左髋）/ 杂物包（右髋）
    def pouch(x0, x1, y0, y1, seed):
        pm = L.rect(x0, y0, x1, y1, 2)
        _contact(L, pm, 0.4, 1.6, 1.3, 0.5)
        _fill(L, pm, P["pouch"], "#3a3629", "#7d7762", seed, streak=False)
    if view == "S":
        pouch(CX + 9, CX + 15, hip + 1, hip + 11, 56)
        L.paint(L.rect(CX + 10, hip - 1, CX + 14, hip + 2, 1), hexc("#3a3629"))
        pouch(CX - 15, CX - 9, hip + 1, hip + 9, 57)
    elif view == "E":
        pouch(CX + 6, CX + 12, hip + 1, hip + 11, 58)
    else:
        pouch(CX - 15, CX - 9, hip + 1, hip + 11, 59)
        pouch(CX + 9, CX + 15, hip + 1, hip + 9, 60)
    L.rim(m, -1.5, -0.8, "#93a2ad", 0.65)
    L.rim(m, 0, -1.1, "#05070b", 0.35)
    return lean, hem


def _osk_lamp(L, x, y, dim=1.0):
    """胸前高流明探照灯：矩形壳体 + 大圆灯罩（光晕小、壳体有明暗）。"""
    house = L.rect(x - 4.6, y - 4.2, x + 4.6, y + 4.2, 1.6)
    _contact(L, house, 0.4, 1.8, 1.5, 0.55)
    L.paint(house, hexc("#20262b") * dim)
    L.shade(house, L.gx(x - 5, x + 5, 1.5, 0.55) * dim)
    L.paint(L.rect(x - 4.6, y - 4.2, x + 4.6, y - 2.6, 1) * 1.0, hexc("#454d55") * dim, 0.8)
    for rx in (-2.6, 0, 2.6):
        L.paint(L.rect(x + rx - 0.5, y + 2.6, x + rx + 0.5, y + 3.9), hexc("#454d55") * dim, 0.7)
    L.paint(L.ellipse(x, y - 0.3, 3.1, 3.1), hexc("#f2e3b8") * dim)      # 灯罩
    L.paint(L.ellipse(x - 0.8, y - 1.1, 1.25, 1.25), hexc("#fff8e6") * dim)
    L.paint(L.ellipse(x, y, 5.6, 5.6), hexc("#ffe9b0"), 0.14 * dim)      # 微光晕


def _osk_head(L, P, view, head, lean):
    """GP-5 面具：双圆玻璃目镜 + 下颚橄榄色滤罐；帽兜接触阴影。"""
    hx = CX + (lean * 1.2 if view == "E" else 0)
    hood = L.ellipse(hx + (1 if view == "E" else 0), head, 9.8, 10.2)
    _contact(L, hood, 0.3, 2.2, 1.8, 0.5)
    _fill(L, hood, P["hat"], P["hat_dk"], P["hat_lt"], 41, streak=False)
    L.shade(hood, L.gx(hx - 10, hx + 10, 1.2, 0.56))
    L.rim(hood, -1.5, -1, "#7e8a95", 0.55)
    flt_d, flt_l = P["filter_dk"], P["filter_lt"]
    if view == "S":
        plate = L.ellipse(hx, head + 1.6, 7.6, 8.4)
        _fill(L, plate, P["hat_dk"], "#141b21", P["hat"], 42, streak=False)
        for ex in (-3.3, 3.3):                       # 双圆玻璃目镜
            L.paint(L.ellipse(hx + ex, head - 1.2, 3.25, 3.25), hexc("#1d242a"))
            L.paint(L.ellipse(hx + ex, head - 1.2, 2.55, 2.55), hexc("#0e161d"))
            L.paint(L.ellipse(hx + ex - 0.8, head - 2.1, 1.05, 0.75), hexc("#c3ced9"), 0.95)  # 冷反光
            L.paint(L.rect(hx + ex - 1.7, head - 1.2, hx + ex + 1.7, head - 0.6), hexc("#1c2c36"), 0.55)
            L.paint(L.arc(hx + ex, head - 1.2, 3.25, 3.25, 0, 360, 0.7), hexc("#4c565f"))     # 金属圈
        # 下颚滤罐（橄榄色）
        fm = L.ellipse(hx, head + 7.2, 3.3, 3.0)
        _contact(L, fm, 0.3, 1.6, 1.3, 0.55)
        _fill(L, fm, P["filter"], flt_d, flt_l, 43, streak=False)
        L.paint(L.ellipse(hx, head + 6.8, 3.9, 3.5), hexc(P["coat_dk"]), 0.85)   # 罐口沿
        L.paint(L.arc(hx, head + 7.2, 2.2, 2.0, 0, 360, 0.75), hexc(flt_d))
        L.paint(L.ellipse(hx, head + 7.2, 0.8, 0.8), hexc(flt_d) * 0.7)
        L.paint(L.ellipse(hx - 1.1, head + 6.0, 1.1, 0.6), hexc(flt_l), 0.5)
    elif view == "E":
        L.paint(L.ellipse(hx + 4.4, head - 1.2, 3.0, 3.0), hexc("#1d242a"))
        L.paint(L.ellipse(hx + 4.4, head - 1.2, 2.3, 2.3), hexc("#0e161d"))
        L.paint(L.ellipse(hx + 3.8, head - 2.0, 0.9, 0.65), hexc("#c3ced9"), 0.95)
        L.paint(L.arc(hx + 4.4, head - 1.2, 3.0, 3.0, 0, 360, 0.7), hexc("#4c565f"))
        fm = L.ellipse(hx + 8.2, head + 6.2, 3.0, 3.2)
        _fill(L, fm, P["filter"], flt_d, flt_l, 44, streak=False)
        L.paint(L.ellipse(hx + 9.2, head + 6.6, 2.1, 2.5), hexc(P["filter"]))
        L.shade(fm, L.gx(hx + 5, hx + 11, 1.2, 0.6))
        L.paint(L.ellipse(hx + 8.8, head + 5.2, 1.0, 0.6), hexc(flt_l), 0.5)
    else:
        L.paint(L.rect(hx - 1.0, head - 7, hx + 1.0, head + 6), hexc(P["hat_dk"]), 0.8)
        L.paint(L.rect(hx - 8, head + 2, hx + 8, head + 3.4, 1) * hood, hexc(P["hat_dk"]), 0.7)
        L.paint(L.ellipse(hx, head + 8.2, 2.6, 1.5), hexc(P["filter"]), 0.9)
    for sx in (-1, 1):
        if view != "E" or sx > 0:
            L.paint(L.rect(hx + sx * 8.6 - 1.2, head - 1, hx + sx * 8.6 + 1.2, head + 5, 1),
                    hexc(P["hat_dk"]), 0.85)
    L.snow_cap(hx - 6, hx + 6, head - 8.5, 3.2, 42, droop=0.1)
    return hx


def _osk_hoses(L, P, view, hx, head, sh, lean):
    """波纹呼吸软管：面颊 → 肩后 → 背气瓶。"""
    if view == "S":
        for sx in (-1, 1):
            _hose(L, [(hx + sx * 6.2, head + 5.5), (hx + sx * 10.5, head + 11),
                      (hx + sx * 12.2, sh + 1.5)], 2.6, P["hose"])
    elif view == "E":
        _hose(L, [(hx + 8.2, head + 6.5), (hx + 4, head + 12), (CX - 11 + lean, sh - 2)], 2.6, P["hose"])
    else:
        for sx in (-1, 1):
            _hose(L, [(hx + sx * 9.0, head + 6.5), (hx + sx * 11.5, sh - 2),
                      (hx + sx * 6.0, sh - 5)], 2.6, P["hose"])


def _osk_back(L, P, view, sh, hip, lean):
    """背负气瓶 + 调压阀：N 全貌，E 侧面露出。"""
    if view not in ("N", "E"):
        return
    if view == "N":
        m = L.rect(CX - 6, sh - 5, CX + 6, sh + 15, 4)
        _contact(L, m, 0.5, 2.2, 1.8, 0.5)
        _fill(L, m, P["tank"], P["tank_dk"], P["tank_lt"], 51)
        L.shade(m, L.gx(CX - 6, CX + 6, 1.22, 0.62))
        L.paint(L.rect(CX - 6, sh - 6.5, CX + 6, sh - 3.5, 1.6), hexc(P["tank_dk"]))
        vm = L.rect(CX + 1, sh - 10, CX + 7, sh - 5, 1.4)
        L.paint(vm, hexc(P["tank_dk"]))
        L.paint(L.rect(CX + 2, sh - 9, CX + 4, sh - 7.5, 0.6), hexc("#79847f"), 0.7)
        for sy in (sh + 2, sh + 8):
            L.paint(L.rect(CX - 7, sy, CX + 7, sy + 2.2), hexc(P["web"]), 0.95)
        L.rim(m, -1.3, 0, "#67737d", 0.5)
    else:
        m = L.rect(CX - 18 + lean * 0.5, sh - 4, CX - 11 + lean * 0.5, sh + 14, 3)
        _fill(L, m, P["tank"], P["tank_dk"], P["tank_lt"], 52)
        L.shade(m, L.gx(CX - 18, CX - 11, 1.2, 0.62))
        L.paint(L.rect(CX - 18 + lean * 0.5, sh - 5.5, CX - 11 + lean * 0.5, sh - 3, 1.2), hexc(P["tank_dk"]))
        L.paint(L.rect(CX - 18 + lean * 0.5, sh + 4, CX - 11 + lean * 0.5, sh + 6), hexc(P["web"]), 0.9)


def _osk_rifle(L, P, view, sh, hip, lean):
    """消音 AKM 斜挎（他右肩 → 他左髋），长圆柱消音器是剪影关键。"""
    gun, gun_l, wood = hexc(P["iron"]), hexc(P["iron_lt"]), hexc(P["rust"])
    dark = hexc("#0c0f13")

    def seg(x0, y0, x1, y1, w, col, rim_a=0.5):
        sm = L.line([(x0, y0), (x1, y1)], w)
        _contact(L, sm, 0.4, 1.6, 1.3, 0.5)
        L.paint(sm, col)
        L.rim(sm, -1, -0.5, gun_l, rim_a)

    if view == "S":
        a, b = (CX - 11, sh + 4), (CX + 7, hip + 3)
        seg(a[0], a[1], b[0], b[1], 3.6, gun)
        L.paint(L.line([(CX - 5, sh + 12), (CX + 1, sh + 18)], 4.6), wood)                    # 木护木
        L.rim(L.line([(CX - 5, sh + 12), (CX + 1, sh + 18)], 4.6), -1, -0.6, "#5c4830", 0.5)
        L.paint(L.line([(CX - 1, sh + 15), (CX - 3, sh + 23), (CX - 6, sh + 26)], 3.0, False), dark)
        L.paint(L.line([(CX - 1, sh + 15), (CX - 3, sh + 23), (CX - 6, sh + 26)], 2.2, False), gun)   # 弹匣
        L.paint(L.ellipse(CX - 11, sh + 4, 3.4, 3.4), hexc("#1b2026"))                          # 枪托底
        L.paint(L.ellipse(CX - 11, sh + 3, 3.0, 1.2), gun_l, 0.4)
        seg(b[0], b[1], CX + 14, hip + 11, 4.2, gun * 0.92, 0.55)                               # 消音器
        L.paint(L.ellipse(CX + 14, hip + 11, 2.1, 2.1), hexc("#080a0d"))
    elif view == "E":
        x0 = CX - 11 + lean
        L.paint(L.line([(x0, sh + 13), (x0 + 9, sh + 15)], 5.2), wood)
        L.rim(L.line([(x0, sh + 13), (x0 + 9, sh + 15)], 5.2), -1, -0.6, "#5c4830", 0.5)
        seg(x0 + 8, sh + 15, x0 + 22, sh + 18, 3.6, gun)
        L.paint(L.line([(x0 + 14, sh + 17), (x0 + 20, sh + 19)], 4.2), wood)
        L.paint(L.line([(x0 + 13, sh + 18), (x0 + 14, sh + 26), (x0 + 17, sh + 29)], 3.0, False), dark)
        L.paint(L.line([(x0 + 13, sh + 18), (x0 + 14, sh + 26), (x0 + 17, sh + 29)], 2.2, False), gun)
        seg(x0 + 21, sh + 18.2, x0 + 33, sh + 21.5, 4.4, gun * 0.92, 0.55)                     # 消音器
        L.paint(L.ellipse(x0 + 33, sh + 21.5, 2.2, 2.2), hexc("#080a0d"))
    else:
        # N：同一把枪（他右肩=观众右 → 他左髋=观众左）
        seg(CX + 11, sh + 2, CX - 7, hip + 1, 2.2, hexc("#1d2329"), 0.4)                        # 枪背带
        seg(CX + 8, sh + 6, CX - 4, hip - 1, 3.2, gun)
        L.paint(L.line([(CX + 9, sh + 5), (CX + 13, sh + 12)], 5.4), hexc("#1b2026"))          # 枪托
        seg(CX - 5, hip, CX - 11, hip + 7, 3.8, gun * 0.92, 0.55)                              # 消音器
        L.paint(L.ellipse(CX - 11, hip + 7, 2.0, 2.0), hexc("#080a0d"))


def _osk_arm(L, P, pts, dim=1.0):
    """橡胶袖 + 喇叭袖口厚手套。"""
    m = L.line(pts, 9.8)
    _fill(L, m, P["coat"], P["coat_dk"], P["coat_lt"], 61)
    L.shade(m, L.gx(min(p[0] for p in pts) - 6, max(p[0] for p in pts) + 6, 1.32, 0.68) * dim)
    hx, hy = pts[-1]
    L.paint(L.ellipse(hx, hy + 1.5, 4.8, 5.0), hexc(P["hand"]) * dim)   # 厚橡胶手套
    L.shade(L.ellipse(hx, hy + 1.5, 4.8, 5.0), L.gy(hy - 3, hy + 6, 1.25, 0.62) * dim)
    L.paint(L.ellipse(hx, hy - 0.6, 5.0, 2.0), hexc("#20262b") * dim)   # 喇叭袖口
    L.paint(L.ellipse(hx, hy + 0.6, 3.4, 1.4), hexc("#0e1114") * dim)
    return m


# ---------------------------------------------------------------------------
# 组帧
# ---------------------------------------------------------------------------
def frame(P, view, phase, crouch, walking):
    L = Layer(FW, FH, 4)
    s, c, hip, sh, head = _pose(view, phase, crouch, walking)
    osk = P["kind"] == "osk"
    sw = s * (2.4 if osk else 3.2)
    if osk:
        s = s * 0.8
    if view == "E":
        lean = 6.0 if (osk and crouch) else (7.0 if crouch else 0.0)
        hunch = 0.0 if osk else 2.2
        if osk:
            _osk_arm(L, P, [(CX - 4 + lean, sh + 5), (CX - 6 - s * 4 + lean * 0.5, sh + 16),
                            (CX - 5 - s * 7, sh + 27)], 0.8)
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
                _osk_lamp(L, CX + 5.5, sh + 11)
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
    img = L.finish(outline=None)                 # 写实：不用均匀黑描边
    # 确定性颗粒种子（hash() 对 str 加盐，不可复现，这里用稳定算术）
    vi = {"S": 0, "E": 1, "N": 2}[view]
    seed = (sum(ord(ch) for ch in P["kind"]) + vi * 131 + int(phase * 1000) * 7
            + int(crouch) * 37 + int(walking) * 53) % 9999
    return _grain(_outline_soft(img), 3.2, seed=seed)


def sheet(P) -> Image.Image:
    img = Image.new("RGBA", (FW * 8, FH * 3), (0, 0, 0, 0))
    for row, view in enumerate(("S", "E", "N")):
        cells = [(0.0, False, False)] + [(k / 4, False, True) for k in range(4)] + \
                [(0.0, True, False), (0.25, True, True), (0.75, True, True)]
        for col, (ph, cr, wk) in enumerate(cells):
            img.alpha_composite(frame(P, view, ph, cr, wk), (col * FW, row * FH))
    return img
