"""artlib — 程序化手绘风资产的绘制底层（numpy + Pillow）。

约定（与《美术资源生成 Prompt 规格书》§3 一致）：
  * 1 逻辑米 = 64 px；地面沿 y 压缩 0.62（1 米地面 = 39.68 px）；立面/角色不压缩。
  * 所有精灵 pivot = 底部中心（脚底 / 落地点）。
  * 颜色按「阴天中性冷光」上色，夜色由引擎里的 CanvasModulate + 2D 灯光给出。

Layer 内部用预乘 alpha 的 float32 存储，在 SS 倍超采样分辨率上画，finish() 时 BOX 降采样抗锯齿。
"""
from __future__ import annotations

import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PPM = 64.0
SQ = 0.62
GY = PPM * SQ  # 1 米地面的像素高度


# ---------------------------------------------------------------------------
# 颜色 / 数学
# ---------------------------------------------------------------------------
def hexc(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def lerp(a, b, t):
    if isinstance(t, np.ndarray) and t.ndim == 2 and np.ndim(a) == 1:
        t = t[..., None]
    return a + (b - a) * t


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def norm01(a: np.ndarray, lo=1.0, hi=99.0) -> np.ndarray:
    p0, p1 = np.percentile(a, lo), np.percentile(a, hi)
    return np.clip((a - p0) / max(1e-6, p1 - p0), 0.0, 1.0)


def _resize_f(arr: np.ndarray, size, resample=Image.BICUBIC) -> np.ndarray:
    return np.asarray(Image.fromarray(arr.astype(np.float32), "F").resize(size, resample), np.float32)


# ---------------------------------------------------------------------------
# 噪声
# ---------------------------------------------------------------------------
def vnoise(h: int, w: int, cx: float, cy: float | None = None, seed: int = 0) -> np.ndarray:
    """平滑值噪声 [0,1]；cx/cy 为格子像素尺寸（各向异性 → 地面压缩）。"""
    cy = cx if cy is None else cy
    cx, cy = max(1.0, cx), max(1.0, cy)
    gh, gw = int(math.ceil(h / cy)) + 4, int(math.ceil(w / cx)) + 4
    g = np.random.default_rng(seed).random((gh, gw)).astype(np.float32)
    big = _resize_f(g, (int(gw * cx), int(gh * cy)))
    oy, ox = int(cy * 1.5), int(cx * 1.5)
    return np.clip(big[oy:oy + h, ox:ox + w], 0.0, 1.0)


def fbm(h, w, cx, cy=None, octaves=4, seed=0, gain=0.5) -> np.ndarray:
    cy = cx if cy is None else cy
    s = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for i in range(octaves):
        f = 2 ** i
        s += amp * vnoise(h, w, cx / f, cy / f, seed + i * 101)
        tot += amp
        amp *= gain
    return s / tot


def tile_noise(n: int, cell: int, seed: int = 0) -> np.ndarray:
    """可无缝平铺的值噪声（n 必须能被 cell 整除）。"""
    k = n // cell
    g = np.random.default_rng(seed).random((k, k)).astype(np.float32)
    g3 = np.tile(g, (3, 3))
    big = _resize_f(g3, (3 * n, 3 * n))
    return np.clip(big[n:2 * n, n:2 * n], 0.0, 1.0)


def blur(a: np.ndarray, r: float) -> np.ndarray:
    if r <= 0:
        return a
    im = Image.fromarray(np.clip(a * 255.0, 0, 255).astype(np.uint8), "L")
    return np.asarray(im.filter(ImageFilter.GaussianBlur(r)), np.float32) / 255.0


def blur_rgb(a: np.ndarray, r: float) -> np.ndarray:
    return np.stack([blur(a[..., i], r) for i in range(a.shape[2])], -1)


# ---------------------------------------------------------------------------
# Layer — 超采样绘制画布
# ---------------------------------------------------------------------------
class Layer:
    def __init__(self, w: int, h: int, ss: int = 3):
        self.w, self.h, self.ss = w, h, ss
        self.W, self.H = w * ss, h * ss
        self.p = np.zeros((self.H, self.W, 3), np.float32)  # 预乘 rgb
        self.a = np.zeros((self.H, self.W), np.float32)
        ys, xs = np.mgrid[0:self.H, 0:self.W].astype(np.float32)
        self.X = (xs + 0.5) / ss  # 1× 像素坐标
        self.Y = (ys + 0.5) / ss

    # ---- 遮罩 ----
    def _m(self):
        im = Image.new("L", (self.W, self.H), 0)
        return im, ImageDraw.Draw(im)

    def _s(self, pts):
        s = self.ss
        return [(x * s, y * s) for x, y in pts]

    def poly(self, pts) -> np.ndarray:
        im, d = self._m()
        d.polygon(self._s(pts), fill=255)
        return np.asarray(im, np.float32) / 255.0

    def rect(self, x0, y0, x1, y1, r: float = 0.0) -> np.ndarray:
        im, d = self._m()
        s = self.ss
        if r > 0:
            d.rounded_rectangle([x0 * s, y0 * s, x1 * s - 1, y1 * s - 1], radius=r * s, fill=255)
        else:
            d.rectangle([x0 * s, y0 * s, x1 * s - 1, y1 * s - 1], fill=255)
        return np.asarray(im, np.float32) / 255.0

    def ellipse(self, cx, cy, rx, ry) -> np.ndarray:
        im, d = self._m()
        s = self.ss
        d.ellipse([(cx - rx) * s, (cy - ry) * s, (cx + rx) * s, (cy + ry) * s], fill=255)
        return np.asarray(im, np.float32) / 255.0

    def line(self, pts, width: float, round_caps: bool = True) -> np.ndarray:
        im, d = self._m()
        s = self.ss
        sp = self._s(pts)
        d.line(sp, fill=255, width=max(1, int(round(width * s))), joint="curve")
        if round_caps:
            r = width * s / 2.0
            for x, y in (sp[0], sp[-1]):
                d.ellipse([x - r, y - r, x + r, y + r], fill=255)
        return np.asarray(im, np.float32) / 255.0

    def arc(self, cx, cy, rx, ry, a0, a1, width) -> np.ndarray:
        im, d = self._m()
        s = self.ss
        d.arc([(cx - rx) * s, (cy - ry) * s, (cx + rx) * s, (cy + ry) * s], a0, a1,
              fill=255, width=max(1, int(round(width * s))))
        return np.asarray(im, np.float32) / 255.0

    # ---- 上色 ----
    @staticmethod
    def _bb(m: np.ndarray):
        rows = np.flatnonzero(m.any(1))
        if rows.size == 0:
            return None
        cols = np.flatnonzero(m.any(0))
        return slice(rows[0], rows[-1] + 1), slice(cols[0], cols[-1] + 1)

    def paint(self, mask: np.ndarray, color, alpha: float | np.ndarray = 1.0) -> None:
        bb = self._bb(mask)
        if bb is None:
            return
        m = np.clip(mask[bb] * (alpha[bb] if isinstance(alpha, np.ndarray) else alpha), 0.0, 1.0)
        c = color[bb] if (isinstance(color, np.ndarray) and color.ndim == 3) else np.asarray(color, np.float32)
        p, a = self.p[bb], self.a[bb]
        p *= (1.0 - m[..., None])
        p += c * m[..., None]
        a *= (1.0 - m)
        a += m

    def shade(self, mask: np.ndarray, f) -> None:
        """在 mask 内把颜色乘以 f（标量或 HxW）。"""
        bb = self._bb(mask)
        if bb is None:
            return
        f = np.asarray(f, np.float32)
        ff = f[bb] if f.ndim == 2 else f
        k = 1.0 + (ff - 1.0) * mask[bb]
        self.p[bb] *= k[..., None]

    def tint(self, mask: np.ndarray, color, amt: float | np.ndarray = 1.0) -> None:
        """在已有像素上向 color 混合（不改变 alpha）。"""
        bb = self._bb(mask)
        if bb is None:
            return
        am = amt[bb] if isinstance(amt, np.ndarray) else amt
        m = np.clip(mask[bb] * am, 0.0, 1.0) * self.a[bb]
        c = np.asarray(color, np.float32)
        p = self.p[bb]
        p *= (1.0 - m[..., None])
        p += c * m[..., None]

    # ---- 梯度 / 纹理 ----
    def gx(self, x0, x1, v0, v1) -> np.ndarray:
        t = np.clip((self.X - x0) / max(1e-6, x1 - x0), 0, 1)
        return v0 + (v1 - v0) * t

    def gy(self, y0, y1, v0, v1) -> np.ndarray:
        t = np.clip((self.Y - y0) / max(1e-6, y1 - y0), 0, 1)
        return v0 + (v1 - v0) * t

    def noise(self, cell: float, seed: int = 0, cy: float | None = None, octaves: int = 3) -> np.ndarray:
        cy = cell if cy is None else cy
        return fbm(self.H, self.W, cell * self.ss, cy * self.ss, octaves, seed)

    def tex(self, base: str, amt: float = 0.08, cell: float = 6, seed: int = 0, cy=None) -> np.ndarray:
        n = self.noise(cell, seed, cy)
        return hexc(base)[None, None, :] * (1.0 + (n - 0.5)[..., None] * 2.0 * amt)

    def rim(self, mask: np.ndarray, dx: float, dy: float, color, strength: float = 0.5) -> None:
        """mask 向 (dx,dy) 方向的内缘高光/暗边。"""
        sx, sy = int(round(dx * self.ss)), int(round(dy * self.ss))
        sh = np.roll(np.roll(mask, sy, 0), sx, 1)
        edge = np.clip(mask - sh, 0.0, 1.0)
        self.paint(edge, hexc(color) if isinstance(color, str) else color, strength)

    # ---- 雪 / 冰 / 锈 ----
    def snow_cap(self, x0, x1, y, thick, seed=0, droop=0.35, under=None) -> np.ndarray:
        """沿顶边 y 堆一条雪；返回雪的 mask。under: 只在这个 mask 附近堆（可选）。"""
        n1 = vnoise(1, self.W, max(2.0, 16 * self.ss), 1, seed)[0]
        n2 = vnoise(1, self.W, max(2.0, 5 * self.ss), 1, seed + 7)[0]
        n3 = vnoise(1, self.W, max(2.0, 2.5 * self.ss), 1, seed + 11)[0]
        xs = self.X[0]
        span = max(1e-6, x1 - x0)
        u = np.clip((xs - x0) / span, 0, 1)
        edge = np.clip(np.minimum(u, 1 - u) * span / max(2.0, min(thick, 14.0) * 1.2), 0, 1) ** 0.6
        lump = min(thick * 0.35, 5.0)
        top = y - thick * 0.8 - lump * (n1 - 0.35) - lump * 0.4 * (n3 - 0.5)
        top = top + (1 - edge) * thick * 0.8          # 两端圆角收口
        bot = y + min(thick * 0.2, 2.0) + min(thick * droop, 7.0) * n2 ** 2
        inx = (xs >= x0) & (xs <= x1)
        m = ((self.Y >= top[None, :]) & (self.Y <= bot[None, :]) & inx[None, :]).astype(np.float32)
        if under is not None:
            m *= np.clip(blur(under, 2 * self.ss) * 3.0, 0, 1)
        g = np.clip((self.Y - top[None, :]) / np.maximum(1e-3, (bot - top))[None, :], 0, 1)
        col = lerp(hexc("#e9eff5"), hexc("#a9bacb"), 0.25 * g + 0.75 * smooth(0.55, 1.0, g))
        col = col * (1.0 - 0.06 * self.noise(6, seed + 5))[..., None]
        sp = (self.noise(1.2, seed + 3) > 0.74).astype(np.float32) * 0.35
        col = col + sp[..., None] * 0.15
        self.paint(m, col)
        return m

    def icicles(self, x0, x1, y, max_len, count, seed=0, width=2.2) -> None:
        r = np.random.default_rng(seed)
        for _ in range(count):
            x = r.uniform(x0, x1)
            ln = max_len * (0.25 + 0.75 * r.random() ** 2)
            wd = width * (0.6 + 0.6 * r.random())
            m = self.poly([(x - wd, y), (x + wd, y), (x + 0.3, y + ln)])
            self.paint(m, hexc("#c6d8e6"), 0.92)
            self.paint(self.poly([(x - wd * 0.5, y), (x - wd * 0.1, y), (x, y + ln * 0.8)]),
                       hexc("#f4f9fc"), 0.7)

    def rust_streaks(self, mask, seed=0, amt=0.6, color="#6a4a2a", cell=(1.6, 14)) -> None:
        n = fbm(self.H, self.W, cell[0] * self.ss, cell[1] * self.ss, 3, seed)
        k = smooth(0.58, 0.8, n) * mask
        self.tint(k, hexc(color), amt)

    def grime(self, mask, seed=0, amt=0.25, cell=5) -> None:
        n = self.noise(cell, seed)
        self.shade(mask, 1.0 - amt * smooth(0.45, 0.85, n))

    # ---- 输出 ----
    def finish(self, outline: str | None = "#07090c", outline_a: float = 0.85) -> Image.Image:
        w, h = self.w, self.h
        pr = [_resize_f(self.p[..., i], (w, h), Image.BOX) for i in range(3)]
        a = _resize_f(self.a, (w, h), Image.BOX)
        rgb = np.stack(pr, -1) / np.maximum(a, 1e-5)[..., None]
        rgb = np.clip(rgb, 0, 1)
        if outline:
            ai = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8), "L")
            dil = np.asarray(ai.filter(ImageFilter.MaxFilter(3)), np.float32) / 255.0
            o = np.clip(dil - a, 0, 1) * outline_a
            oc = hexc(outline)
            na = a + o * (1 - a)
            rgb = (rgb * a[..., None] + oc * (o * (1 - a))[..., None]) / np.maximum(na, 1e-5)[..., None]
            a = na
        out = np.dstack([np.clip(rgb, 0, 1), np.clip(a, 0, 1)])
        return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")


def to_img(rgb: np.ndarray, alpha: np.ndarray | None = None) -> Image.Image:
    if alpha is None:
        return Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
    out = np.dstack([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)])
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")


def obox(L: Layer, x, base, w, d, h, top_col, front_col, seed=0, top_amt=0.06, front_amt=0.07,
         snow=0.0):
    """斜俯视盒子：顶面(深 d，已压缩) + 正立面(高 h)。返回 (top_mask, front_mask)。"""
    front = L.rect(x, base - h, x + w, base)
    top = L.rect(x, base - h - d, x + w, base - h)
    L.paint(top, L.tex(top_col, top_amt, 5, seed))
    L.paint(front, L.tex(front_col, front_amt, 5, seed + 1))
    L.shade(front, L.gy(base - h, base, 1.04, 0.82))
    L.shade(top, L.gy(base - h - d, base - h, 1.06, 0.96))
    L.paint(L.rect(x, base - h - 0.6, x + w, base - h + 0.8), hexc(top_col) * 1.18, 0.6)
    if snow > 0:
        # 雪盖住整个顶面（厚度 ∝ snow），前沿略微垂落到立面上
        L.snow_cap(x - 1, x + w + 1, base - h + 2, (d + 3) / 0.8 * snow, seed + 9, droop=0.25)
    return top, front
