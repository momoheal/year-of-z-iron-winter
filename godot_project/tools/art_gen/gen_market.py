"""黑市 / 幸存者立绘（PRP_*_Stand）。

黑区需要「人」，但不是敌人：市场摊主和幸存者都站着不动，所以不做 24 帧动画表，
直接出一个静态立绘当道具用（pivot = 脚底中心，和角色表一致）。

做法：拿 CHR_04 回退半人的底（褪色棉袄的平民轮廓，行序 S/E/N），**只给衣服换色**
（按 HSV 色相筛出橄榄绿的棉袄，皮肤 / 头发不动，否则脸会变绿），再手画辨识记号：
毛线帽、白袖标（白区居民）/ 兜帽、红袖标、手提马灯（黑市摊主）。
"""
from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.abspath(os.path.join(HERE, "..", "..", "art"))
SHEET = os.path.join(ART, "10_characters", "CHR_04_HalfHuman", "CHR_04_HalfHuman_Sheet.png")
FW, FH, PIV = 72, 112, (36, 108)


def _frame(row: int, col: int) -> Image.Image:
    sheet = Image.open(SHEET).convert("RGBA")
    return sheet.crop((col * FW, row * FH, col * FW + FW, row * FH + FH))


def _recolor_cloth(img: Image.Image, hue: float, sat: float, val: float,
                   tint, tint_a: float, h_lo: int = 22, h_hi: int = 72) -> Image.Image:
    """只动「衣服」：色相落在橄榄绿区间的像素才换色，皮肤 / 头发原样保留。"""
    a = np.asarray(img, np.float32)
    rgb, alpha = a[..., :3], a[..., 3:]
    hsv = np.asarray(Image.fromarray(rgb.astype(np.uint8), "RGB").convert("HSV"), np.float32)
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    cloth = (h >= h_lo) & (h <= h_hi) & (s > 26)
    h = np.where(cloth, (h + hue) % 256.0, h)
    s = np.where(cloth, np.clip(s * sat, 0, 255), s)
    v = np.where(cloth, np.clip(v * val, 0, 255), v)
    out = np.asarray(Image.fromarray(np.dstack([h, s, v]).astype(np.uint8), "HSV").convert("RGB"),
                     np.float32)
    t = np.array(tint, np.float32)[None, None, :]
    mix = np.where(cloth[..., None], tint_a, 0.0)
    out = out * (1.0 - mix) + t * mix
    return Image.fromarray(np.dstack([np.clip(out, 0, 255), alpha]).astype(np.uint8), "RGBA")


def _behind(img: Image.Image, draw_fn) -> Image.Image:
    """把配件画在人物**后面**（兜帽这类包住轮廓的东西）。"""
    back = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(back))
    return Image.alpha_composite(back, img)


def _glow(img: Image.Image, xy, r: int, col=(255, 196, 120), a: int = 100) -> Image.Image:
    """马灯柔光斑（只是画上去的光，不参与碰撞；引擎里另有 PointLight2D）。"""
    g = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    for k in range(6, 0, -1):
        rr = int(r * k / 6)
        d.ellipse([xy[0] - rr, xy[1] - rr, xy[0] + rr, xy[1] + rr],
                  fill=(*col, int(a * (1.0 - k / 7.0))))
    return Image.alpha_composite(img, g.filter(ImageFilter.GaussianBlur(3)))


def survivor() -> tuple[Image.Image, tuple[int, int]]:
    """白区居民：灰褐棉袄 + 白袖标扎在抱胸的前臂上（进红区会被查的就是这个）。"""
    img = _recolor_cloth(_frame(0, 0), hue=-14, sat=0.40, val=1.12,
                         tint=(162, 152, 134), tint_a=0.30)
    d = ImageDraw.Draw(img)
    # 白袖标：前臂（抱胸姿势里唯一露出来的一段袖子）
    d.polygon([(37, 45), (47, 45), (47, 53), (37, 53)], fill=(224, 219, 203, 255))
    d.line([37, 45, 47, 45], fill=(150, 146, 130, 255))
    d.line([37, 53, 47, 53], fill=(150, 146, 130, 255))
    d.line([42, 45, 42, 53], fill=(170, 166, 150, 255))
    return img, PIV


def trader() -> tuple[Image.Image, tuple[int, int]]:
    """黑市摊主：墨绿大衣 + 红袖标 + 手提马灯（侧身，像在守摊子）。"""
    img = _recolor_cloth(_frame(1, 0), hue=10, sat=0.85, val=0.76,
                         tint=(46, 54, 46), tint_a=0.34)
    d = ImageDraw.Draw(img)
    # 红袖标：近侧前臂
    d.polygon([(33, 44), (41, 43), (41, 51), (33, 52)], fill=(148, 30, 22, 255))
    d.line([33, 44, 41, 43], fill=(96, 18, 14, 255))
    d.line([33, 52, 41, 51], fill=(96, 18, 14, 255))
    # 马灯：挂在手里，垂到膝盖上方（引擎里这盏灯另外配 PointLight2D）
    d.line([43, 50, 47, 50], fill=(28, 30, 30, 255), width=2)
    d.rectangle([42, 52, 52, 70], fill=(32, 34, 36, 255), outline=(10, 12, 12, 255))
    d.rectangle([44, 55, 50, 67], fill=(255, 208, 136, 255))
    d.rectangle([44, 62, 50, 67], fill=(255, 152, 62, 255))
    d.line([47, 54, 47, 67], fill=(255, 240, 200, 255))
    img = _glow(img, (47, 61), 20)
    return img, PIV



def stall() -> tuple[Image.Image, tuple[int, int]]:
    """黑市摊位：一张拼板桌 + 两只弹药箱 + 一根挂马灯的杆子。

    桌面高度按坐姿视线画（≈0.8 m），桌上摆罐头和弹盒；杆子后面挂一盏灯，
    引擎里再加 PointLight2D —— 黑区里这盏灯就是「这里有人」的信号。
    """
    from artlib import Layer, hexc, smooth

    w, h = 118, 96
    L = Layer(w, h, 3)
    base = 88
    # 桌腿
    for lx in (14, 88):
        L.paint(L.rect(lx, base - 40, lx + 7, base - 2), L.tex("#4a3b2a", 0.12, 3, lx))
        L.shade(L.rect(lx, base - 40, lx + 7, base - 2), 0.9)
    # 桌面（拼板 + 前沿）
    top = L.rect(8, base - 50, 104, base - 38)
    L.paint(top, L.tex("#6b563c", 0.14, 3, 7, cy=2))
    for k in range(1, 5):
        x = 8 + k * 19
        L.paint(L.rect(x, base - 50, x + 1.4, base - 38), hexc("#2c2318"), 0.9)
    L.paint(L.rect(8, base - 38, 104, base - 34), hexc("#3a2e20"))
    # 桌上的货：两只弹盒 + 一罐罐头
    for (bx, bw, bh) in ((22, 26, 14), (54, 20, 11)):
        box = L.rect(bx, base - 50 - bh, bx + bw, base - 50)
        L.paint(box, L.tex("#4a5240", 0.12, 3, bx))
        L.shade(box, 0.86 + 0.20 * smooth(base - 50 - bh, base - 50, L.Y))
        L.paint(L.rect(bx, base - 50 - bh, bx + bw, base - 50 - bh + 3), hexc("#5c6650"))
        L.paint(L.rect(bx + 4, base - 50 - bh + 5, bx + bw - 4, base - 50 - bh + 7), hexc("#8c7139"))
    L.paint(L.ellipse(86, base - 56, 7, 8), L.tex("#8a5a34", 0.1, 3, 5))
    L.paint(L.ellipse(86, base - 60, 7, 4), hexc("#c8a257"))
    # 挂灯的杆子 + 马灯
    L.paint(L.rect(102, base - 86, 106, base - 4), L.tex("#3a3f42", 0.1, 3, 99))
    L.paint(L.rect(96, base - 86, 108, base - 83), hexc("#3a3f42"))
    L.paint(L.line([(100, base - 83), (100, base - 74)], 2), hexc("#22262a"))
    L.paint(L.rect(93, base - 74, 107, base - 54), hexc("#2a2e30"))
    L.paint(L.rect(95, base - 71, 105, base - 57), hexc("#ffd08a"))
    L.paint(L.rect(95, base - 62, 105, base - 57), hexc("#ff9840"))
    # 雪
    L.snow_cap(6, 106, base - 50, 7, 33, droop=0.25)
    L.snow_cap(10, 102, base - 1, 9, 34, droop=0.0)
    return L.finish(), (w / 2, base)


ALL = {
    "PRP_Survivor_Stand": survivor,
    "PRP_Trader_Stand": trader,
    "PRP_Market_Stall": stall,
}


def main() -> None:
    for name, fn in ALL.items():
        img, piv = fn()
        out = os.path.join(ART, "30_props", name + ".png")
        img.save(out)
        print(f"  {name:24s} {img.size[0]}x{img.size[1]}  pivot={piv}  -> {out}")
        img.resize((img.width * 3, img.height * 3), Image.NEAREST).save(f"/tmp/{name}.png")


if __name__ == "__main__":
    main()
