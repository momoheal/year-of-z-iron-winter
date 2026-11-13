"""VFX 贴图（灯光形状、粒子、雾）与环境音循环（AMB_*）。

灯光贴图：RGB = 衰减，A = 1（黑色 = 不发光），这样无论引擎是否用 alpha 衰减结果都一致。
锥形灯：1024×512，光源顶点在 (0, 256)，引擎里用 offset=(512,0) 把顶点对到节点原点。
"""
from __future__ import annotations

import math
import wave
import numpy as np

from artlib import fbm, hexc, smooth, tile_noise, to_img, vnoise


def light_radial(n=512, power=2.0, core=0.0):
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(xs - n / 2 + 0.5, ys - n / 2 + 0.5) / (n / 2)
    f = np.clip(1 - r, 0, 1) ** power
    if core > 0:
        f = np.clip(f + core * np.clip(1 - r * 6, 0, 1) ** 2, 0, 1)
    f *= smooth(1.0, 0.92, r)
    return to_img(np.repeat(f[..., None], 3, -1))


def _edge_falloff(w, h, fx=48, fy=80):
    """四周 smoothstep 羽化到 0 的乘性 mask，返回 (h, w) 数组。

    为什么需要：±30°/±22.5° 的锥角在 1024×512 画布里，光束在到达右边缘之前
    就先撞到上下边缘（半宽 512·tan30° ≈ 295 px > 半高 256 px），顶点又贴在左边缘，
    于是上/下/左三条边的亮度不是 0。PointLight2D 用整张矩形贴图参与光照，
    非零边缘就会在世界里投出带硬边的长方形光带（截图里横贯全屏的灰白带子）。
    让边缘严格渐变到 0，矩形边界就看不见了。
    """
    xs = np.arange(w, dtype=np.float32) + 0.5
    ys = np.arange(h, dtype=np.float32) + 0.5
    mx = np.clip(np.minimum(xs, w - xs) / fx, 0, 1)
    my = np.clip(np.minimum(ys, h - ys) / fy, 0, 1)
    mx = mx * mx * (3 - 2 * mx)          # smoothstep
    my = my * my * (3 - 2 * my)
    return mx[None, :] * my[:, None]


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
    f *= _edge_falloff(w, h)
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
# 地面贴花（Decal）—— 夜间场景里可以一层层叠上去的痕迹
#
# 全部按**正俯视 1:1** 出图，**不做 0.62 预压缩**。落位时由
# NightExplore._ground_transform() 施加 diag(1, SQ)·R(θ)，SQ = 0.62。
# 这里要是先压扁了，运行时会被压第二遍 —— 脚印会缩成一条线。
# 也因为这个原因，贴花可以任意旋转（矩阵里已经含压缩），
# 不必像道具那样预烘 8 个方向。
#
# 视觉基调 -30°C：
#   · 压实的雪是被踩**暗**的，边缘反而被挤得发**亮**（所以脚印是暗心 + 亮唇）；
#   · 血很快凝住，所以血泊是发暗的紫褐（比鲜血 #4a1416 更暗更紫），
#     外圈结一圈霜白细边 —— 那是"冻住了"的视觉信号。
# ---------------------------------------------------------------------------
DECAL_BLOOD = "#3a0e12"        # 冻血主色
DECAL_BLOOD_DEEP = "#240709"   # 凝住的血块
DECAL_FROST = "#c3d2e2"        # 霜白
DECAL_SNOW_LIT = "#e3ebf5"     # 被挤起来 / 翻出来的亮雪
DECAL_PRESSED = "#33424f"      # 被踩实的暗雪


def _grid(w, h):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    return xs, ys


def _radial(xs, ys, cx, cy, rx, ry):
    """归一化椭圆半径：正好在边界上是 1.0。"""
    return np.hypot((xs - cx) / max(rx, 1e-3), (ys - cy) / max(ry, 1e-3))


def _rect_field(xs, ys, cx, cy, hw, hh, p=3.0):
    """超椭圆场：边界是 1.0。p 越大越接近圆角矩形 —— 鞋底不能用纯椭圆，
    椭圆怎么调都是一根胶囊，看不出"前掌 + 后跟"两块。

    hw/hh 允许是标量或与画面同形的数组（左右脚的内外侧不对称就是这么传进来的），
    所以这里只能用 np.maximum，不能用内置 max。
    """
    return (np.abs((xs - cx) / np.maximum(hw, 1e-3)) ** p
            + np.abs((ys - cy) / np.maximum(hh, 1e-3)) ** p) ** (1.0 / p)


def _mix(rgb, col, t):
    """把 rgb 按权重 t (h,w) 往 col 混。

    不用 artlib.lerp：它只在第一个参数是一维时才展开 t 的维度，
    rgb 已经是 (h,w,3) 的时候会形状对不上。
    """
    return rgb + (hexc(col) - rgb) * np.asarray(t, np.float32)[..., None]


def decal_footprint(kind="boot_l", w=32, h=32, seed=1):
    """靴印 / 爪印（正俯视 32×32，局部 **+X = 前进方向**）。

    朝向约定：运行时 _ground_transform(θ) 把局部 +X 转到 facing，
    所以鞋底的长轴必须沿 **X**。画成"竖着"的鞋印会被贴成垂直于行走方向 ——
    这一版就是踩了这个坑之后重画的。

    形状上，32px 里面用椭圆拼鞋底怎么调都是胶囊或葫芦。改成两块**圆角方形**：
    前掌（长 0.35、宽 0.30）＋ 一个明显更小的后跟（0.19 × 0.23），中间一道细桥。
    靴子的足弓本来就不着地，这个"断开"是对的，也正是它让鞋印一眼能认出来。
    """
    xs, ys = _grid(w, h)
    nz = vnoise(h, w, 6, 6, seed) - 0.5

    if kind == "paw":
        # 掌垫在后（x 小），四趾在前（x 大）—— 爪印的趾头是朝着行进方向的
        r = _rect_field(xs, ys, w * 0.335, h * 0.50, w * 0.185, h * 0.270, 2.2)
        for tx, ty, rx, ry in ((0.60, 0.24, 0.085, 0.105), (0.68, 0.40, 0.095, 0.115),
                               (0.68, 0.60, 0.095, 0.115), (0.60, 0.76, 0.085, 0.105)):
            r = r - 0.0
            r = np.minimum(r, _rect_field(xs, ys, w * tx, h * ty, w * rx, h * ry, 2.0))
        arch = smooth(1.00, 0.66, r + nz * 0.10)
        lip = smooth(1.24, 1.00, r + nz * 0.10) * (1.0 - arch) * 0.42
    else:
        # 内外侧不对称：内侧（足弓那侧）收窄 —— 正俯视下分左右就靠这一点
        med = -1.0 if kind == "boot_l" else 1.0
        dy = (ys - h * 0.5) * med
        side = np.where(dy > 0.0, 0.84, 1.0)
        fore = _rect_field(xs, ys, w * 0.335, h * 0.50, w * 0.175, h * 0.150 * side, 3.2)
        heel = _rect_field(xs, ys, w * 0.720, h * 0.50, w * 0.108, h * 0.134 * side, 2.8)
        bridge = _rect_field(xs, ys, w * 0.545, h * 0.50, w * 0.085, h * 0.084, 2.0)
        r = np.minimum(fore, heel)
        # 防滑纹垂直于长轴 → 沿 X 排布；4~5 道就够，再多就成条形码
        tread = 0.80 + 0.20 * np.clip(np.sin(xs / w * np.pi * 9.0), 0.0, 1.0) ** 0.5
        body = smooth(1.04, 0.82, r + nz * 0.09)
        neck = smooth(1.00, 0.60, bridge + nz * 0.09) * 0.32
        arch = np.maximum(body, neck) * tread
        lip = smooth(1.16, 1.00, r + nz * 0.09) * (1.0 - body) * 0.32

    a = np.clip(arch * 0.90 + lip, 0.0, 1.0)
    rgb = _mix(np.broadcast_to(hexc(DECAL_SNOW_LIT), (h, w, 3)).astype(np.float32),
               DECAL_PRESSED, np.clip(arch, 0.0, 1.0))
    return to_img(rgb, a)


def decal_bullet_hole(kind="snow", w=28, h=28, seed=3):
    """弹孔，三种被击材质。

    第一版把喷溅画成了放射状长光条，放大看是颗星星。真实弹着点是
    **块状**的：雪被一小撮一小撮铲起来、金属沿孔缘撕开一圈、木头崩出短刺。
    所以这里全部换成"阈值噪声切块 + 限制在 1~2.4 倍孔半径"。
    """
    xs, ys = _grid(w, h)
    cx, cy = w * 0.5, h * 0.5
    nz = vnoise(h, w, 4, 4, seed) - 0.5
    nz2 = vnoise(h, w, 3, 3, seed + 7) - 0.5
    ang = np.arctan2(ys - cy, xs - cx)
    rr = np.hypot(xs - cx, ys - cy) / (min(w, h) * 0.5)

    if kind == "metal":
        core_r, rim, dark = 0.34, "#8b98a8", "#05070a"
    elif kind == "wood":
        core_r, rim, dark = 0.28, "#8f7245", "#1a110b"
    else:
        core_r, rim, dark = 0.32, DECAL_SNOW_LIT, "#10151a"

    core = smooth(core_r * 1.45, core_r * 0.50, rr + nz * 0.14)

    if kind == "snow":
        # 细碎的雪粒：频率要高、阈值要紧，否则会切成一块块白纸片
        chunk = np.clip((vnoise(h, w, 1.5, 1.5, seed + 5) - 0.60) * 3.2, 0.0, 1.0)
        # 半径一律用 core_r 的倍数：rr 是以「短边一半」归一化的，
        # 直接写 2.45 会变成铺满整张图的雪花点。
        eject = smooth(core_r * 2.6, core_r * 1.05, rr) * chunk * (1.0 - core)
    elif kind == "metal":
        jag = 1.0 + 0.35 * np.clip(np.cos(ang * 6.0 + nz2 * 6.0), 0.0, 1.0)
        eject = smooth(core_r * 2.1 * jag, core_r * 0.95, rr) * (1.0 - core)
    else:
        # 木头：崩的是短木刺，不是光条 —— 压低指数让尖角变钝，长度收到 1.9 倍孔半径
        spike = np.clip(np.cos(ang * 5.0 + nz2 * 4.0), 0.0, 1.0) ** 0.9
        eject = smooth(core_r * 1.8, core_r * 0.90, rr) * spike * (1.0 - core)

    # 外围烟痕：金属弹孔全靠这一圈才在浅色底上读得出来
    soot_amt = 0.55 if kind == "metal" else 0.30
    soot = smooth(core_r * 4.2, core_r * 1.1, rr) * (1.0 - core) * soot_amt
    # 碎屑只给雪地：木头和金属的散点是方形噪点，放大像彩色马赛克
    speck = (vnoise(h, w, 1.6, 1.6, seed + 13) > 0.90) * smooth(core_r * 6.5, core_r * 1.8, rr)
    if kind != "snow":
        speck = np.zeros_like(speck)

    a = np.clip(core * 0.95 + eject * 0.85 + soot + speck * 0.50, 0.0, 1.0)
    rgb = _mix(np.broadcast_to(hexc(rim), (h, w, 3)).astype(np.float32), dark, core)
    rgb = _mix(rgb, rim, np.clip(eject + speck, 0.0, 1.0))
    return to_img(rgb, a)


def decal_blood_pool(w=160, h=104, seed=5):
    """冻结的血泊：不规则暗红主体 + 中心凝块 + 外圈霜白细边。

    外圈那一道霜白是"冻住了"的唯一视觉信号，第一版画得太淡，
    在雪地上看不出冻结感，所以把 frost 的 alpha 提到 0.58、颜色也提亮。
    """
    xs, ys = _grid(w, h)
    cx, cy = w * 0.5, h * 0.5
    wob = (fbm(h, w, w * 0.20, h * 0.20, 3, seed) - 0.5) * 0.62
    wob += (vnoise(h, w, w * 0.075, h * 0.075, seed + 3) - 0.5) * 0.26
    rr = _radial(xs, ys, cx, cy, w * 0.41, h * 0.39) + wob

    body = smooth(1.04, 0.88, rr)
    deep = smooth(0.80, 0.26, rr)
    frost = smooth(1.30, 1.00, rr) * (1.0 - body)
    clot = fbm(h, w, w * 0.10, h * 0.10, 3, seed + 11)          # 凝住后的斑驳
    spots = (fbm(h, w, w * 0.06, h * 0.06, 2, seed + 23) > 0.62) * smooth(0.85, 0.20, rr)

    a = np.clip(body * (0.82 + 0.16 * clot) + frost * 0.58, 0.0, 1.0)
    rgb = np.broadcast_to(hexc(DECAL_BLOOD), (h, w, 3)).astype(np.float32)
    rgb = _mix(rgb, DECAL_BLOOD_DEEP, np.clip(deep * 0.80 + spots * 0.55, 0.0, 1.0))
    rgb = _mix(rgb, DECAL_FROST, np.clip(frost, 0.0, 1.0))
    return to_img(rgb, a)


def decal_blood_trail(w=64, h=40, seed=9):
    """拖行血痕：沿 +X 拉长，头部厚、尾部收干，可首尾相接连续铺。

    第一版是个规整的锥形，看着像漏斗。这里把宽度曲线交给噪声去啃，
    再甩出去几个小血点，才有"被拖着走"的意思。
    """
    xs, ys = _grid(w, h)
    t = np.clip(xs / max(w - 1.0, 1.0), 0.0, 1.0)              # 0 = 头，1 = 尾
    nz = vnoise(h, w, 9, 5, seed) - 0.5
    nz2 = vnoise(h, w, 4, 3, seed + 4) - 0.5

    # 一串沿 X 叠着的血块，越往后越小、越淡；中轴左右偏移由噪声给，
    # 边缘再被噪声啃一遍 —— 这样才像拖出来的，而不是浇出来的一个锥形。
    body = np.zeros((h, w), np.float32)
    axis = np.zeros((h, w), np.float32)
    for k in range(6):
        u = 0.10 + 0.16 * k
        sx = w * u
        sy = h * 0.5 + (vnoise(1, 1, 1, 1, seed + k * 3)[0, 0] - 0.5) * h * 0.22
        rx = max(w * (0.20 - 0.026 * k), 1.5)
        ry = max(h * (0.28 - 0.040 * k), 1.5)
        dd = _radial(xs, ys, sx, sy, rx, ry) + nz * 0.55
        body = np.maximum(body, smooth(1.05, 0.68, dd))
        axis = np.maximum(axis, smooth(1.9, 0.5, dd))

    drop = (vnoise(h, w, 2.2, 2.2, seed + 8) > 0.86) * np.clip(1.6 - axis, 0.0, 1.0) * 0.8
    frost = np.clip(axis - body, 0.0, 1.0) * (1.0 - body) * 0.5

    a = np.clip(body * 0.94 + drop * 0.50 + frost * 0.22, 0.0, 1.0)
    rgb = np.broadcast_to(hexc(DECAL_BLOOD), (h, w, 3)).astype(np.float32)
    rgb = _mix(rgb, DECAL_FROST, np.clip(frost, 0.0, 1.0) * 0.38)
    return to_img(rgb, a)


# 贴花注册表：键 = 文件名主干，值 = 无参工厂（返回 PIL Image）。
# gen_assets.build_decals() 遍历它落盘并写 manifest，pivot 统一取画面中心。
DECALS = {
    "VFX_Decal_Footprint_Boot_L": lambda: decal_footprint("boot_l", 32, 32, 11),
    "VFX_Decal_Footprint_Boot_R": lambda: decal_footprint("boot_r", 32, 32, 11),
    "VFX_Decal_Footprint_Paw": lambda: decal_footprint("paw", 32, 32, 23),
    "VFX_Decal_Bullet_Snow": lambda: decal_bullet_hole("snow", 28, 28, 31),
    "VFX_Decal_Bullet_Metal": lambda: decal_bullet_hole("metal", 20, 20, 37),
    "VFX_Decal_Bullet_Wood": lambda: decal_bullet_hole("wood", 22, 22, 41),
    "VFX_Decal_Blood_Pool_S": lambda: decal_blood_pool(96, 64, 51),
    "VFX_Decal_Blood_Pool_M": lambda: decal_blood_pool(160, 104, 53),
    "VFX_Decal_Blood_Pool_L": lambda: decal_blood_pool(240, 152, 57),
    "VFX_Decal_Blood_Trail": lambda: decal_blood_trail(64, 40, 59),
}


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
