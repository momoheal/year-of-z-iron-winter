"""剧情 NPC + 战役伙伴专属立绘。

NPC（夜潜站着不动，出静态立绘即可）：
  安娜    浅灰蓝薄棉袄 + 毛领 + 深棕长发 + 手腕旧皮带（0419 把自己捆在铁架床上的那两根）
  梁诺夫  脏白大褂 + 半秃花白 + 圆眼镜 + 颈挂听诊器（老眼科主任）
  古丽娅  白大褂 + 暗红头巾 + 臂抱病历夹（女流调医师）
  幸存者  褪色军绿棉袄 + 旧围巾 + 网兜包袱（黑市平民）
  摊主    深棕皮大衣 + 便帽 + 毛领 + 腰包 + 叼烟（黑市）

战役伙伴（MATES，也可作夜潜跟随者的形象）：
  帕维尔  深蓝工装 + 鸭舌帽 + 花白胡茬 + 手持扳手（钳工老爹）
  伊万    藏青列车长制服 + 大檐帽 + 怀表链 + 手持信号灯（老轨）
  灰烬    灰白狼犬（四足侧视、立耳，尺寸 96×80，与人形立绘不同）

人形立绘规格 72×112、pivot 脚底中心 (36,108)；灰烬 96×80、pivot (48,76)。
脖子修正：头 / 五官整体下移 4px（头中心 32、下巴 41），脖子 rect 缩短到 40-46，
肩膀与领口仍在 44 附近 —— 脖子只露 2~3px，不再"长颈鹿"。

单独预览：python gen_npcs.py  → 写 30_props + 打印路径 + _all.png。
正式注册进 manifest 走：python gen_assets.py --level <id> props --only <名字,...>。
"""
from __future__ import annotations

import os

from artlib import Layer, hexc

FW, FH, PIV = 72, 112, (36, 108)
CX = 36.0
HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.abspath(os.path.join(HERE, "..", "..", "art"))


# ---------------------------------------------------------------------------
# 共享人体（正面站姿，脚底 106；头 ellipse 中心 32、眼 31.5、下巴 41、肩 44）
# ---------------------------------------------------------------------------
def _legs(L, trousers, boots):
    for sx in (-1, 1):
        x = CX + sx * 4.0
        L.paint(L.rect(x - 3, 78, x + 3, 101, 1.5), L.tex(trousers, 0.10, 4, int(x) + 60))
        boot = L.ellipse(x + 0.5, 103, 4.6, 3.0)
        L.paint(boot, hexc(boots))
        L.shade(boot, 0.9)


def _coat(L, sh, hem, color, seed, style="coat"):
    body = L.poly([(CX - sh, 44), (CX + sh, 44), (CX + sh + 3, hem), (CX - sh - 3, hem)])
    L.paint(body, L.tex(color, 0.10, 5, seed))
    L.shade(body, L.gx(CX - sh - 3, CX + sh + 3, 1.14, 0.76))     # 左亮右暗
    L.paint(L.line([(CX, 48), (CX, hem - 2)], 0.9), hexc("#000000"), 0.22)   # 前襟
    for k in range(3):
        L.paint(L.ellipse(CX + 2.2, 53 + k * 9, 0.9, 0.9), hexc("#20232a"), 0.55)
    if style == "gown":
        L.paint(L.poly([(CX - 4, 44), (CX + 4, 44), (CX, 56)]), hexc("#3f3f45"))  # 领口 V
    L.grime(body, seed + 3, 0.18)
    L.rim(body, -1.2, 0, "#a9bdd2", 0.35)
    return body


def _arms(L, sh, color, skin, mode="down"):
    if mode == "clasp":     # 双手交握在身前（虚弱 / 拘谨）
        for sx in (-1, 1):
            L.paint(L.line([(CX + sx * (sh - 2), 46), (CX + sx * (sh - 1), 60), (CX + sx * 3, 71)], 6.2),
                    L.tex(color, 0.08, 4, 7))
        for sx in (-1, 1):
            L.paint(L.ellipse(CX + sx * 2.4, 72, 2.8, 3.0), hexc(skin))
    else:                   # 自然下垂
        for sx in (-1, 1):
            L.paint(L.line([(CX + sx * (sh - 1), 46), (CX + sx * (sh + 1), 60), (CX + sx * (sh + 0.5), 74)], 6.4),
                    L.tex(color, 0.08, 4, 7 + sx))
            L.paint(L.ellipse(CX + sx * (sh + 0.5), 76, 2.6, 3.2), hexc(skin))


def _head(L, skin, blush=None):
    L.paint(L.rect(CX - 2.5, 40, CX + 2.5, 46, 1), hexc(skin))     # 脖子（短：只露 2~3px）
    head = L.ellipse(CX, 32, 8, 9)
    L.paint(head, hexc(skin))
    L.shade(head, L.gx(CX - 8, CX + 8, 1.12, 0.82))
    for sx in (-1, 1):                                             # 眼
        L.paint(L.ellipse(CX + sx * 3, 31.5, 0.9, 1.1), hexc("#241d18"))
    L.paint(L.line([(CX, 33), (CX, 35.5)], 0.8), hexc("#000000"), 0.16)   # 鼻影
    L.paint(L.line([(CX - 1.6, 37.5), (CX + 1.6, 37.5)], 0.8), hexc("#5a3a32"), 0.55)  # 嘴
    if blush:                                                      # 退烧后的潮红
        for sx in (-1, 1):
            L.paint(L.ellipse(CX + sx * 4.4, 35, 2.2, 1.6), hexc(blush), 0.35)
    return head


# ---------------------------------------------------------------------------
# 夜潜剧情 NPC / 黑市人物
# ---------------------------------------------------------------------------
def anna():
    L = Layer(FW, FH, 3)
    skin = "#cbaa90"
    _legs(L, "#4a4a52", "#3a3230")
    L.paint(L.rect(CX - 8, 85, CX + 8, 90), hexc("#b9b2a4"))       # 棉袄下露出的病号服
    _coat(L, 11.0, 86, "#8a94a0", 11)                              # 浅灰蓝薄棉袄
    L.paint(L.ellipse(CX, 45, 7.5, 3.0), hexc("#b9b2a4"))          # 毛翻领
    _arms(L, 11.0, "#8a94a0", skin, "clasp")
    _head(L, skin, blush="#c98a7a")
    hair = "#3a2c24"                                               # 深棕长发
    L.paint(L.ellipse(CX, 25, 8.6, 5.2), hexc(hair))               # 发顶（不遮眼）
    L.paint(L.rect(CX - 8, 23, CX + 8, 27, 2.5), hexc(hair))       # 刘海
    for sx in (-1, 1):                                             # 两侧发片垂到肩
        L.paint(L.poly([(CX + sx * 8.4, 26), (CX + sx * 9.4, 45), (CX + sx * 6.4, 48),
                        (CX + sx * 6.6, 30)]), hexc(hair))
    L.paint(L.line([(CX - 4.5, 70.5), (CX + 4.5, 70.5)], 1.6), hexc("#6a4a2a"))  # 手腕旧皮带
    L.paint(L.rect(CX - 1, 69.3, CX + 1, 71.7), hexc("#8a6a3a"))
    return L.finish(), PIV


def leonov():
    L = Layer(FW, FH, 3)
    skin = "#c4a48c"
    _legs(L, "#3f3f45", "#2f2a28")
    _coat(L, 12.5, 88, "#c8c9c4", 23, style="gown")                # 脏白大褂
    _arms(L, 12.5, "#c8c9c4", skin)
    _head(L, skin)
    hair = "#b9b9b2"                                               # 半秃：只两侧 + 后脑花白
    for sx in (-1, 1):
        L.paint(L.ellipse(CX + sx * 7.3, 33, 1.8, 4.4), hexc(hair))
    L.paint(L.arc(CX, 32, 8.0, 9.0, 20, 160, 2.2), hexc(hair))     # 后脑一圈
    for sx in (-1, 1):                                             # 圆眼镜
        L.paint(L.arc(CX + sx * 3.1, 31.5, 2.7, 2.7, 0, 360, 0.8), hexc("#26262a"))
    L.paint(L.line([(CX - 0.6, 31.5), (CX + 0.6, 31.5)], 0.8), hexc("#26262a"))
    L.paint(L.arc(CX, 46, 4.5, 6, 20, 160, 1.2), hexc("#2a2d30"))  # 颈挂听诊器
    L.paint(L.line([(CX + 2, 50), (CX + 4, 60)], 1.2), hexc("#2a2d30"))
    L.paint(L.ellipse(CX + 4, 61, 2.2, 2.2), hexc("#3a3d42"))
    L.paint(L.ellipse(CX + 4, 61, 1.1, 1.1), hexc("#8a8f96"))
    return L.finish(), PIV


def gulya():
    L = Layer(FW, FH, 3)
    skin = "#caa88f"
    _legs(L, "#43434b", "#332c2a")
    _coat(L, 11.5, 88, "#bfbfb8", 31, style="gown")                # 白大褂
    _arms(L, 11.5, "#bfbfb8", skin)
    _head(L, skin)
    scarf = "#7a3b38"                                              # 暗红头巾（包头，不遮眼）
    L.paint(L.ellipse(CX, 25, 9, 5.6), hexc(scarf))
    L.paint(L.rect(CX - 9, 24, CX + 9, 28.5, 2), hexc(scarf))
    L.paint(L.poly([(CX + 7, 30), (CX + 12.5, 36), (CX + 6.5, 37)]), hexc("#632f2c"))  # 脑后结
    L.paint(L.rect(CX + 1, 52, CX + 11, 68, 1), hexc("#7a5a34"))   # 臂抱病历夹
    L.paint(L.rect(CX + 2, 53, CX + 10, 56), hexc("#d8cfb8"))
    L.paint(L.rect(CX + 1, 52, CX + 11, 54), hexc("#5a4020"))
    L.paint(L.ellipse(CX + 3, 66, 2.4, 2.8), hexc(skin))
    return L.finish(), PIV


def survivor():
    """黑市普通幸存者：褪色军绿棉袄 + 旧围巾 + 拢手 + 背着网兜包袱，一脸疲惫。"""
    L = Layer(FW, FH, 3)
    skin = "#b99c82"
    _legs(L, "#3a3c33", "#241f19")
    _coat(L, 12.0, 88, "#5c6148", 41)                              # 褪色军绿棉袄
    _arms(L, 12.0, "#5c6148", skin, "clasp")
    _head(L, skin)
    hair = "#241f18"
    L.paint(L.ellipse(CX, 25, 8.4, 5.0), hexc(hair))               # 短发顶
    L.paint(L.rect(CX - 8, 23, CX + 8, 27, 2.5), hexc(hair))       # 刘海
    L.paint(L.ellipse(CX, 45, 7.5, 3.2), hexc("#6a5c46"))          # 旧围巾
    L.paint(L.rect(CX - 2, 47, CX + 3, 60), hexc("#5c4f3c"))       # 围巾垂下
    L.paint(L.poly([(CX + 12, 52), (CX + 22, 54), (CX + 25, 70), (CX + 20, 76), (CX + 11, 72)]),
            hexc("#6b5f47"))                                        # 背在右肩后的网兜包袱
    for i in range(4):
        L.paint(L.line([(CX + 12 + i * 3, 54), (CX + 14 + i * 3, 74)], 0.6), hexc("#4a4132"), 0.5)
        L.paint(L.line([(CX + 11, 56 + i * 4), (CX + 24, 58 + i * 4)], 0.6), hexc("#4a4132"), 0.5)
    L.paint(L.line([(CX + 9, 49), (CX + 17, 55)], 1.2), hexc("#7a6c50"))   # 挎带
    L.paint(L.rect(CX - 5, 39, CX + 5, 44), hexc("#3a2c22"), 0.14)           # 下颌胡茬
    return L.finish(), PIV


def trader():
    """黑市摊主：深棕皮大衣 + 便帽 + 毛领 + 拢手 + 腰包 + 嘴角叼烟，精明。"""
    L = Layer(FW, FH, 3)
    skin = "#c8ab90"
    _legs(L, "#332f28", "#1e1a14")
    _coat(L, 12.5, 90, "#4a3f33", 47)                              # 深棕皮大衣
    _arms(L, 12.5, "#4a3f33", skin, "clasp")
    _head(L, skin)
    L.paint(L.ellipse(CX, 24, 9, 4.6), hexc("#3a332a"))            # 便帽
    L.paint(L.rect(CX - 9, 24, CX + 9, 27.5, 2), hexc("#3a332a"))
    L.paint(L.ellipse(CX, 45, 8, 3.6), hexc("#6a5a44"))            # 毛领
    L.paint(L.rect(CX + 5, 58, CX + 15, 68, 1), hexc("#2e2620"))   # 腰包
    L.paint(L.rect(CX + 5, 58, CX + 15, 62), hexc("#3c3228"))
    L.paint(L.rect(CX + 9, 61, CX + 11, 63), hexc("#8a7a5a"))
    L.paint(L.line([(CX + 1.6, 37.5), (CX + 6, 38.5)], 1.0), hexc("#e6e2d8"))  # 嘴角叼烟
    L.paint(L.ellipse(CX + 6, 38.5, 0.9, 0.9), hexc("#c85a3a"))
    return L.finish(), PIV


# ---------------------------------------------------------------------------
# 战役伙伴（MATES）
# ---------------------------------------------------------------------------
def pavel():
    """帕维尔老爹（钳工）：深蓝工装 + 鸭舌帽 + 花白胡茬 + 胸前围裙 + 手持扳手。"""
    L = Layer(FW, FH, 3)
    skin = "#c0a186"
    _legs(L, "#33383f", "#23201c")
    _coat(L, 12.5, 90, "#4a5560", 53)                              # 深蓝工装
    _arms(L, 12.5, "#4a5560", skin)
    _head(L, skin)
    L.paint(L.ellipse(CX, 24, 9, 4.4), hexc("#3a4048"))            # 鸭舌帽
    L.paint(L.rect(CX - 9, 24, CX + 11, 27, 2), hexc("#2f353c"))   # 帽檐（前伸）
    L.paint(L.poly([(CX - 6, 48), (CX + 6, 48), (CX + 8, 84), (CX - 8, 84)]),
            hexc("#5c4a38"))                                       # 皮质工装围裙
    L.paint(L.rect(CX - 5, 39, CX + 5, 44), hexc("#b9b9b2"), 0.4)  # 花白胡茬
    # 右手扳手（钳工标志）
    L.paint(L.line([(CX + 13, 70), (CX + 19, 56)], 2.2), hexc("#8a8f96"))
    L.paint(L.arc(CX + 19, 54, 3.0, 3.0, 40, 320, 1.6), hexc("#9aa0a8"))
    return L.finish(), PIV


def ivan():
    """老轨伊万（列车长）：藏青制服 + 大檐帽 + 金扣 + 怀表链 + 手持红绿信号灯。"""
    L = Layer(FW, FH, 3)
    skin = "#c6a78c"
    _legs(L, "#262b33", "#1d1a16")
    _coat(L, 12.0, 90, "#2e3a4a", 61)                              # 藏青列车长制服
    _arms(L, 12.0, "#2e3a4a", skin)
    _head(L, skin)
    L.paint(L.ellipse(CX, 24, 9.4, 4.6), hexc("#232c38"))          # 大檐帽顶
    L.paint(L.rect(CX - 10, 24, CX + 10, 27, 2), hexc("#1a2230"))  # 大帽檐
    L.paint(L.rect(CX - 9, 23, CX + 9, 24.5), hexc("#8a7a3a"))     # 帽墙饰带
    L.paint(L.ellipse(CX, 25.5, 1.2, 1.2), hexc("#d8b84a"))        # 帽徽
    for k in range(3):                                             # 制服金扣
        L.paint(L.ellipse(CX + 2.2, 53 + k * 9, 1.1, 1.1), hexc("#c8a84a"))
    L.paint(L.line([(CX - 6, 50), (CX + 4, 62)], 0.8), hexc("#c8a84a"), 0.7)  # 怀表链
    # 手持信号灯（列车长标志，红 / 绿两点）
    L.paint(L.line([(CX - 13, 70), (CX - 15, 58)], 1.6), hexc("#3a3d42"))
    L.paint(L.rect(CX - 18, 52, CX - 12, 60, 1), hexc("#2a2d30"))
    L.paint(L.ellipse(CX - 15, 54.5, 1.4, 1.4), hexc("#c85a3a"))
    L.paint(L.ellipse(CX - 15, 58, 1.4, 1.4), hexc("#5ac86a"))
    return L.finish(), PIV


def ash():
    """灰烬（灰狼犬）：四足侧视、灰背白腹、立耳、翘尾。96×80，pivot (48,76)。"""
    W, H = 96, 80
    L = Layer(W, H, 3)
    back, belly, dark = "#6a6f76", "#b9bcc0", "#3a3d42"
    # 四腿（先画，身体盖在上）
    for lx in (34, 46, 60, 70):
        L.paint(L.rect(lx - 2, 52, lx + 2, 72, 1), L.tex(back, 0.08, 4, lx))
        L.paint(L.rect(lx - 2, 70, lx + 3, 73, 1), hexc(dark))      # 爪
    # 尾巴（后方向上翘）
    L.paint(L.line([(70, 46), (82, 36), (86, 30)], 4.0), L.tex(back, 0.08, 4, 9))
    L.paint(L.ellipse(86, 29, 3.0, 3.4), hexc(belly))               # 尾尖白
    # 身体（椭圆，背灰腹白）
    body = L.ellipse(50, 46, 26, 13)
    L.paint(body, L.tex(back, 0.10, 5, 3))
    L.paint(L.ellipse(50, 52, 22, 7), L.tex(belly, 0.08, 5, 5))     # 白腹
    L.shade(body, L.gy(34, 58, 1.1, 0.86))
    # 头（前伸，朝左）+ 立耳 + 吻部
    L.paint(L.ellipse(24, 38, 11, 9), L.tex(back, 0.10, 5, 7))      # 头
    for ex in (18, 28):                                             # 立耳（三角）
        L.paint(L.poly([(ex - 3, 32), (ex + 3, 32), (ex, 22)]), hexc(back))
        L.paint(L.poly([(ex - 1.6, 31), (ex + 1.6, 31), (ex, 25)]), hexc(dark))
    L.paint(L.poly([(16, 40), (6, 44), (16, 47)]), hexc(belly))     # 吻部（前伸）
    L.paint(L.ellipse(7, 44, 2.0, 1.8), hexc("#1a1c1f"))            # 鼻
    L.paint(L.ellipse(22, 37, 1.5, 1.7), hexc("#1a1c1f"))           # 眼
    L.paint(L.ellipse(22.4, 36.6, 0.5, 0.5), hexc("#e8e8e8"))       # 眼神光
    return L.finish(), (48, 76)


ALL = {
    "PRP_Anna_Stand": anna,
    "PRP_Leonov_Stand": leonov,
    "PRP_Gulya_Stand": gulya,
    "PRP_Survivor_Stand": survivor,
    "PRP_Trader_Stand": trader,
    "PRP_Pavel_Stand": pavel,
    "PRP_Ivan_Stand": ivan,
    "PRP_Ash_Stand": ash,
}


def main() -> None:
    from PIL import Image
    prev = os.path.join(os.environ.get("TEMP", "/tmp"), "npc_preview")
    os.makedirs(prev, exist_ok=True)
    tiles = []
    for name, fn in ALL.items():
        img, piv = fn()
        out = os.path.join(ART, "30_props", name + ".png")
        img.save(out)
        big = img.resize((img.width * 4, img.height * 4), Image.NEAREST)
        big.save(os.path.join(prev, name + ".png"))
        tiles.append(big)
        print(f"  {name:22s} {img.size[0]}x{img.size[1]} pivot={piv} -> {out}")
    h = max(t.height for t in tiles)
    sheet = Image.new("RGBA", (sum(t.width for t in tiles) + 40, h), (24, 26, 32, 255))
    x = 0
    for t in tiles:
        sheet.paste(t, (x, h - t.height), t)
        x += t.width + 20
    sheet.save(os.path.join(prev, "_all.png"))
    print("preview ->", os.path.join(prev, "_all.png"))


if __name__ == "__main__":
    main()
