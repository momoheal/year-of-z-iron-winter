"""角色精灵表 — CHR_01 阿列克谢 / CHR_05 内务清杀兵 ОСК / CHR_04 回退半人（定妆图 v2）。

造型来源：用户 2026-10 新出的油画质感定妆图 + 三视图（正 / 侧 / 背）：
  阿列克谢：写实 ≈7 头身、消瘦微驼；炭黑偏蓝的双排扣长大衣（及小腿、满身霜粉）+ 灰褐羊羔毛大翻领
    + 灰色 ушанка（耳罩放下、系带垂着）+ 圆框眼镜（右镜片裂、胶布缠镜腿）+ 高过肩的橄榄褐帆布背包
    （翻盖 + 侧袋 + 扣带）+ 腰带挂钥匙串（左胯）与马灯（右胯）+ 右手握长撬棍（扁头朝外、J 形撬钩）
    + 冻伤发紫的手 + 灰色毡筒靴。
  ОСК：铅灰偏蓝的厚橡胶防护服（褶皱、油亮、老化裂纹、霜）+ 兜帽 + 双圆玻璃目镜防毒面具
    + 下颚橄榄色滤罐 + 波纹呼吸软管接背负气瓶（背面双瓶）+ 卡其帆布 X 束带 / 弹匣包 / 水壶
    + 胸前黄色矩形探照灯 + 消音 AKM 斜挎胸前（侧面低姿端枪）+ 厚手套 + 黑色胶靴。
  回退半人：褪色棉袄、还有瞳孔（白眼黑瞳，区别于狂暴者的黑眼窝）、高烧潮红、右颊灰鳞，双臂抱身。

引擎硬规格（保持不变，否则场景要重排）：
  每帧 72×112、pivot 脚底中心 (36,108)、行序 S/E/N；W = E 水平翻转（引擎 flip_h）。
  CHR_01/05 列序 0 待机 · 1-4 行走 · 5 蹲待机 · 6-7 蹲走；
  CHR_04 列序 0 抱臂待机 · 1-4 蹒跚 · 5 蜷坐 · 6 倒地 · 7 护头。
_limb / _legs / _pose 是旧版共享底层，gen_rabid（CHR_03）仍在用，语义保持不变。
"""
from __future__ import annotations

import math
import numpy as np
from PIL import Image

from artlib import Layer, hexc, smooth

FW, FH = 72, 112
GY_ = 108
CX = 36

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


def _knee(hip, foot, l1, l2, fwd):
    """两段骨 IK：已知胯与脚，求膝；fwd=+1 膝盖朝 +x（面朝东），0 = 正/背面（膝在两点连线上）。"""
    dx, dy = foot[0] - hip[0], foot[1] - hip[1]
    d = max(1e-3, math.hypot(dx, dy))
    if fwd == 0:
        return (hip[0] + dx * l1 / (l1 + l2), hip[1] + dy * l1 / (l1 + l2))
    d2 = min(d, l1 + l2 - 0.05)
    a = (l1 * l1 - l2 * l2 + d2 * d2) / (2 * d2)
    h = math.sqrt(max(0.0, l1 * l1 - a * a))
    ux, uy = dx / d, dy / d
    return (hip[0] + ux * a + uy * fwd * h, hip[1] + uy * a - ux * fwd * h)


def _step(s, c, side):
    """单腿步态：side=+1 与相位同步，-1 反相。返回 (前后位移 -1..1, 抬脚 0..1)。
    摆动期（脚向前）抬脚、支撑期贴地后移 —— 不会出现「倒着走」。"""
    return s * side, max(0.0, c * side)


def _legs(L, P, view, s, c, hip, crouch):
    # 腿/靴几何：默认值与旧版逐像素一致（CHR_03 依赖此行为）；OSK 用 P 里的 leg_w/boot_w 加重。
    lw = P.get("leg_w", 10.5)
    shaft = P.get("boot_shaft_w", 5.0)
    bw = P.get("boot_w", 6.5 if view == "E" else 5.5)
    snow_w = P.get("boot_snow_w", 4.0)
    legs = []
    if view in ("S", "N"):
        for side in (-1, 1):
            f, up = _step(s, c, side)
            lift = up * 4.0
            hx = CX + side * 6
            if crouch:
                knee = (CX + side * 12, hip + 9 - lift * 0.4)
                foot = (CX + side * 8, GY_ - 2 - lift * 0.5)
            else:
                foot = (hx, GY_ - 3.5 - lift + f * 1.4 * (1 if view == "S" else -1))
                knee = (hx + side * 1.0, (hip + foot[1]) / 2 - lift * 0.5)
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
                f, up = _step(s, c, sg)
                foot = (hx + f * 11, GY_ - 3 - up * 4)
                seg = (GY_ - 7 - hip) / 2 * 1.06
                knee = _knee((hx, hip), (foot[0], foot[1] - 4), seg, seg, 1)
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



# ===========================================================================
# 定妆图 v2：写实比例（≈7 头身）、油画霜粉质感、软描边
# 光从左上来；所有布料 = 细纹理 × 大块明暗 × 竖向渐暗 + 霜粉颗粒（上表面多）
# ===========================================================================
FROST = "#d5dee7"


def _cloth(L, col, seed, fine=0.07, broad=0.12):
    c = L.tex(col, fine, 1.6, seed)
    n = L.noise(7.0, seed + 1)
    return c * (1.0 + (n - 0.5) * 2.0 * broad)[..., None]


def _form(L, m, x0, x1, y0, y1, hx=(1.2, 0.68), vy=(1.06, 0.8)):
    L.shade(m, L.gx(x0, x1, *hx))
    L.shade(m, L.gy(y0, y1, *vy))


def _frost(L, m, amt=0.55, seed=0, y0=None, y1=None):
    """霜粉：细颗粒 + 少量盐霜斑；y0→y1 由多到少（上表面积雪多）。"""
    k = smooth(0.7, 0.86, L.noise(1.1, seed, octaves=2))
    k2 = smooth(0.52, 0.74, L.noise(2.6, seed + 9)) * smooth(0.45, 0.7, L.noise(6.0, seed + 13))
    lit = L.gx(CX - 16, CX + 16, 1.0, 0.55)
    if y0 is not None:
        g = L.gy(y0, y1, 1.0, 0.25)
        k, k2 = k * g, k2 * g
    L.paint(m * k * lit, hexc(FROST), amt * 0.55)
    L.paint(m * k2 * lit, hexc(FROST), amt * 0.42)


def _stroke(L, m, pts, w, col, a=0.6):
    L.paint(L.line(pts, w) * m, hexc(col), a)


def _sleeve(L, P, pts, w, seed, dim=1.0, frost=0.45):
    m = L.line(pts, w)
    L.paint(m, _cloth(L, P["coat"], seed))
    xs = [p[0] for p in pts]
    _form(L, m, min(xs) - w, max(xs) + w, pts[0][1], pts[-1][1], (1.22, 0.7), (1.08, 0.86))
    # 肘部褶
    ex, ey = pts[1]
    _stroke(L, m, [(ex - w * 0.4, ey - 1.0), (ex + w * 0.3, ey + 0.6)], 0.7, P["coat_dk"], 0.7)
    _frost(L, m, frost, seed + 3, pts[0][1], pts[-1][1])
    L.shade(m, dim)
    return m


def _hose(L, pts, w, col, lt, step=1.25):
    """波纹软管：粗线 + 交替亮环。"""
    m = L.line(pts, w)
    L.paint(m, hexc(col))
    acc = 0.0
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        seg = math.hypot(x1 - x0, y1 - y0)
        n = max(1, int(seg / step))
        nx, ny = -(y1 - y0) / max(seg, 1e-6), (x1 - x0) / max(seg, 1e-6)
        for i in range(n):
            t = i / n
            cx_, cy_ = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            if int(acc / step) % 2 == 0:
                L.paint(L.line([(cx_ - nx * w * 0.42, cy_ - ny * w * 0.42),
                                (cx_ + nx * w * 0.42, cy_ + ny * w * 0.42)], 0.55, False), hexc(lt), 0.8)
            acc += seg / n
    L.rim(m, -0.8, -0.8, "#6b7580", 0.35)
    return m


def _hero_pose(phase, crouch, walking, base):
    s = math.sin(phase * math.tau) if walking else 0.0
    c = math.cos(phase * math.tau) if walking else 0.0
    bob = -1.3 * abs(s) if walking else 0.0
    hip, sh, head = base["crouch"] if crouch else base["stand"]
    if crouch:
        bob *= 0.5
    return s, c, hip + bob, sh + bob, head + bob


def _hero_legs(L, P, view, s, c, hip, crouch, seed=40):
    """长腿 + 筒靴。S/N：左右交替抬脚；E：前后跨步（远腿先画、压暗）。"""
    tw, bw, bh, hs = P["thigh_w"], P["boot_w"], P["boot_h"], P["hip_sep"]
    legs = []
    if view in ("S", "N"):
        for side in (-1, 1):
            f, up = _step(s, c, side)
            lift = up * 3.4
            hx = CX + side * hs
            if crouch:
                knee = (CX + side * (hs + 5.5), hip + 7 - lift * 0.3)
                foot = (CX + side * (hs + 2.5), GY_ - lift * 0.4)
            else:
                # 正面：迈出的脚朝镜头（屏幕下移）；背面相反
                foot = (hx + side * 0.6, GY_ - lift + f * 1.5 * (1 if view == "S" else -1))
                knee = (hx + side * 0.9, (hip + foot[1]) / 2 - lift * 0.6)
            legs.append((1.0, (hx, hip), knee, foot, 0.0))
    else:
        for k, sg in enumerate((-1, 1)):          # k=0 远腿（左） k=1 近腿（右）
            dim = 0.72 if k == 0 else 1.0
            if crouch:
                if k == 1:
                    knee, foot = (CX + 10 + s * 2, hip + 2), (CX + 6 + s * 3, GY_)
                else:
                    knee, foot = (CX + 1 - s * 2, hip + 12), (CX - 8 - s * 3, GY_)
                hx = CX - 2
            else:
                hx = CX - 1
                f, up = _step(s, c, sg)
                foot = (hx + f * 10, GY_ - up * 3.6)
                seg = (GY_ - 3 - hip) / 2 * 1.05
                knee = _knee((hx, hip), (foot[0] + 0.5, foot[1] - 3), seg, seg, 1)   # 膝盖永远朝前
            legs.append((dim, (hx, hip), knee, foot, 3.0))
    for dim, hp, knee, foot, toe in legs:
        kf = max(1e-3, math.hypot(foot[0] - knee[0], foot[1] - knee[1]))
        t = min(1.0, bh / kf)
        ank = (foot[0] + (knee[0] - foot[0]) * t, foot[1] + (knee[1] - foot[1]) * t)
        m = L.line([hp, knee, ank], tw)
        L.paint(m, _cloth(L, P["trousers"], seed))
        _form(L, m, min(hp[0], foot[0]) - tw, max(hp[0], foot[0]) + tw, hip, GY_, (1.15, 0.75), (1.0, 0.85))
        L.shade(m, dim)
        # 筒靴：靴筒 + 靴头
        shaft = L.line([ank, (foot[0] + toe * 0.3, foot[1] - 3.5)], bw)
        toe_m = L.ellipse(foot[0] + toe, foot[1] - 2.2, bw * 0.55 + toe * 0.55, 2.6)
        bm = np.clip(shaft + toe_m, 0, 1)
        L.paint(bm, _cloth(L, P["boots"], seed + 5, 0.09, 0.14))
        _form(L, bm, foot[0] - bw, foot[0] + bw + toe, ank[1], foot[1], (1.25, 0.66), (1.12, 0.78))
        L.paint(L.rect(ank[0] - bw / 2 - 1, ank[1] - 1, ank[0] + bw / 2 + 1, ank[1] + 1.4, 0.7) * bm,
                hexc(P["boots_lt"]), 0.55)                                  # 靴口翻边
        _frost(L, bm, 0.75, seed + 7, ank[1], foot[1])
        L.paint(L.ellipse(foot[0] + toe, foot[1] - 0.6, bw * 0.55 + toe * 0.5, 1.2) * bm, hexc(FROST), 0.5)
        L.shade(bm, dim)


# ---------------------------------------------------------------------------
# 阿列克谢
# ---------------------------------------------------------------------------
def _al_crowbar(L, P, hx, hy, ang, back=15.0, fwd=10.0, dim=1.0, hook=1):
    """长撬棍：握在中段；back 段指向 ang（扁头），fwd 段反向、末端 J 形撬钩。"""
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    p0 = (hx + ux * back, hy + uy * back)
    p1 = (hx - ux * fwd, hy - uy * fwd)
    # 撬钩：从 p1 继续前伸后向下 / 回弯
    k1 = (p1[0] - ux * 2.6 + 0.6 * hook, p1[1] - uy * 2.6 + 1.6)
    k2 = (k1[0] - ux * 0.6 + 0.8 * hook, k1[1] + 2.6)
    k3 = (k2[0] + ux * 1.8, k2[1] + 1.0)
    tip = (p0[0] + ux * 2.2 - uy * 0.9, p0[1] + uy * 2.2 + ux * 0.9)        # 扁头微弯
    m = L.line([tip, p0, p1, k1, k2, k3], 2.1)
    L.paint(m, hexc(P["iron"]) * dim)
    L.paint(L.line([p0, p1], 0.7, False), hexc(P["iron_lt"]) * dim, 0.75)
    L.paint(L.line([tip, p0], 1.0, False) * m, hexc("#6a4a30"), 0.4)        # 扁头锈
    _frost(L, m, 0.35, 77)


def _al_hand(L, P, x, y, dim=1.0):
    m = L.ellipse(x, y, 2.6, 3.2)
    L.paint(m, hexc(P["hand"]) * dim)
    L.shade(m, L.gx(x - 3, x + 3, 1.15, 0.8))
    L.paint(L.ellipse(x + 0.4, y + 1.0, 2.0, 1.4) * m, hexc(P["bite"]), 0.55)     # 冻伤发紫的指节
    L.paint(L.ellipse(x - 0.8, y - 1.2, 0.9, 0.7) * m, hexc("#e7c9bf"), 0.4)


def _al_head(L, P, view, hx, head):
    hat, hat_lt = _cloth(L, P["hat"], 31, 0.14, 0.1), _cloth(L, P["hat_lt"], 32, 0.16, 0.08)
    skin = hexc(P["skin"])
    if view == "S":
        for sx in (-1, 1):                                     # 耳罩（放下，盖住耳朵到下颌）
            m = L.poly([(hx + sx * 4.2, head - 4.0), (hx + sx * 8.4, head - 4.0), (hx + sx * 8.9, head + 6.0),
                        (hx + sx * 6.6, head + 7.4), (hx + sx * 4.4, head + 6.2)])
            L.paint(m, hat)
            L.shade(m, 0.82 if sx > 0 else 1.0)
        L.paint(L.line([(hx + 6.1, head + 6.0), (hx + 6.6, head + 9.5), (hx + 6.1, head + 12.0)], 0.6),
                hexc(P["hat_dk"]))                             # 垂下的系带
        face = np.clip(L.ellipse(hx, head + 0.4, 4.6, 5.9) + L.poly(
            [(hx - 3.6, head + 3.0), (hx + 3.6, head + 3.0), (hx + 1.6, head + 6.8), (hx - 1.6, head + 6.8)]), 0, 1)
        L.paint(face, skin)
        L.shade(face, L.gx(hx - 5, hx + 5, 1.16, 0.72))
        L.paint(L.ellipse(hx - 2.6, head + 2.6, 1.6, 1.3) * face, hexc(P["skin_dk"]), 0.45)   # 颧骨下凹
        L.paint(L.ellipse(hx + 2.6, head + 2.6, 1.6, 1.3) * face, hexc(P["skin_dk"]), 0.5)
        L.paint(L.ellipse(hx, head + 1.4, 1.1, 1.6) * face, hexc(P["cheek"]), 0.45)          # 冻红的鼻头
        L.paint(L.rect(hx - 1.6, head + 4.4, hx + 1.6, head + 5.0, 0.3), hexc("#5e3f36"), 0.85)
        L.paint(face * smooth(0.55, 0.8, L.noise(1.0, 25)) * L.gy(head + 2, head + 7, 0.2, 1.0),
                hexc("#665247"), 0.35)                         # 胡茬
        for ex in (-2.3, 2.3):
            L.paint(L.ellipse(hx + ex, head - 0.5, 1.0, 0.7), hexc("#1d1716"))
            L.paint(L.rect(hx + ex - 1.5, head - 2.4, hx + ex + 1.5, head - 1.8, 0.3), hexc("#3a2c26"), 0.7)
        gl = hexc("#3b4048")
        for ex in (-2.3, 2.3):                                 # 圆框眼镜
            L.paint(L.ellipse(hx + ex, head - 0.4, 2.1, 2.0), hexc("#c7d3dc"), 0.22)
            L.paint(L.arc(hx + ex, head - 0.4, 2.15, 2.05, 0, 360, 0.75), gl)
            L.paint(L.ellipse(hx + ex - 0.8, head - 1.2, 0.55, 0.4), hexc("#eef4f8"), 0.8)
        L.paint(L.line([(hx - 0.25, head - 0.6), (hx + 0.25, head - 0.6)], 0.6, False), gl)
        cx_, cy_ = hx - 2.3, head - 0.4                        # 右镜片（观众左）蛛网裂
        for ang in (25, 140, 230, 310):
            a = math.radians(ang)
            L.paint(L.line([(cx_, cy_), (cx_ + 1.9 * math.cos(a), cy_ + 1.8 * math.sin(a))], 0.4, False),
                    hexc("#f2f7fa"), 0.85)
        L.paint(L.rect(hx - 5.2, head - 1.3, hx - 3.9, head + 0.3, 0.4), hexc("#101317"))   # 黑胶布镜腿
        crown = np.clip(L.ellipse(hx, head - 6.4, 7.6, 4.8) + L.rect(hx - 7.6, head - 6.4, hx + 7.6, head - 3.0, 1.5), 0, 1)
        L.paint(crown, hat)
        _form(L, crown, hx - 8, hx + 8, head - 11, head - 3, (1.18, 0.7), (1.1, 0.88))
        band = L.rect(hx - 8.6, head - 6.6, hx + 8.6, head - 2.4, 2.0)        # 翻起的前檐
        L.paint(band, hat_lt)
        L.shade(band, L.gx(hx - 7, hx + 7, 1.14, 0.74))
        L.paint(L.rect(hx - 7.2, head - 3.2, hx + 7.2, head - 2.4, 0.4) * band, hexc(P["hat_dk"]), 0.6)
        hm = np.clip(crown + band, 0, 1)
    elif view == "E":
        m = L.rect(hx - 4.6, head - 4.5, hx + 0.4, head + 7.0, 1.8)          # 后侧耳罩
        L.paint(m, hat * 0.8)
        face = np.clip(L.ellipse(hx + 1.2, head + 0.4, 4.2, 5.8) + L.poly(
            [(hx + 0.5, head + 3.0), (hx + 5.0, head + 3.2), (hx + 3.6, head + 6.8), (hx + 0.5, head + 6.6)]), 0, 1)
        L.paint(face, skin)
        L.shade(face, L.gx(hx - 3, hx + 6, 0.8, 1.08))
        L.paint(L.ellipse(hx + 5.3, head + 1.3, 1.1, 1.5), skin * 0.95)                       # 鼻
        L.paint(L.ellipse(hx + 5.0, head + 1.4, 0.9, 1.0), hexc(P["cheek"]), 0.5)
        L.paint(L.ellipse(hx + 3.2, head - 0.5, 0.8, 0.7), hexc("#1d1716"))
        L.paint(L.rect(hx + 3.4, head + 4.5, hx + 5.0, head + 5.0, 0.3), hexc("#5e3f36"), 0.85)
        L.paint(face * smooth(0.55, 0.8, L.noise(1.0, 26)) * L.gy(head + 2, head + 7, 0.2, 1.0),
                hexc("#665247"), 0.35)
        L.paint(L.ellipse(hx + 3.4, head - 0.4, 1.4, 2.0), hexc("#c7d3dc"), 0.25)
        L.paint(L.arc(hx + 3.4, head - 0.4, 1.45, 2.05, 0, 360, 0.75), hexc("#3b4048"))
        L.paint(L.line([(hx + 2.0, head - 0.6), (hx - 2.2, head - 0.2)], 0.6, False), hexc("#3b4048"))
        L.paint(L.line([(hx - 0.2, head + 6.2), (hx - 0.6, head + 10.5)], 0.6), hexc(P["hat_dk"]))
        crown = np.clip(L.ellipse(hx - 0.5, head - 6.4, 7.4, 4.8) + L.rect(hx - 7.9, head - 6.4, hx + 6.9, head - 3.0, 1.5), 0, 1)
        L.paint(crown, hat)
        _form(L, crown, hx - 7, hx + 6, head - 12, head - 3, (1.15, 0.75), (1.1, 0.88))
        band = L.rect(hx - 1.0, head - 6.6, hx + 7.6, head - 2.4, 2.0)
        L.paint(band, hat_lt)
        flap = L.rect(hx - 5.6, head - 4.0, hx - 0.6, head + 6.8, 1.8)       # 近侧耳罩
        L.paint(flap, hat)
        L.shade(flap, L.gy(head - 4, head + 7, 1.05, 0.8))
        hm = np.clip(crown + band + flap, 0, 1)
    else:
        back = np.clip(L.ellipse(hx, head - 5.0, 8.4, 5.6) + L.rect(hx - 8.4, head - 5.0, hx + 8.4, head + 5.0, 2.4)
                       + L.poly([(hx - 8.4, head - 2), (hx - 9.2, head + 7), (hx - 5.5, head + 7.5), (hx - 5, head)])
                       + L.poly([(hx + 8.4, head - 2), (hx + 9.2, head + 7), (hx + 5.5, head + 7.5), (hx + 5, head)]), 0, 1)
        L.paint(back, hat)
        _form(L, back, hx - 7, hx + 7, head - 12, head + 7, (1.15, 0.72), (1.08, 0.82))
        L.paint(L.rect(hx - 0.4, head - 11, hx + 0.4, head + 6, 0.3) * back, hexc(P["hat_dk"]), 0.5)
        L.paint(L.rect(hx - 7.0, head + 4.6, hx + 7.0, head + 6.5, 1.0) * back, hexc(P["hat_dk"]), 0.45)
        hm = back
    L.paint(hm * smooth(0.48, 0.7, L.noise(0.7, 33)), hexc(P["hat_lt"]), 0.35)      # 毛尖
    _frost(L, hm, 0.75, 35, head - 12, head - 2)


def _al_collar(L, P, view, hx, sh):
    fur = _cloth(L, P["fur"], 21, 0.18, 0.08)
    if view == "S":
        m = np.clip(L.ellipse(hx - 6.6, sh - 0.2, 6.8, 4.2) + L.ellipse(hx + 6.6, sh - 0.2, 6.8, 4.2), 0, 1)
        m = m * (1 - L.poly([(hx - 2.6, sh - 4.5), (hx + 2.6, sh - 4.5), (hx, sh + 4.2)]))
    elif view == "E":
        m = L.ellipse(hx - 0.8, sh - 0.5, 7.2, 4.0)
    else:
        m = L.rect(hx - 11.5, sh - 3.6, hx + 11.5, sh + 3.2, 3.0)
    L.paint(m, fur)
    _form(L, m, hx - 11, hx + 11, sh - 4, sh + 4, (1.18, 0.75), (1.12, 0.78))
    L.paint(m * smooth(0.46, 0.66, L.noise(0.6, 22)), hexc(P["fur_lt"]), 0.55)       # 羊羔毛卷
    L.paint(m * smooth(0.5, 0.7, L.noise(0.8, 23)), hexc(P["fur_dk"]), 0.4)
    _frost(L, m, 0.5, 24, sh - 4, sh + 4)
    if view == "S":
        L.paint(L.poly([(hx - 2.0, sh - 3.8), (hx + 2.0, sh - 3.8), (hx, sh + 2.8)]), hexc("#1c2028"))   # 领口里的旧毛衣


def _al_pack(L, P, view, sh, lean):
    can = _cloth(L, P["pack"], 51, 0.1, 0.12)
    if view == "S":                                            # 只露出肩后的包顶
        m = L.poly([(CX - 13.5, sh - 1), (CX - 12.5, sh - 7.5), (CX - 6, sh - 8.6), (CX - 2, sh - 5),
                    (CX + 2, sh - 5), (CX + 7, sh - 7.2), (CX + 12.5, sh - 5.8), (CX + 13.5, sh - 1),
                    (CX + 14, sh + 14), (CX - 14, sh + 14)])
        L.paint(m, can)
        _form(L, m, CX - 14, CX + 14, sh - 9, sh + 12, (1.1, 0.7), (1.12, 0.7))
        _frost(L, m, 0.5, 52, sh - 9, sh)
        return
    if view == "E":
        x0, x1 = CX - 18.5 + lean, CX - 4.5 + lean
        body = L.rect(x0, sh - 8.5, x1, sh + 24, 4.0)
        L.paint(body, can)
        _form(L, body, x0, x1, sh - 9, sh + 24, (0.95, 1.12), (1.1, 0.72))
        flap = L.rect(x0 + 0.5, sh - 9.0, x1 + 0.5, sh + 4.5, 3.6)
        L.paint(flap, _cloth(L, P["pack_lt"], 53, 0.1, 0.1))
        L.shade(flap, L.gy(sh - 9, sh + 5, 1.08, 0.86))
        L.paint(L.rect(x0 + 0.5, sh + 3.4, x1 + 0.5, sh + 4.6, 0.5) * flap, hexc(P["pack_dk"]), 0.75)
        pk = L.rect(x0 - 1.6, sh + 9, x0 + 6.5, sh + 22, 2.4)                   # 侧袋
        L.paint(pk, _cloth(L, P["pack"], 54, 0.1, 0.1) * 0.9)
        L.paint(L.rect(x0 - 1.6, sh + 9, x0 + 6.5, sh + 12.6, 1.6), hexc(P["pack_lt"]) * 0.92)
        L.paint(L.rect(x0 + 1.6, sh + 11.5, x0 + 3.4, sh + 15.5, 0.4), hexc(P["strap"]))
        L.paint(L.rect(x0 + 1.9, sh + 13.0, x0 + 3.1, sh + 14.0, 0.2), hexc(P["buckle"]))
        for bx in (x0 + 4.0, x1 - 4.0):                                        # 扣带
            L.paint(L.rect(bx - 0.9, sh - 0.5, bx + 0.9, sh + 9, 0.4), hexc(P["strap"]))
            L.paint(L.rect(bx - 1.2, sh + 6.5, bx + 1.2, sh + 7.8, 0.2), hexc(P["buckle"]))
        L.paint(L.line([(x0 + 3, sh + 1), (x0 + 5, sh + 3.2), (x0 + 3.5, sh + 5)], 0.5, False),
                hexc(P["pack_dk"]), 0.8)                                       # 缝补
        m = np.clip(body + flap + pk, 0, 1)
        _frost(L, m, 0.6, 55, sh - 9, sh + 20)
        return
    # N：背包占满后背
    body = L.rect(CX - 12, sh - 7.5, CX + 12, sh + 25, 4.0)
    L.paint(body, can)
    _form(L, body, CX - 12, CX + 12, sh - 8, sh + 25, (1.12, 0.74), (1.1, 0.74))
    flap = L.rect(CX - 11.5, sh - 8, CX + 11.5, sh + 7, 3.6)
    L.paint(flap, _cloth(L, P["pack_lt"], 56, 0.1, 0.1))
    L.shade(flap, L.gy(sh - 8, sh + 7, 1.1, 0.84))
    L.paint(L.rect(CX - 11.5, sh + 5.8, CX + 11.5, sh + 7.0, 0.5) * flap, hexc(P["pack_dk"]), 0.75)
    for bx in (-5.0, 5.0):
        L.paint(L.rect(CX + bx - 1.0, sh - 1, CX + bx + 1.0, sh + 12, 0.4), hexc(P["strap"]))
        L.paint(L.rect(CX + bx - 1.4, sh + 9.5, CX + bx + 1.4, sh + 11, 0.2), hexc(P["buckle"]))
    for sx in (-1, 1):
        pk = L.rect(CX + sx * 7.5 - 4.5, sh + 12.5, CX + sx * 7.5 + 4.5, sh + 23.5, 2.0)
        L.paint(pk, _cloth(L, P["pack"], 57 + sx, 0.1, 0.1) * 0.92)
        L.paint(L.rect(CX + sx * 7.5 - 4.5, sh + 12.5, CX + sx * 7.5 + 4.5, sh + 15.8, 1.4),
                hexc(P["pack_lt"]) * 0.9)
        L.paint(L.rect(CX + sx * 7.5 - 0.7, sh + 14.5, CX + sx * 7.5 + 0.7, sh + 17.5, 0.2), hexc(P["buckle"]))
    _frost(L, body, 0.6, 58, sh - 8, sh + 24)


def _al_coat(L, P, view, hip, sh, hem, s, lean):
    if view == "E":
        fx = max(0.0, s) * 2.5
        bx = max(0.0, -s) * 2.5
        pts = [(CX - 6.5 + lean, sh - 1.5), (CX + 5.5 + lean, sh - 0.5), (CX + 8 + lean * 0.8, sh + 9),
               (CX + 7 + lean * 0.5, hip), (CX + 10.5 + fx, hem), (CX - 10.5 - bx, hem + 0.5),
               (CX - 7.5, hip), (CX - 8.5 + lean * 0.7, sh + 9)]
    else:
        sw = s * 1.2
        pts = [(CX - 12, sh + 1), (CX - 6, sh - 2.5), (CX + 6, sh - 2.5), (CX + 12, sh + 1),
               (CX + 12.6, sh + 10), (CX + 10.6, hip), (CX + 13.6 + sw, hem - 1), (CX + 12 + sw, hem + 0.6),
               (CX - 12 + sw, hem + 0.6), (CX - 13.6 + sw, hem - 1), (CX - 10.6, hip), (CX - 12.6, sh + 10)]
    m = L.poly(pts)
    L.paint(m, _cloth(L, P["coat"], 61, 0.07, 0.14))
    _form(L, m, CX - 13, CX + 13, sh, hem, (1.28, 0.66), (1.08, 0.78))
    # 长褶：一条暗 + 一条亮
    folds = (-7.5, -1.5, 6.0) if view != "E" else (-4.0, 3.5)
    for i, fx_ in enumerate(folds):
        x = CX + fx_ + (lean * 0.5 if view == "E" else 0)
        _stroke(L, m, [(x, hip + 3), (x - 0.8 + s * 0.8, (hip + hem) / 2), (x - 1.6 + s * 1.5, hem)], 1.1,
                P["coat_dk"], 0.75)
        _stroke(L, m, [(x + 1.3, hip + 5), (x + 0.6 + s * 0.8, (hip + hem) / 2 + 2), (x - 0.2 + s * 1.5, hem - 1)],
                0.7, P["coat_lt"], 0.45)
    if view == "S":
        # 双排扣：门襟斜线 + 两列铜扣（冻得发黑）+ 驳领
        L.paint(L.line([(CX - 1, sh + 2), (CX + 3.2, sh + 11), (CX + 3.2, hem)], 0.8, False) * m,
                hexc(P["coat_dk"]), 0.95)
        for lx, sg in ((CX - 3.5, -1), (CX + 3.5, 1)):
            lap = L.poly([(lx - sg * 2.5, sh - 1.5), (lx + sg * 2.8, sh + 1.5), (lx + sg * 1.0, sh + 11),
                          (lx - sg * 0.6, sh + 6)])
            L.paint(lap * m, hexc(P["coat_lt"]), 0.35)
            L.rim(lap * m, sg * 0.8, 0, P["coat_dk"], 0.6)
        for by in (sh + 13, sh + 20, hip + 6, hip + 13):
            for bx in (CX - 2.8, CX + 6.0):
                L.paint(L.ellipse(bx, by, 0.95, 0.95) * m, hexc("#0e1015"))
                L.paint(L.ellipse(bx - 0.3, by - 0.3, 0.4, 0.4) * m, hexc("#7a7f88"), 0.6)
    elif view == "N":
        L.paint(L.line([(CX, hip + 2), (CX, hem)], 0.8, False) * m, hexc(P["coat_dk"]), 0.9)   # 后开衩
        L.paint(L.rect(CX - 7, hip - 2.0, CX + 7, hip + 1.2, 0.6) * m, _cloth(L, P["coat_lt"], 62) * 0.8)  # 后腰襻
    # 腰带
    belt = L.rect(CX - 14, hip - 2.0, CX + 14, hip + 1.6, 0.6) * m
    L.paint(belt, hexc(P["belt"]))
    L.paint(L.rect(CX - 14, hip - 2.0, CX + 14, hip - 1.3) * belt, hexc("#6f6852"), 0.5)
    if view == "S":
        L.paint(L.rect(CX - 2.4, hip - 2.6, CX + 2.4, hip + 2.2, 0.5), hexc(P["buckle"]))
        L.paint(L.rect(CX - 1.3, hip - 1.4, CX + 1.3, hip + 1.0, 0.3), hexc(P["belt"]))
    _frost(L, m, 0.6, 63, sh - 2, hem)
    L.paint(L.rect(CX - 16, hem - 2.5, CX + 16, hem + 1) * m, hexc(FROST), 0.22)                     # 下摆沾雪
    L.rim(m, -1.0, 0, "#4c5466", 0.45)
    L.rim(m, 0, 1.0, "#0a0c10", 0.4)
    return m


def _al_straps(L, P, view, sh, lean):
    if view == "S":
        for sx in (-1, 1):
            m = L.line([(CX + sx * 7.6, sh - 2.5), (CX + sx * 8.2, sh + 7), (CX + sx * 7.4, sh + 17)], 2.4)
            L.paint(m, hexc(P["strap"]))
            L.shade(m, L.gx(CX - 10, CX + 10, 1.1, 0.8))
            L.paint(L.rect(CX + sx * 8.2 - 1.5, sh + 8.0, CX + sx * 8.2 + 1.5, sh + 9.6, 0.3), hexc(P["buckle"]))
    elif view == "E":
        m = L.line([(CX - 4 + lean, sh - 2), (CX + 2.5 + lean, sh + 0.5), (CX + 4.5 + lean * 0.8, sh + 13)], 2.3)
        L.paint(m, hexc(P["strap"]))
        L.paint(L.rect(CX + 2.6 + lean, sh + 6, CX + 5.6 + lean, sh + 7.4, 0.3), hexc(P["buckle"]))


def _al_gear(L, P, view, hip, lean):
    """腰带上的钥匙串与马灯（参考图：钥匙在左胯、马灯挂右胯）。"""
    if view == "N":
        return
    if view == "S":
        kx, lx = CX - 6.5, CX + 9.0
    else:
        kx, lx = CX + 2.0 + lean * 0.4, CX + 6.5 + lean * 0.4
    L.paint(L.arc(kx, hip + 2.6, 1.3, 1.3, 0, 360, 0.6), hexc(P["key"]))                    # 钥匙圈
    L.paint(L.line([(kx, hip + 3.8), (kx + 0.3, hip + 8.0)], 0.9), hexc(P["key"]))
    L.paint(L.rect(kx - 0.3, hip + 6.2, kx + 1.6, hip + 6.9, 0.2), hexc(P["key"]))
    L.paint(L.line([(lx, hip + 1), (lx, hip + 3)], 0.6, False), hexc("#2a2c30"))           # 马灯
    body = L.rect(lx - 2.3, hip + 3, lx + 2.3, hip + 10.5, 0.9)
    L.paint(body, hexc(P["brass"]))
    glass = L.rect(lx - 1.6, hip + 4.6, lx + 1.6, hip + 9.0, 0.6)
    L.paint(glass, hexc(P["glass"]))
    L.shade(glass, L.gx(lx - 2, lx + 2, 1.15, 0.7))
    for gx_ in (lx - 0.7, lx + 0.7):
        L.paint(L.line([(gx_, hip + 4.4), (gx_, hip + 9.2)], 0.4, False), hexc("#2a2c30"), 0.8)
    L.paint(L.rect(lx - 2.6, hip + 2.5, lx + 2.6, hip + 3.6, 0.4), hexc("#2a2c30"))
    L.paint(L.rect(lx - 2.6, hip + 9.6, lx + 2.6, hip + 10.9, 0.4), hexc("#2a2c30"))
    _frost(L, body, 0.35, 66)


def _draw_aleksei(L, P, view, phase, crouch, walking):
    s, c, hip, sh, head = _hero_pose(phase, crouch, walking, P)
    hem = min(hip + (19 if crouch else 25), GY_ - 7)
    sw = s * 2.6
    if view == "E":
        lean = 5.0 if crouch else 1.2           # 微驼：上身前探
        hx = CX + 2.4 + lean * 1.2
        # 远臂（左臂，在身后）
        _sleeve(L, P, [(CX - 1 + lean, sh + 3), (CX - 2 + s * 4 + lean * 0.5, sh + 14),
                       (CX - 2.5 + s * 6, sh + 24)], 5.8, 71, 0.68)
        _al_hand(L, P, CX - 2.5 + s * 6, sh + 27, 0.68)
        _hero_legs(L, P, view, s, c, hip, crouch)
        _al_coat(L, P, view, hip, sh, hem, s, lean)
        _al_gear(L, P, view, hip, lean)
        _al_pack(L, P, view, sh, lean)
        _al_straps(L, P, view, sh, lean)
        _al_collar(L, P, view, hx - 1.5, sh)
        _al_head(L, P, view, hx, head + 1.2)
        # 近臂（右臂）低垂握撬棍：扁头朝后上，撬钩朝前下
        wx, wy = CX + 2.5 - s * 6 + lean * 0.6, sh + 25      # 近臂与近腿反相
        _sleeve(L, P, [(CX + 1 + lean, sh + 3), (CX + 2 - s * 4 + lean * 0.8, sh + 14), (wx, wy)], 6.0, 72)
        _al_crowbar(L, P, wx + 0.3, wy + 3.0, 196 - s * 8, 14, 10)
        _al_hand(L, P, wx + 0.3, wy + 3.0)
        return
    _hero_legs(L, P, view, s, c, hip, crouch)
    if view == "S":
        _al_pack(L, P, view, sh, 0)
    _al_coat(L, P, view, hip, sh, hem, s, 0)
    if view == "N":
        _al_pack(L, P, view, sh, 0)
    else:
        _al_straps(L, P, view, sh, 0)
        _al_gear(L, P, view, hip, 0)
    _al_collar(L, P, view, CX, sh)
    # 右手（S=观众左，N=观众右）握撬棍
    rs = -1 if view == "S" else 1
    for side in (-1, 1):
        sgw = sw * side * (-1 if view == "S" else 1)       # 手臂与同侧腿反相（S 向前=屏幕下）
        wx, wy = CX + side * 13.2, sh + 25 + sgw
        _sleeve(L, P, [(CX + side * 11.6, sh + 2.5), (CX + side * 13.6, sh + 14 + sgw * 0.5), (wx, wy)], 6.0,
                73 + side, 0.92 if side > 0 else 1.0)
        L.paint(L.rect(wx - 3.2, wy - 3.5, wx + 3.2, wy - 0.4, 1.2), _cloth(L, P["coat_lt"], 75) * 0.85, 0.9)   # 袖口翻边
        if side == rs:
            ang = 198 - sgw * 2 if view == "S" else -18 + sgw * 2     # 扁头朝外上方，撬钩朝内下方
            _al_crowbar(L, P, wx, wy + 3.0, ang, 15, 9, hook=1 if view == "S" else -1)
        _al_hand(L, P, wx, wy + 3.0)
    _al_head(L, P, view, CX, head)


# ---------------------------------------------------------------------------
# 内务清杀兵 ОСК
# ---------------------------------------------------------------------------
def _osk_suit(L, P, m, seed, y0, y1, x0=CX - 16, x1=CX + 16):
    L.paint(m, _cloth(L, P["suit"], seed, 0.06, 0.15))
    _form(L, m, x0, x1, y0, y1, (1.3, 0.64), (1.08, 0.8))
    # 橡胶的油亮高光 + 老化裂纹
    hl = smooth(0.62, 0.74, L.noise(3.0, seed + 2, 1.2)) * L.gx(x0, x1, 1.0, 0.25)
    L.paint(m * hl, hexc(P["suit_lt"]), 0.5)
    cr = smooth(0.74, 0.76, L.noise(1.4, seed + 4, 5.0))
    L.paint(m * cr, hexc(P["suit_dk"]), 0.65)
    _frost(L, m, 0.5, seed + 6, y0, y1)


def _osk_glove(L, P, x, y, dim=1.0, rx=3.4, ry=3.8):
    m = L.ellipse(x, y, rx, ry)
    L.paint(m, hexc(P["glove"]) * dim)
    _form(L, m, x - rx, x + rx, y - ry, y + ry, (1.25, 0.7), (1.1, 0.8))
    _frost(L, m, 0.45, int(x * 7 + y))
    L.paint(L.rect(x - rx - 0.4, y - ry - 2.2, x + rx + 0.4, y - ry + 0.6, 1.0), hexc(P["glove"]) * dim * 1.1)   # 长手套口


def _osk_arm(L, P, pts, seed, dim=1.0):
    m = L.line(pts, 7.6)
    _osk_suit(L, P, m, seed, pts[0][1], pts[-1][1], min(p[0] for p in pts) - 4, max(p[0] for p in pts) + 4)
    ex, ey = pts[1]
    _stroke(L, m, [(ex - 3, ey - 1), (ex + 2.5, ey + 1.2)], 0.8, P["suit_dk"], 0.8)
    _stroke(L, m, [(ex - 2.5, ey + 2.2), (ex + 2.8, ey + 3.4)], 0.6, P["suit_dk"], 0.6)
    L.shade(m, dim)


def _osk_lamp(L, P, x, y, side=False):
    w = 3.0 if side else 6.6
    m = L.rect(x - w / 2, y, x + w / 2, y + 9.0, 1.0)
    L.paint(m, _cloth(L, P["lamp"], 91, 0.08, 0.12))
    L.shade(m, L.gx(x - w / 2, x + w / 2, 1.15, 0.75))
    L.rust_streaks(m, 92, 0.5, P["rust"], (1.2, 4))
    if side:
        L.paint(L.ellipse(x + 1.6, y + 3.6, 0.9, 2.0), hexc(P["lens"]))
        return
    L.paint(L.ellipse(x, y + 3.6, 2.4, 2.4), hexc("#3a3426"))
    L.paint(L.ellipse(x, y + 3.6, 1.9, 1.9), hexc(P["lens"]))
    L.paint(L.ellipse(x - 0.5, y + 3.1, 0.8, 0.8), hexc("#ffffff"))
    L.paint(L.ellipse(x, y + 3.6, 4.6, 4.6), hexc("#fff1a8"), 0.12)                     # 镜头泛光
    L.paint(L.rect(x - 2.2, y + 6.8, x + 2.2, y + 8.0, 0.3), hexc("#3a3426"), 0.7)          # 散热栅


def _osk_rifle(L, P, pts_stock, pts_body, supp, mag, dim=1.0):
    """消音 AKM：木托 + 机匣 + 弯弹匣 + 长圆柱消音器。"""
    st = L.line(pts_stock, 2.9)
    L.paint(st, hexc(P["wood"]) * dim)
    L.paint(L.line(pts_stock, 0.8, False), hexc("#8c6448") * dim, 0.6)
    b = L.line(pts_body, 2.5)
    L.paint(b, hexc(P["gun"]) * dim)
    L.paint(L.line(pts_body, 0.6, False), hexc(P["gun_lt"]) * dim, 0.7)
    mm = L.line(mag, 2.2)
    L.paint(mm, hexc(P["gun"]) * dim * 1.1)
    hg = L.line([pts_body[1], (pts_body[1][0] + (pts_body[2][0] - pts_body[1][0]) * 0.45,
                               pts_body[1][1] + (pts_body[2][1] - pts_body[1][1]) * 0.45)], 2.8)
    L.paint(hg, hexc(P["wood"]) * dim)                                                  # 护木
    sp = L.line(supp, 3.2)
    L.paint(sp, hexc(P["supp"]) * dim)
    L.paint(L.line(supp, 0.8, False), hexc("#7c838b") * dim, 0.6)
    _frost(L, np.clip(st + b + sp, 0, 1), 0.3, 93)


def _osk_head(L, P, view, hx, head):
    hood_c = P["suit"]
    if view == "N":
        m = L.ellipse(hx, head - 0.5, 8.8, 10.2)
        _osk_suit(L, P, m, 101, head - 11, head + 10, hx - 9, hx + 9)
        _stroke(L, m, [(hx - 1, head - 9), (hx, head + 9)], 0.8, P["suit_dk"], 0.6)
        return
    if view == "S":
        hood = L.ellipse(hx, head - 1.0, 9.0, 10.4)
        _osk_suit(L, P, hood, 102, head - 11, head + 10, hx - 9, hx + 9)
        face = L.ellipse(hx, head + 1.2, 6.4, 7.8)
        L.paint(face, _cloth(L, P["mask"], 103, 0.08, 0.1))
        _form(L, face, hx - 6, hx + 6, head - 6, head + 9, (1.25, 0.7), (1.1, 0.8))
        L.rim(face, 0, -1.0, "#1a1d21", 0.7)
        for ex in (-3.2, 3.2):                                 # 双圆玻璃目镜
            L.paint(L.ellipse(hx + ex, head - 0.6, 2.9, 2.9), hexc(P["rim"]))
            g = L.ellipse(hx + ex, head - 0.6, 2.2, 2.2)
            L.paint(g, hexc(P["glass"]))
            L.shade(g, L.gy(head - 3, head + 2, 1.25, 0.55))
            L.paint(L.ellipse(hx + ex - 0.8, head - 1.5, 0.8, 0.6), hexc("#f1f6fa"), 0.9)
            L.paint(L.arc(hx + ex, head - 0.6, 2.9, 2.9, 200, 330, 0.5), hexc("#c3cad1"), 0.6)
        L.paint(L.ellipse(hx + 1.2, head + 4.2, 1.6, 1.4), hexc("#2a2f35"))                # 发声膜
        L.paint(L.ellipse(hx + 1.2, head + 4.2, 0.8, 0.7), hexc(P["rim"]), 0.7)
        # 下颚滤罐（偏观众左，朝前下）
        cyl = L.line([(hx - 0.2, head + 5.6), (hx - 2.2, head + 9.0)], 5.6)
        L.paint(cyl, _cloth(L, P["filter"], 104, 0.08, 0.1))
        L.shade(cyl, L.gx(hx - 5, hx + 2, 1.2, 0.72))
        cap = L.ellipse(hx - 2.4, head + 9.6, 3.0, 2.2)
        L.paint(cap, hexc(P["filter_dk"]))
        L.paint(L.arc(hx - 2.4, head + 9.6, 2.2, 1.5, 0, 360, 0.5), hexc(P["filter"]), 0.9)
        L.paint(L.ellipse(hx - 2.4, head + 9.6, 0.9, 0.6), hexc("#15171a"))
        L.paint(L.line([(hx - 4.6, head + 6.4), (hx - 2.0, head + 5.0)], 0.5, False), hexc("#8b9272"), 0.6)
        return
    # E：侧脸
    hood = L.ellipse(hx - 1.2, head - 1.0, 8.4, 10.2)
    _osk_suit(L, P, hood, 105, head - 11, head + 10, hx - 9, hx + 8)
    face = L.poly([(hx + 1.0, head - 6.5), (hx + 5.6, head - 4.0), (hx + 6.6, head + 2.0), (hx + 6.0, head + 6.5),
                   (hx + 1.6, head + 8.6), (hx - 0.5, head + 2)])
    L.paint(face, _cloth(L, P["mask"], 106, 0.08, 0.1))
    L.shade(face, L.gx(hx, hx + 7, 0.85, 1.1))
    L.paint(L.ellipse(hx + 4.4, head - 0.8, 1.9, 2.9), hexc(P["rim"]))
    g = L.ellipse(hx + 4.7, head - 0.8, 1.3, 2.3)
    L.paint(g, hexc(P["glass"]))
    L.shade(g, L.gy(head - 3, head + 2, 1.25, 0.55))
    L.paint(L.ellipse(hx + 4.4, head - 1.8, 0.5, 0.6), hexc("#f1f6fa"), 0.9)
    cyl = L.line([(hx + 4.8, head + 5.4), (hx + 7.8, head + 8.8)], 5.4)
    L.paint(cyl, _cloth(L, P["filter"], 107, 0.08, 0.1))
    L.shade(cyl, L.gy(head + 3, head + 11, 1.15, 0.72))
    L.paint(L.ellipse(hx + 8.6, head + 9.6, 1.9, 2.8), hexc(P["filter_dk"]))
    L.paint(L.ellipse(hx + 8.8, head + 9.7, 0.8, 1.2), hexc("#15171a"))


def _osk_torso(L, P, view, hip, sh, lean):
    if view == "E":
        pts = [(CX - 8 + lean, sh - 1), (CX + 7 + lean, sh), (CX + 10.5 + lean * 0.8, sh + 9),
               (CX + 10.5 + lean * 0.5, sh + 18), (CX + 8.5, hip + 6), (CX - 7, hip + 6), (CX - 9.5, hip),
               (CX - 10 + lean * 0.7, sh + 9)]
    else:
        pts = [(CX - 15.5, sh + 2), (CX - 9, sh - 2), (CX + 9, sh - 2), (CX + 15.5, sh + 2),
               (CX + 15.5, sh + 13), (CX + 13.5, hip), (CX + 12.8, hip + 7), (CX - 12.8, hip + 7),
               (CX - 13.5, hip), (CX - 15.5, sh + 13)]
    m = L.poly(pts)
    _osk_suit(L, P, m, 111, sh - 2, hip + 7)
    # 大褶皱：厚橡胶在腰 / 胸口堆出的横褶
    for fy, a in ((sh + 15, 0.8), (sh + 19, 0.6), (hip + 3, 0.7)):
        _stroke(L, m, [(CX - 12, fy), (CX - 4, fy + 1.4), (CX + 4, fy + 0.4), (CX + 12, fy + 1.6)], 0.9,
                P["suit_dk"], a)
        _stroke(L, m, [(CX - 11, fy - 1.3), (CX - 4, fy + 0.1), (CX + 3, fy - 0.9)], 0.6, P["suit_lt"], a * 0.5)
    if view == "S":
        _stroke(L, m, [(CX + 0.5, sh + 1), (CX + 0.3, hip + 6)], 0.8, P["suit_dk"], 0.85)  # 拉链压条
    L.rim(m, -1.0, 0, "#7d8896", 0.4)
    L.rim(m, 0, 1.0, "#14181d", 0.4)
    return m


def _osk_harness(L, P, view, hip, sh, lean):
    web, dk = hexc(P["web"]), hexc(P["web_dk"])
    if view == "S":
        for sx in (-1, 1):
            m = L.line([(CX + sx * 8.5, sh - 2), (CX + sx * 7.6, sh + 10), (CX + sx * 6.4, hip - 2)], 2.4)
            L.paint(m, web)
            L.shade(m, L.gx(CX - 12, CX + 12, 1.12, 0.78))
        L.paint(L.rect(CX - 8, sh + 6.6, CX + 8, sh + 8.6, 0.4), web)                       # 胸带
        L.paint(L.rect(CX - 1.6, sh + 6.0, CX + 1.6, sh + 9.2, 0.5), hexc("#9aa0a6"))       # 快拆扣
        L.paint(L.line([(CX - 13, sh + 24), (CX + 10, hip + 9)], 2.0), web)                 # 斜挎枪带
    elif view == "E":
        m = L.line([(CX - 7 + lean, sh - 1), (CX + 1 + lean, sh + 2), (CX + 6 + lean * 0.6, sh + 18)], 2.4)
        L.paint(m, web)
        L.paint(L.line([(CX - 9.5, sh + 4), (CX - 8.5 + lean * 0.5, sh + 18)], 2.0), dk)
    else:
        for sx in (-1, 1):
            L.paint(L.line([(CX + sx * 8.5, sh - 2), (CX + sx * 6.2, hip - 2)], 2.4), web)
        L.paint(L.rect(CX - 10, sh + 15, CX + 10, sh + 17, 0.4), web)
    belt = L.rect(CX - 14, hip - 2.4, CX + 14, hip + 1.6, 0.6) if view != "E" else \
        L.rect(CX - 10, hip - 2.4, CX + 10.5, hip + 1.6, 0.6)
    L.paint(belt, web)
    L.shade(belt, L.gx(CX - 14, CX + 14, 1.12, 0.75))
    pouch = _cloth(L, P["pouch"], 121, 0.1, 0.1)
    if view == "S":
        boxes = [(CX - 12.5, CX - 7.0), (CX - 6.6, CX - 1.6)]
        cx_ = CX + 11.0
    elif view == "E":
        boxes = [(CX - 1.5, CX + 4.0)]
        cx_ = CX - 7.0
    else:
        boxes = [(CX - 4, CX + 1), (CX + 1.5, CX + 6.5)]
        cx_ = CX - 10.5
    for x0, x1 in boxes:                                       # 弹匣包
        m = L.rect(x0, hip - 4.5, x1, hip + 4.5, 0.9)
        L.paint(m, pouch)
        L.shade(m, L.gy(hip - 5, hip + 5, 1.15, 0.78))
        L.paint(L.rect(x0, hip - 4.5, x1, hip - 2.0, 0.6), hexc(P["web"]) * 1.05)
        L.paint(L.rect((x0 + x1) / 2 - 0.5, hip - 2.6, (x0 + x1) / 2 + 0.5, hip - 1.2, 0.2), hexc("#2a2c26"))
        _frost(L, m, 0.4, int(x0 * 3))
    can = L.rect(cx_ - 3.0, hip - 3.5, cx_ + 3.0, hip + 6.5, 2.4)                          # 水壶
    L.paint(can, _cloth(L, P["canteen"], 122, 0.08, 0.1))
    _form(L, can, cx_ - 3, cx_ + 3, hip - 4, hip + 7, (1.25, 0.7), (1.1, 0.8))
    L.paint(L.rect(cx_ - 1.0, hip - 5.0, cx_ + 1.0, hip - 3.2, 0.4), hexc("#3b3e35"))
    _frost(L, can, 0.45, 123)


def _osk_tanks(L, P, view, sh, lean):
    if view == "E":
        cyl = [(CX - 17 + lean, CX - 8 + lean)]
    else:
        cyl = [(CX - 10, CX - 1), (CX + 1, CX + 10)]
    allm = None
    for x0, x1 in cyl:
        m = L.rect(x0, sh - 5, x1, sh + 25, 4.2)
        L.paint(m, _cloth(L, P["tank"], 131, 0.06, 0.12))
        _form(L, m, x0, x1, sh - 5, sh + 25, (1.45, 0.6), (1.1, 0.85))
        L.paint(L.line([(x0 + 2.2, sh - 2), (x0 + 2.2, sh + 22)], 1.1, False) * m, hexc(P["tank_lt"]), 0.5)
        L.rust_streaks(m, 132 + int(x0), 0.35, P["rust"], (1.2, 6))
        for by in (sh + 3, sh + 17):
            L.paint(L.rect(x0 - 0.5, by, x1 + 0.5, by + 2.2, 0.4), hexc(P["web"]))
            L.paint(L.rect((x0 + x1) / 2 - 1.2, by - 0.2, (x0 + x1) / 2 + 1.2, by + 2.4, 0.3), hexc("#8d9196"))
        allm = m if allm is None else np.clip(allm + m, 0, 1)
    vx = (cyl[0][0] + cyl[-1][1]) / 2 if view != "E" else (cyl[0][0] + cyl[0][1]) / 2
    L.paint(L.rect(vx - 2.0, sh - 8, vx + 2.0, sh - 4, 0.6), hexc("#5d646b"))               # 阀门
    L.paint(L.rect(vx - 3.2, sh - 8.6, vx + 3.2, sh - 7.4, 0.4), hexc("#3b4046"))
    _frost(L, allm, 0.55, 133, sh - 6, sh + 25)
    return vx


def _draw_osk(L, P, view, phase, crouch, walking):
    s, c, hip, sh, head = _hero_pose(phase, crouch, walking, P)
    s *= 0.85                                     # 步子更沉
    sw = s * 1.6
    if view == "E":
        lean = 4.0 if crouch else 0.6
        hx = CX + 2.2 + lean * 1.1
        _osk_arm(L, P, [(CX - 2 + lean, sh + 4), (CX + 2 + lean * 0.6, sh + 15), (CX + 13 + lean * 0.5, sh + 20)],
                 141, 0.68)                                     # 远臂托护木
        _hero_legs(L, P, view, s, c, hip, crouch, 140)
        vx = _osk_tanks(L, P, view, sh, lean)
        _osk_torso(L, P, view, hip, sh, lean)
        _osk_harness(L, P, view, hip, sh, lean)
        _osk_lamp(L, P, CX + 9.6 + lean * 0.7, sh + 4, side=True)
        drape = L.poly([(hx - 7.5, head + 3), (hx + 3.5, head + 6), (CX + 7 + lean, sh + 2), (CX - 8 + lean, sh + 1)])
        _osk_suit(L, P, drape, 147, head, sh + 3)                   # 兜帽垂到肩上（脖子）
        _stroke(L, drape, [(hx - 5, head + 7), (CX - 2 + lean, sh + 1)], 0.8, P["suit_dk"], 0.7)
        _osk_head(L, P, view, hx, head)
        _hose(L, [(hx + 5.0, head + 8.0), (hx + 3.5, sh + 4.5), (CX - 1 + lean, sh + 1.0), (vx + 1.0, sh - 7.0)],
              2.6, P["hose"], P["hose_lt"])
        g0 = (CX + 2 + lean * 0.5, sh + 18)
        _osk_rifle(L, P, [(CX - 8 + lean * 0.5, sh + 15), g0],
                   [g0, (CX + 6 + lean * 0.5, sh + 19.5), (CX + 18, sh + 23.5)],
                   [(CX + 18, sh + 23.5), (CX + 27, sh + 26.5)],
                   [(CX + 7, sh + 20.5), (CX + 8, sh + 25), (CX + 10.5, sh + 28)])
        _osk_glove(L, P, CX + 13 + lean * 0.5, sh + 21.5, 0.72, 3.0, 3.3)
        _osk_arm(L, P, [(CX + 0.5 + lean, sh + 4), (CX - 1.5 + lean * 0.6, sh + 14), (CX + 4.5 + lean * 0.5, sh + 19)],
                 142)                                           # 近臂握握把
        _osk_glove(L, P, CX + 5 + lean * 0.5, sh + 20.5, 1.0, 3.2, 3.4)
        return
    _hero_legs(L, P, view, s, c, hip, crouch, 140)
    if view == "N":
        _osk_torso(L, P, view, hip, sh, 0)
        _osk_harness(L, P, view, hip, sh, 0)
        vx = _osk_tanks(L, P, view, sh, 0)
        drape = L.poly([(CX - 7, head + 5), (CX + 7, head + 5), (CX + 10, sh + 1), (CX - 10, sh + 1)])
        _osk_suit(L, P, drape, 148, head, sh + 3)
        _osk_head(L, P, view, CX, head)
        _hose(L, [(vx + 1, sh - 7), (CX + 6, sh - 9), (CX + 9.5, head + 6)], 2.6, P["hose"], P["hose_lt"])
        for side in (-1, 1):
            g = sw * side
            _osk_arm(L, P, [(CX + side * 14, sh + 3), (CX + side * 16.2, sh + 14 + g * 0.5),
                            (CX + side * 15.6, sh + 24 + g)], 143 + side, 0.94 if side < 0 else 1.0)
            _osk_glove(L, P, CX + side * 15.6, sh + 27 + g)
        return
    # S
    L.paint(L.rect(CX + 9, sh - 7, CX + 14, sh + 4, 2), hexc(P["tank"]) * 0.8)               # 肩后露出的气瓶
    _osk_torso(L, P, view, hip, sh, 0)
    _osk_harness(L, P, view, hip, sh, 0)
    _osk_arm(L, P, [(CX + 14.2, sh + 3), (CX + 16.6, sh + 14 - sw * 0.5), (CX + 16.2, sh + 24 - sw)], 144, 0.92)
    _osk_glove(L, P, CX + 16.2, sh + 27.5 - sw)
    _osk_lamp(L, P, CX + 6.8, sh + 3.8)
    g0 = (CX - 5.5, sh + 17)
    _osk_rifle(L, P, [(CX - 14.5, sh + 7), g0],
               [g0, (CX + 1, sh + 22), (CX + 8, sh + 28)],
               [(CX + 8, sh + 28), (CX + 14.5, sh + 34)],
               [(CX - 3.5, sh + 19), (CX - 4.5, sh + 24), (CX - 2.5, sh + 28)])
    _osk_arm(L, P, [(CX - 14.2, sh + 3), (CX - 16.2, sh + 13), (CX - 8.5, sh + 18.5)], 145)
    _osk_glove(L, P, CX - 7.6, sh + 19.5, 1.0, 3.3, 3.5)
    drape = L.poly([(CX - 7, head + 5), (CX + 7, head + 5), (CX + 11, sh + 1.5), (CX - 11, sh + 1.5)])
    _osk_suit(L, P, drape, 149, head, sh + 3)
    _osk_head(L, P, view, CX, head)
    _hose(L, [(CX + 3.0, head + 7.5), (CX + 4.5, sh + 4), (CX + 9.5, sh + 2.5), (CX + 12.0, sh - 1.0)],
          2.6, P["hose"], P["hose_lt"])
    # 兜帽在肩上的褶
    m = L.poly([(CX - 9, head + 6), (CX - 14, sh + 2), (CX - 7, sh + 1)])
    _osk_suit(L, P, m, 146, head, sh + 3)


# ---------------------------------------------------------------------------
# CHR_04 回退半人（退烧中的感染者：还有瞳孔、潮红、颈侧一片灰鳞；双臂抱身发抖）
#   列：0 抱臂待机 · 1-4 蹒跚 · 5 蜷坐 · 6 倒地 · 7 护头（被光照到）
# ---------------------------------------------------------------------------
HALF = dict(
    kind="half",
    coat="#4f4b3b", coat_lt="#716c55", coat_dk="#2c2a22",       # 褪色棉袄（телогрейка）
    trousers="#383b42", boots="#6f675b", boots_lt="#938a7b",      # 裹着破布的旧靴
    skin="#cf9f8a", skin_dk="#9c6e5e", flush="#cc5b50", scale="#8e9497", hair="#3a3129",
    thigh_w=8.4, boot_w=6.8, boot_h=11, hip_sep=4.2,
    stand=(64.0, 38.0, 27.5), crouch=(97.0, 72.0, 61.5),
)


def _half_head(L, P, view, hx, head, cover=False):
    skin = hexc(P["skin"])
    if view == "N":
        m = L.ellipse(hx, head, 5.0, 6.2)
        L.paint(m, skin * 0.9)
        hair = L.ellipse(hx, head - 1.0, 5.2, 5.8)
        L.paint(hair, _cloth(L, P["hair"], 151, 0.15, 0.1))
        L.paint(L.ellipse(hx + 2.5, head + 4.0, 2.2, 1.6), hexc(P["scale"]), 0.8)       # 后颈灰鳞
        _frost(L, hair, 0.45, 152, head - 7, head)
        return
    ox = 1.0 if view == "E" else 0.0
    face = L.ellipse(hx + ox, head + 0.4, 4.6 if view == "S" else 4.2, 5.8)
    L.paint(face, skin)
    L.shade(face, L.gx(hx - 5, hx + 5, 1.12, 0.78))
    L.paint(L.ellipse(hx + ox - 2.4, head + 2.0, 1.8, 1.4) * face, hexc(P["flush"]), 0.5)    # 高烧潮红
    L.paint(L.ellipse(hx + ox + 2.4, head + 2.0, 1.8, 1.4) * face, hexc(P["flush"]), 0.5)
    sc = L.ellipse(hx + ox + 3.2, head + 3.5, 2.4, 3.2) * face                               # 右颊灰鳞
    L.paint(sc, hexc(P["scale"]), 0.75)
    L.paint(sc * smooth(0.55, 0.7, L.noise(0.6, 153)), hexc("#d4d8d6"), 0.7)
    if view == "S":
        for ex in (-1.9, 1.9):                                 # 还有瞳孔：白眼 + 黑瞳（与狂暴者的黑眼窝区分）
            L.paint(L.ellipse(hx + ex, head - 0.3, 1.2, 0.85), hexc("#e8e2dc"))
            L.paint(L.ellipse(hx + ex, head - 0.2, 0.55, 0.6), hexc("#1a1514"))
            L.paint(L.ellipse(hx + ex, head + 1.0, 1.4, 0.6), hexc(P["skin_dk"]), 0.6)
        L.paint(L.rect(hx - 1.4, head + 3.8, hx + 1.4, head + 4.5, 0.3), hexc("#6a3b35"), 0.85)
    else:
        L.paint(L.ellipse(hx + 3.2, head - 0.3, 0.9, 0.8), hexc("#e8e2dc"))
        L.paint(L.ellipse(hx + 3.5, head - 0.2, 0.45, 0.55), hexc("#1a1514"))
        L.paint(L.ellipse(hx + 5.0, head + 1.2, 0.9, 1.3), skin * 0.95)
    hair = L.poly([(hx - 5.2, head - 1), (hx - 4.4, head - 5.6), (hx, head - 7.0), (hx + 4.6, head - 5.4),
                   (hx + 5.0 + ox, head - 2.4), (hx + 2, head - 4.2), (hx - 2.5, head - 3.6), (hx - 4.6, head + 1.5)])
    L.paint(hair, _cloth(L, P["hair"], 154, 0.15, 0.1))
    L.paint(hair * smooth(0.5, 0.7, L.noise(0.6, 155)), hexc("#5c5146"), 0.5)                # 汗湿的乱发
    _frost(L, hair, 0.4, 156, head - 7, head)


def _half_jacket(L, P, view, hip, sh, lean, hug=True):
    hem = hip + 8
    if view == "E":
        pts = [(CX - 6 + lean, sh - 1), (CX + 5 + lean, sh), (CX + 7.5 + lean * 0.8, sh + 9), (CX + 6.5, hem),
               (CX - 7.5, hem), (CX - 8 + lean * 0.6, sh + 9)]
    else:
        pts = [(CX - 10.5, sh + 1), (CX - 5, sh - 2), (CX + 5, sh - 2), (CX + 10.5, sh + 1), (CX + 11, sh + 10),
               (CX + 11.5, hem), (CX - 11.5, hem), (CX - 11, sh + 10)]
    m = L.poly(pts)
    L.paint(m, _cloth(L, P["coat"], 161, 0.08, 0.14))
    cx_ = CX + (lean * 0.6 if view == "E" else 0.0)
    collar = L.rect(cx_ - (4.6 if view != "E" else 3.6), sh - 3.2, cx_ + (4.6 if view != "E" else 4.4), sh + 1.2, 1.4)
    L.paint(collar, _cloth(L, P["coat_lt"], 164, 0.08, 0.1) * 0.9)                 # 立领，脖子根收进领口
    if view == "S":
        L.paint(L.poly([(cx_ - 1.6, sh - 3.2), (cx_ + 1.6, sh - 3.2), (cx_, sh + 1.0)]), hexc(P["skin_dk"]))
    m = np.clip(m + collar, 0, 1)
    _form(L, m, CX - 12, CX + 12, sh, hem, (1.22, 0.7), (1.05, 0.82))
    for fy in np.arange(sh + 5, hem, 4.2):                     # 棉袄绗缝横线
        _stroke(L, m, [(CX - 12, fy), (CX + 12, fy + 0.6)], 0.6, P["coat_dk"], 0.7)
    L.paint(m * smooth(0.76, 0.79, L.noise(1.6, 162)), hexc("#c9c1a8"), 0.7)                 # 破口露棉絮
    _frost(L, m, 0.55, 163, sh, hem)
    L.rim(m, -1.0, 0, P["coat_lt"], 0.45)
    return m


def _half_arm(L, P, pts, seed, dim=1.0):
    m = L.line(pts, 4.8)
    L.paint(m, _cloth(L, P["coat"], seed) * 0.82 * dim)
    _form(L, m, min(p[0] for p in pts) - 3, max(p[0] for p in pts) + 3, pts[0][1] - 2, pts[-1][1] + 2,
          (1.25, 0.72), (1.1, 0.85))
    L.rim(m, 0, -0.9, P["coat_lt"], 0.55)
    L.rim(m, 0, 0.9, "#14130f", 0.6)
    _frost(L, m, 0.4, seed + 1, pts[0][1] - 2, pts[-1][1] + 2)
    return m


def _half_hand(L, P, x, y):
    m = L.ellipse(x, y, 2.1, 1.9)
    L.paint(m, hexc(P["skin"]) * 0.95)
    L.paint(L.ellipse(x + 0.3, y + 0.6, 1.5, 0.9) * m, hexc("#7a6390"), 0.45)


def _draw_half(L, P, view, col):
    crouch = col == 5
    walking = col in (1, 2, 3, 4)
    phase = (col - 1) / 4 if walking else 0.0
    if col == 6:                                               # 倒地：侧躺，雪落在身上
        body = L.rect(16, 96, 50, 104.5, 3.6)
        L.paint(body, _cloth(L, P["coat"], 171, 0.08, 0.14))
        _form(L, body, 16, 50, 96, 105, (1.0, 1.0), (1.15, 0.75))
        legs = L.line([(18, 101), (6, 103.5)], 6.0)
        L.paint(legs, _cloth(L, P["trousers"], 172))
        L.paint(L.ellipse(5, 104, 3.2, 2.4), hexc(P["boots"]))
        arm = L.line([(42, 99), (50, 104), (58, 105.5)], 3.8)
        L.paint(arm, _cloth(L, P["coat"], 173) * 0.8)
        L.paint(L.ellipse(59.5, 105.6, 2.0, 1.6), hexc(P["skin"]) * 0.85)
        hd = L.ellipse(55, 99.2, 5.0, 4.2)
        L.paint(hd, hexc(P["skin"]) * 0.78)
        L.paint(L.ellipse(54.5, 97.0, 5.0, 2.6), hexc(P["hair"]))
        L.paint(L.ellipse(57, 101, 2.0, 1.6) * hd, hexc(P["scale"]), 0.8)
        _frost(L, np.clip(body + legs + hd, 0, 1), 0.7, 174, 95, 106)
        return
    s, c, hip, sh, head = _hero_pose(phase, crouch, walking, P)
    s *= 0.6                                                   # 蹒跚：步子小
    lean = (3.5 if crouch else 2.6) if view == "E" else 0.0
    hx = CX + (lean * 1.3 + 1.2 if view == "E" else 0.0)
    if not crouch:
        _hero_legs(L, P, view, s, c, hip, False, 176)
    ex = 1.2 if view == "E" else 0.0
    nx = hx - (lean * 0.6 if view == "E" else 0.0)
    neck = L.poly([(hx - 2.6 + ex, head + 3.0), (hx + 2.6 + ex, head + 3.0), (nx + 3.6, sh + 2.0), (nx - 3.6, sh + 2.0)])
    L.paint(neck, hexc(P["skin"]))
    L.shade(neck, L.gx(nx - 4, nx + 4, 1.05, 0.7))
    L.shade(neck, L.gy(head + 3, sh + 2, 0.72, 1.0))                                           # 下巴投影
    L.paint(L.rect(nx + 0.6, head + 5.0, nx + 3.4, sh + 1.5, 0.6) * neck, hexc(P["scale"]), 0.75)   # 颈侧灰鳞
    _half_jacket(L, P, view, hip, sh, lean)
    if crouch:                                                 # 蜷坐：膝盖顶到胸口，双臂环膝
        kx = CX + (5 if view == "E" else 0)
        if view != "N":
            for fx in ((-4.5, 4.5) if view == "S" else (9.0,)):
                L.paint(L.ellipse(CX + fx, GY_ - 1.8, 3.6, 2.4), hexc(P["boots"]))
            knees = L.ellipse(kx, sh + 14, 8.0 if view == "S" else 6.0, 7.0)
            L.paint(knees, _cloth(L, P["trousers"], 175))
            _form(L, knees, kx - 8, kx + 8, sh + 7, sh + 21, (1.2, 0.7), (1.15, 0.8))
            _frost(L, knees, 0.6, 178, sh + 7, sh + 21)
            if view == "S":
                for side in (-1, 1):
                    _half_arm(L, P, [(CX + side * 9.5, sh + 3), (CX + side * 10.5, sh + 13), (CX + side * 2, sh + 18)],
                              186 + side)
                    _half_hand(L, P, CX + side * 1.5, sh + 18.5)
            else:
                _half_arm(L, P, [(CX + 1 + lean, sh + 3), (CX + 3 + lean, sh + 13), (CX + 10, sh + 17)], 186)
                _half_hand(L, P, CX + 10.5, sh + 17)
        _half_head(L, P, view, hx, head)
        return
    if view == "N":
        _half_head(L, P, view, hx, head)
        for side in (-1, 1):
            _half_arm(L, P, [(CX + side * 9.5, sh + 3), (CX + side * 11, sh + 12), (CX + side * 7, sh + 17)], 177 + side)
        return
    if col == 7:                                               # 护头：双臂抬起挡光
        _half_head(L, P, view, hx, head + 1)
        if view == "S":
            for side in (-1, 1):
                _half_arm(L, P, [(CX + side * 9.5, sh + 3), (CX + side * 11.5, sh - 6), (CX + side * 3, head - 3)],
                          179 + side)
                _half_hand(L, P, CX + side * 2.6, head - 3.6)
        else:
            _half_arm(L, P, [(CX + 2 + lean, sh + 3), (CX + 8 + lean, sh - 5), (hx + 6, head - 3)], 179)
            _half_hand(L, P, hx + 6.4, head - 3.6)
        return
    _half_head(L, P, view, hx, head)
    # 抱臂发抖：前臂横在胸前
    if view == "S":
        for side, yy in ((-1, sh + 12), (1, sh + 14.5)):
            _half_arm(L, P, [(CX + side * 9.5, sh + 2.5), (CX + side * 11, sh + 10.5), (CX - side * 6, yy)], 181 + side)
            _half_hand(L, P, CX - side * 7.0, yy - 0.3)
    else:
        _half_arm(L, P, [(CX + 1 + lean, sh + 3), (CX + 2 + lean, sh + 11), (CX + 8 + lean, sh + 12)], 185)
        _half_hand(L, P, CX + 8.8 + lean, sh + 11.8)


# ---------------------------------------------------------------------------
ALEKSEI = dict(
    kind="aleksei",
    coat="#262b34", coat_lt="#434b5a", coat_dk="#12151b",
    fur="#8f877b", fur_lt="#bcb4a3", fur_dk="#5c574d",
    hat="#76787c", hat_lt="#a2a4a7", hat_dk="#4a4c50",
    skin="#c8a28c", skin_dk="#8f6a59", cheek="#bd786c",
    hand="#b39a95", bite="#5e4f86",
    pack="#665a40", pack_lt="#83744f", pack_dk="#41372a", strap="#3f3527", buckle="#9a937c",
    belt="#4c4636", key="#a59e90", brass="#8c7445", glass="#d6b462",
    boots="#87877f", boots_lt="#b3b3ab", trousers="#2c3038",
    iron="#1c1e22", iron_lt="#575c64",
    thigh_w=8.6, boot_w=7.6, boot_h=16, hip_sep=4.4,
    stand=(62.0, 35.0, 22.0), crouch=(82.0, 57.0, 44.0),
)
OSK = dict(
    kind="osk",
    suit="#4b5562", suit_lt="#7a8796", suit_dk="#262d36",      # 铅灰偏蓝的橡胶防护服（参考图 v2）
    trousers="#46505c", boots="#1d2025", boots_lt="#3e444c",
    glove="#30353c", mask="#3a4048", glass="#7f95a8", rim="#7d868f",
    filter="#6f7455", filter_dk="#474b36",
    hose="#1e2227", hose_lt="#3e454d",
    web="#7d7a5b", web_dk="#55533e", pouch="#6c6b4e", canteen="#5f6450",
    lamp="#c8b466", lens="#fff4bb", rust="#7a4a30",
    tank="#2f353c", tank_lt="#69737e",
    wood="#6a4632", gun="#22252a", gun_lt="#545b63", supp="#4b5057",
    thigh_w=11.0, boot_w=9.4, boot_h=19, hip_sep=5.4,
    stand=(63.0, 36.0, 21.0), crouch=(82.0, 57.0, 42.0),
)


def frame(P, view, phase, crouch, walking):
    L = Layer(FW, FH, 4)
    if P["kind"] == "osk":
        _draw_osk(L, P, view, phase, crouch, walking)
    else:
        _draw_aleksei(L, P, view, phase, crouch, walking)
    return L.finish(outline="#090b10", outline_a=0.72)


def sheet(P) -> Image.Image:
    img = Image.new("RGBA", (FW * 8, FH * 3), (0, 0, 0, 0))
    for row, view in enumerate(("S", "E", "N")):
        cells = [(0.0, False, False)] + [(k / 4, False, True) for k in range(4)] + \
                [(0.0, True, False), (0.25, True, True), (0.75, True, True)]
        for col, (ph, cr, wk) in enumerate(cells):
            img.alpha_composite(frame(P, view, ph, cr, wk), (col * FW, row * FH))
    return img


def half_sheet() -> Image.Image:
    img = Image.new("RGBA", (FW * 8, FH * 3), (0, 0, 0, 0))
    for row, view in enumerate(("S", "E", "N")):
        for col in range(8):
            L = Layer(FW, FH, 4)
            _draw_half(L, HALF, view, col)
            img.alpha_composite(L.finish(outline="#090b10", outline_a=0.72), (col * FW, row * FH))
    return img
