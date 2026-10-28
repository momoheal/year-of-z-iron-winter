"""VFX 贴图（灯光形状、粒子、雾）与环境音循环（AMB_*）。

灯光贴图：RGB = 衰减，A = 1（黑色 = 不发光），这样无论引擎是否用 alpha 衰减结果都一致。
锥形灯：1024×512，光源顶点在 (0, 256)，引擎里用 offset=(512,0) 把顶点对到节点原点。
"""
from __future__ import annotations

import math
import wave
import numpy as np

from artlib import hexc, smooth, tile_noise, to_img, vnoise


def light_radial(n=512, power=2.0, core=0.0):
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(xs - n / 2 + 0.5, ys - n / 2 + 0.5) / (n / 2)
    f = np.clip(1 - r, 0, 1) ** power
    if core > 0:
        f = np.clip(f + core * np.clip(1 - r * 6, 0, 1) ** 2, 0, 1)
    f *= smooth(1.0, 0.92, r)
    return to_img(np.repeat(f[..., None], 3, -1))


def light_cone(half_deg, w=1024, h=512, edge=0.18, power=1.5, spill=0.12, seed=0, hard=False):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    dx, dy = xs + 0.5, ys + 0.5 - h / 2
    r = np.hypot(dx, dy) / w
    ang = np.abs(np.arctan2(dy, dx))
    half = math.radians(half_deg)
    soft = half * (0.06 if hard else edge)
    beam = smooth(half + soft, half - soft, ang)
    fall = np.clip(1 - r, 0, 1) ** power * smooth(0.0, 0.035, r)
    rings = 0.9 + 0.1 * vnoise(h, w, 30, 30, seed)
    glow = smooth(half * 1.9, half * 0.6, ang) * spill * np.clip(1 - r * 1.6, 0, 1) ** 2
    near = np.clip(1 - r * 9, 0, 1) ** 2 * 0.35
    f = np.clip(beam * fall * rings + glow + near, 0, 1)
    return to_img(np.repeat(f[..., None], 3, -1))


def soft_dot(n=16, color="#ffffff", power=1.6):
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(xs - n / 2 + 0.5, ys - n / 2 + 0.5) / (n / 2)
    a = np.clip(1 - r, 0, 1) ** power
    return to_img(np.broadcast_to(hexc(color), (n, n, 3)).copy(), a)


def steam_puff(n=64, seed=0):
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(xs - n / 2, ys - n / 2) / (n / 2)
    nz = vnoise(n, n, 9, 9, seed) * 0.6 + vnoise(n, n, 4, 4, seed + 1) * 0.4
    a = np.clip((1 - r) * 1.4 - 0.25 + (nz - 0.5) * 0.9, 0, 1) ** 1.3 * 0.85
    return to_img(np.broadcast_to(hexc("#eef4f8"), (n, n, 3)).copy(), a)


def fog_noise(n=512):
    a = tile_noise(n, 128, 501) * 0.55 + tile_noise(n, 64, 502) * 0.3 + tile_noise(n, 32, 503) * 0.15
    a = np.clip((a - a.min()) / (a.max() - a.min()), 0, 1)
    return to_img(np.repeat(a[..., None], 3, -1))


# ---------------------------------------------------------------------------
# 音频
# ---------------------------------------------------------------------------
SR = 22050


def _onepole(x, a):
    """一阶低通，a 可为标量或逐样本数组。"""
    a = np.broadcast_to(np.asarray(a, np.float64), x.shape).tolist()
    xs = x.tolist()
    y = [0.0] * len(xs)
    acc = 0.0
    for i, v in enumerate(xs):
        acc += a[i] * (v - acc)
        y[i] = acc
    return np.asarray(y)


def _loop_xfade(x, fade_s=1.0):
    n = int(fade_s * SR)
    head, tail = x[:n].copy(), x[-n:].copy()
    t = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * t + tail * (1 - t)
    return x


def _save_wav(path, x, gain=0.8):
    x = x / max(1e-6, np.max(np.abs(x))) * gain
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def amb_wind(path, dur=12.0, seed=1):
    r = np.random.default_rng(seed)
    n = int((dur + 1.0) * SR)
    t = np.arange(n) / SR
    white = r.standard_normal(n)
    gust = 0.55 + 0.45 * np.sin(t * 2 * np.pi / (dur + 1.0) * 2 + 0.7) * np.sin(t * 2 * np.pi / (dur + 1.0) * 3)
    cut = 260 + 520 * np.clip(gust, 0, 1)
    k = 1 - np.exp(-2 * np.pi * cut / SR)
    y = _onepole(white, k)
    y = _onepole(y, k)
    howl = np.sin(2 * np.pi * np.cumsum(180 + 60 * gust) / SR) * 0.08 * gust
    x = y * (0.35 + 0.65 * gust) + howl * np.abs(y).mean() * 6
    _save_wav(path, _loop_xfade(x), 0.7)


def amb_fire(path, dur=6.0, seed=2):
    r = np.random.default_rng(seed)
    n = int((dur + 0.5) * SR)
    roar = _onepole(r.standard_normal(n), 1 - math.exp(-2 * math.pi * 180 / SR)) * 0.6
    x = roar.copy()
    for _ in range(int(dur * 14)):
        i = r.integers(0, n - 2000)
        ln = r.integers(60, 600)
        env = np.exp(-np.arange(ln) / (ln * 0.18))
        x[i:i + ln] += r.standard_normal(ln) * env * r.uniform(0.3, 1.4)
    _save_wav(path, _loop_xfade(x, 0.5), 0.6)


def amb_steam(path, dur=4.0, seed=3):
    r = np.random.default_rng(seed)
    n = int((dur + 0.5) * SR)
    w = r.standard_normal(n)
    lo = _onepole(w, 1 - math.exp(-2 * math.pi * 1800 / SR))
    hiss = w - lo
    t = np.arange(n) / SR
    env = 0.7 + 0.3 * np.sin(t * 2 * np.pi / (dur + 0.5) * 3) ** 2
    _save_wav(path, _loop_xfade(hiss * env, 0.5), 0.45)


def amb_buzz(path, dur=2.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = sum(np.sin(2 * np.pi * 100 * k * t) / k for k in (1, 2, 3, 5)) * 0.5
    x *= 0.85 + 0.15 * np.sin(2 * np.pi * 0.5 * t)
    _save_wav(path, x, 0.25)
