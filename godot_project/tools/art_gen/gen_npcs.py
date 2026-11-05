"""剧情 NPC 专属立绘 — 疗养院：安娜（0419）/ 梁诺夫医生 / 古丽娅医师。

之前三位角色与黑市平民共用 PRP_Survivor_Stand（CHR_04 换色、抱胸姿势），
重要剧情人物没有辨识度。这里给每人一张独立精画立绘：正常站姿 + 各自的
配色 / 发型 / 道具，一眼能分清谁是谁：
  安娜    浅灰蓝薄棉袄 + 毛领 + 深棕长发 + 手腕旧皮带（她把自己捆在铁架床上的那两根）
  梁诺夫  脏白大褂 + 半秃花白 + 圆眼镜 + 颈挂听诊器（老眼科主任）
  古丽娅  白大褂 + 暗红头巾 + 臂抱病历夹（女流调医师）

引擎规格与 PRP_Survivor_Stand 完全一致：72×112、pivot 脚底中心 (36,108)。
NPC 站着不动，出静态立绘即可（不做 24 帧动画表）。
build_scene 的 SURVIVORS 钩子支持 (x, y, art) 三元组按人指定立绘。

单独预览：python gen_npcs.py  → 写 30_props 三张 + 打印路径。
正式注册进 manifest 走：python gen_assets.py --level sanitarium props --only PRP_Anna_Stand,...
"""
from __future__ import annotations

import os

from artlib import Layer, hexc

FW, FH, PIV = 72, 112, (36, 108)
CX = 36.0
HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.abspath(os.path.join(HERE, "..", "..", "art"))


# ---------------------------------------------------------------------------
# 共享人体（正面站姿，脚底 106；头 ellipse 中心 28、眼 27.5、下巴 37、肩 44）
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
    L.paint(L.rect(CX - 2.5, 36, CX + 2.5, 46, 1), hexc(skin))     # 脖子
    head = L.ellipse(CX, 28, 8, 9)
    L.paint(head, hexc(skin))
    L.shade(head, L.gx(CX - 8, CX + 8, 1.12, 0.82))
    for sx in (-1, 1):                                             # 眼
        L.paint(L.ellipse(CX + sx * 3, 27.5, 0.9, 1.1), hexc("#241d18"))
    L.paint(L.line([(CX, 29), (CX, 31.5)], 0.8), hexc("#000000"), 0.16)   # 鼻影
    L.paint(L.line([(CX - 1.6, 33.5), (CX + 1.6, 33.5)], 0.8), hexc("#5a3a32"), 0.55)  # 嘴
    if blush:                                                      # 退烧后的潮红
        for sx in (-1, 1):
            L.paint(L.ellipse(CX + sx * 4.4, 31, 2.2, 1.6), hexc(blush), 0.35)
    return head


# ---------------------------------------------------------------------------
# 三位角色
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
    L.paint(L.ellipse(CX, 21, 8.6, 5.2), hexc(hair))               # 发顶（不遮眼）
    L.paint(L.rect(CX - 8, 19, CX + 8, 23, 2.5), hexc(hair))       # 刘海
    for sx in (-1, 1):                                             # 两侧发片垂到肩
        L.paint(L.poly([(CX + sx * 8.4, 22), (CX + sx * 9.4, 41), (CX + sx * 6.4, 44),
                        (CX + sx * 6.6, 26)]), hexc(hair))
    # 手腕上的旧皮带（0419 把自己捆在铁架床栏杆上的那两根）
    L.paint(L.line([(CX - 4.5, 70.5), (CX + 4.5, 70.5)], 1.6), hexc("#6a4a2a"))
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
        L.paint(L.ellipse(CX + sx * 7.3, 29, 1.8, 4.4), hexc(hair))
    L.paint(L.arc(CX, 28, 8.0, 9.0, 20, 160, 2.2), hexc(hair))     # 后脑一圈
    for sx in (-1, 1):                                             # 圆眼镜
        L.paint(L.arc(CX + sx * 3.1, 27.5, 2.7, 2.7, 0, 360, 0.8), hexc("#26262a"))
    L.paint(L.line([(CX - 0.6, 27.5), (CX + 0.6, 27.5)], 0.8), hexc("#26262a"))
    # 颈挂听诊器
    L.paint(L.arc(CX, 46, 4.5, 6, 20, 160, 1.2), hexc("#2a2d30"))
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
    L.paint(L.ellipse(CX, 21, 9, 5.6), hexc(scarf))
    L.paint(L.rect(CX - 9, 20, CX + 9, 24.5, 2), hexc(scarf))
    L.paint(L.poly([(CX + 7, 26), (CX + 12.5, 32), (CX + 6.5, 33)]), hexc("#632f2c"))  # 脑后结
    # 臂抱病历夹
    L.paint(L.rect(CX + 1, 52, CX + 11, 68, 1), hexc("#7a5a34"))
    L.paint(L.rect(CX + 2, 53, CX + 10, 56), hexc("#d8cfb8"))      # 夹上的纸
    L.paint(L.rect(CX + 1, 52, CX + 11, 54), hexc("#5a4020"))      # 夹板
    L.paint(L.ellipse(CX + 3, 66, 2.4, 2.8), hexc(skin))           # 扶夹的手
    return L.finish(), PIV


ALL = {
    "PRP_Anna_Stand": anna,
    "PRP_Leonov_Stand": leonov,
    "PRP_Gulya_Stand": gulya,
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
    sheet = Image.new("RGBA", (sum(t.width for t in tiles) + 40, tiles[0].height), (24, 26, 32, 255))
    x = 0
    for t in tiles:
        sheet.paste(t, (x, 0), t)
        x += t.width + 20
    sheet.save(os.path.join(prev, "_all.png"))
    print("preview ->", os.path.join(prev, "_all.png"))


if __name__ == "__main__":
    main()
