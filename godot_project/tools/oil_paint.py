"""把 AI 出图（光滑数字插画 / 3D 渲染感）转成厚涂油画质感。

用于角色精灵表流水线：对每个切好的单元格单独处理，保证帧间笔触一致。

做法：
1. alpha 加权的 Kuwahara 滤波 —— 取局部方差最小的象限均值，把平滑渐变
   压成大块不透明色面，保留边缘，且不会把透明背景的颜色带进人物边缘。
2. 两遍不同半径叠加，形成"大笔触铺底 + 小笔触破边"的层次。
3. 降饱和 + 冷灰蓝偏移，贴合项目脏冷调色板。
4. 低频画布纹理求梯度做伪浮雕光照，模拟 impasto 颜料脊；叠少量胶片颗粒。

只用 numpy + PIL，无 cv2/scipy 依赖。
"""
from __future__ import annotations

import numpy as np
from PIL import Image


def _integral(a: np.ndarray) -> np.ndarray:
    """返回 (H+1, W+1, C) 积分图，I[i, j] = sum(a[0:i, 0:j])。"""
    p = np.pad(a, ((1, 0), (1, 0), (0, 0)), mode="constant")
    return p.cumsum(axis=0).cumsum(axis=1)


def _box(I: np.ndarray, y0, y1, x0, x1, H: int, W: int) -> np.ndarray:
    y0c = np.clip(y0, 0, H)
    y1c = np.clip(y1, 0, H)
    x0c = np.clip(x0, 0, W)
    x1c = np.clip(x1, 0, W)
    return I[y1c, x1c] - I[y0c, x1c] - I[y1c, x0c] + I[y0c, x0c]


def _kuwahara(rgb: np.ndarray, alpha: np.ndarray, radius: int) -> np.ndarray:
    """alpha 加权 Kuwahara。rgb: H,W,3 float32(0-255)，alpha: H,W,1 float32(0-1)。"""
    H, W = alpha.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W]
    r = radius
    a = alpha[..., 0]
    Ia = _integral(a[..., None])
    Irgb = _integral(rgb * alpha)
    Irgb2 = _integral(rgb * rgb * alpha)

    quadrants = [
        (yy - r, yy + 1, xx - r, xx + 1),        # 左上
        (yy - r, yy + 1, xx, xx + r + 1),        # 右上
        (yy, yy + r + 1, xx - r, xx + 1),        # 左下
        (yy, yy + r + 1, xx, xx + r + 1),        # 右下
    ]

    out = rgb.copy()
    best = np.full((H, W), np.inf, dtype=np.float32)
    for y0, y1, x0, x1 in quadrants:
        w = _box(Ia, y0, y1, x0, x1, H, W)[..., 0]
        w = np.maximum(w, 1e-4)
        s = _box(Irgb, y0, y1, x0, x1, H, W)
        s2 = _box(Irgb2, y0, y1, x0, x1, H, W)
        mean = s / w[..., None]
        var = np.maximum(s2 / w[..., None] - mean * mean, 0.0)
        score = var.mean(axis=2)
        take = score < best
        best = np.where(take, score, best)
        out = np.where(take[..., None], mean, out)
    return np.clip(out, 0, 255)


def _canvas_relief(H: int, W: int, seed: int) -> np.ndarray:
    """低频画布纹理 → 梯度 → 伪浮雕光照，模拟颜料堆积的明暗脊。"""
    rng = np.random.default_rng(seed)
    gh, gw = max(3, H // 9 + 2), max(3, W // 9 + 2)
    small = (rng.random((gh, gw)) * 255).astype(np.uint8)
    n = np.asarray(
        Image.fromarray(small).resize((W, H), Image.BICUBIC), dtype=np.float32
    ) / 255.0
    gx = n - np.roll(n, 1, axis=1)
    gy = n - np.roll(n, 1, axis=0)
    return (gx + gy) * 255.0 * 0.42


def _stroke_blur(rgb: np.ndarray, alpha: np.ndarray, length: int = 5) -> np.ndarray:
    """沿局部边缘切线方向做各向异性模糊，模拟画笔扫过的长笔触。

    亮度梯度的垂直方向即笔触走向；把 4 个方向的长条模糊按方向权重混合。
    """
    lum = rgb.mean(axis=2)
    gx = np.roll(lum, -1, axis=1) - np.roll(lum, 1, axis=1)
    gy = np.roll(lum, -1, axis=0) - np.roll(lum, 1, axis=0)
    # 切线 (-gy, gx)
    tx, ty = -gy, gx
    dirs = [(1, 0), (0, 1), (1, 1), (1, -1)]
    acc = np.zeros_like(rgb)
    wsum = np.zeros(lum.shape + (1,), dtype=np.float32)
    for dx, dy in dirs:
        n = (dx * dx + dy * dy) ** 0.5
        ux, uy = dx / n, dy / n
        w = np.abs(tx * ux + ty * uy)[..., None]
        buf = np.zeros_like(rgb)
        for k in range(-length // 2 + 1, length // 2 + 1):
            buf += np.roll(rgb, (int(dy * k), int(dx * k)), axis=(0, 1))
        acc += buf / max(1, length) * w
        wsum += w
    out = acc / np.maximum(wsum, 1e-4)
    return out


def _ink_edges(rgb: np.ndarray, strength: float) -> np.ndarray:
    """从亮度梯度提出松动的深色轮廓线，模拟厚涂里颜料挤压出的暗边。"""
    lum = rgb.mean(axis=2)
    gx = np.roll(lum, -1, axis=1) - np.roll(lum, 1, axis=1)
    gy = np.roll(lum, -1, axis=0) - np.roll(lum, 1, axis=0)
    g = np.sqrt(gx * gx + gy * gy)
    e = np.clip((g - 7.0) / 26.0, 0.0, 1.0)[..., None] * strength
    ink = np.array([13, 17, 23], dtype=np.float32)
    return rgb * (1.0 - e) + ink * e


def oilify(
    im: Image.Image,
    radius: int = 3,
    passes: tuple[int, ...] = (3, 2),
    blend: float = 0.55,
    stroke: float = 0.35,
    outline: float = 0.0,
    posterize: float = 0.0,
    saturation: float = 0.86,
    relief: float = 0.85,
    grain: float = 2.0,
    seed: int = 20261113,
) -> Image.Image:
    """输入 RGBA，输出 RGBA。alpha 保持不变，只重绘 RGB。

    blend 控制"笔触层"与原图的混合比例，保留造型细节不被糊掉。
    """
    src = np.asarray(im.convert("RGBA"), dtype=np.float32)
    orig = src[..., :3].copy()
    rgb = orig.copy()
    alpha = (src[..., 3:4] / 255.0).copy()

    for r in passes:
        rgb = _kuwahara(rgb, alpha, int(max(1, round(r * radius / 3))))
    rgb = orig * (1.0 - blend) + rgb * blend

    if stroke > 0:
        sb = _stroke_blur(orig, alpha, length=5)
        rgb = rgb * (1.0 - stroke) + (orig * 0.45 + sb * 0.55) * stroke

    if posterize > 0:
        q = np.round(rgb / 15.0) * 15.0
        rgb = rgb * (1.0 - posterize) + q * posterize
    if outline > 0:
        rgb = _ink_edges(rgb, outline)

    # 降饱和 + 冷灰蓝偏移
    gray = rgb.mean(axis=2, keepdims=True)
    rgb = gray + (rgb - gray) * saturation
    rgb = rgb + np.array([-2.5, 0.0, 3.0], dtype=np.float32)

    H, W = alpha.shape[:2]
    if relief > 0:
        rgb += _canvas_relief(H, W, seed)[..., None] * relief
    if grain > 0:
        rng = np.random.default_rng(seed + 7)
        rgb += rng.normal(0.0, grain, (H, W, 1)).astype(np.float32)

    rgb = np.clip(rgb, 0, 255).astype(np.uint8)
    out = np.concatenate([rgb, src[..., 3:4].astype(np.uint8)], axis=2)
    return Image.fromarray(out, "RGBA")


if __name__ == "__main__":
    import sys
    from pathlib import Path

    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    oilify(Image.open(src)).save(dst)
    print(f"oilify -> {dst}")
