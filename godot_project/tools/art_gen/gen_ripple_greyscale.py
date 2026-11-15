"""生成「六类声纹灰度冗余对照图」—— 合成图，绝非 Godot 实机截图。

输出：docs/ui/verify/ripple_accessibility_greyscale.png

用途：FIX-P0-3 的验收证据。把六类声纹全部去色（每类原色按 Rec.709 亮度转灰），
验证「只靠颜色」到底能不能分辨，以及新增的线型 + 中心图标在灰度下是否逐类可辨。

图里每个格子只画新增的冗余层（亮骨白线型 + 中心图标），统一高对比，
不沿用低亮度原色 —— 否则暗红 #b91c1c（亮度 61）连形状一起糊掉。
「原来只靠颜色」的问题由每格的 HEX / LUMA 数值与底部说明呈现：
琥珀 193/198/220 与冷蓝 196 在灰度下几乎同亮，暗红 61 沉进夜底。
不在同半径叠画细环，是为了避免粗冗余线把它盖住、或让实线组看起来像双环。

图中的定义**直接从 scripts/night/NightRippleStyle.gd 的 STYLES 读取**，不是手抄，
所以改了 GDScript 而忘了同步图纸会导致本脚本报错，不会悄悄画出过时的对照图。

零第三方依赖（本机没有 PIL / numpy / matplotlib），只用 zlib + struct 手写 PNG。

用法：
    python godot_project/tools/art_gen/gen_ripple_greyscale.py
"""
from __future__ import annotations

import math
import os
import re
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.abspath(os.path.join(HERE, "..", ".."))          # godot_project/
STYLE_SRC = os.path.join(PROJ, "scripts", "night", "NightRippleStyle.gd")
REPO = os.path.abspath(os.path.join(PROJ, ".."))
OUT = os.path.join(REPO, "docs", "ui", "verify",
                   "ripple_accessibility_greyscale.png")

W, H = 1200, 820
BG = 24
BONE = 232
FRAME = 74

# 5x7 点阵拉丁字库（验收图沿用 verify/README.md 的惯例：只写拉丁/西里尔，不写中文）
FONT = {
    'A': '01110/10001/10001/11111/10001/10001/10001',
    'B': '11110/10001/10001/11110/10001/10001/11110',
    'C': '01111/10000/10000/10000/10000/10000/01111',
    'D': '11110/10001/10001/10001/10001/10001/11110',
    'E': '11111/10000/10000/11110/10000/10000/11111',
    'F': '11111/10000/10000/11110/10000/10000/10000',
    'G': '01111/10000/10000/10111/10001/10001/01111',
    'H': '10001/10001/10001/11111/10001/10001/10001',
    'I': '11111/00100/00100/00100/00100/00100/11111',
    'J': '00111/00010/00010/00010/00010/10010/01100',
    'K': '10001/10010/10100/11000/10100/10010/10001',
    'L': '10000/10000/10000/10000/10000/10000/11111',
    'M': '10001/11011/10101/10101/10001/10001/10001',
    'N': '10001/11001/10101/10011/10001/10001/10001',
    'O': '01110/10001/10001/10001/10001/10001/01110',
    'P': '11110/10001/10001/11110/10000/10000/10000',
    'Q': '01110/10001/10001/10001/10101/10010/01101',
    'R': '11110/10001/10001/11110/10100/10010/10001',
    'S': '01111/10000/10000/01110/00001/00001/11110',
    'T': '11111/00100/00100/00100/00100/00100/00100',
    'U': '10001/10001/10001/10001/10001/10001/01110',
    'V': '10001/10001/10001/10001/10001/01010/00100',
    'W': '10001/10001/10001/10101/10101/11011/10001',
    'X': '10001/10001/01010/00100/01010/10001/10001',
    'Y': '10001/10001/01010/00100/00100/00100/00100',
    'Z': '11111/00001/00010/00100/01000/10000/11111',
    '0': '01110/10001/10011/10101/11001/10001/01110',
    '1': '00100/01100/00100/00100/00100/00100/01110',
    '2': '01110/10001/00001/00010/00100/01000/11111',
    '3': '11111/00010/00100/00010/00001/10001/01110',
    '4': '00010/00110/01010/10010/11111/00010/00010',
    '5': '11111/10000/11110/00001/00001/10001/01110',
    '6': '00110/01000/10000/11110/10001/10001/01110',
    '7': '11111/00001/00010/00100/01000/01000/01000',
    '8': '01110/10001/10001/01110/10001/10001/01110',
    '9': '01110/10001/10001/01111/00001/00010/01100',
    ' ': '00000/00000/00000/00000/00000/00000/00000',
    '-': '00000/00000/00000/11111/00000/00000/00000',
    '/': '00001/00001/00010/00100/01000/10000/10000',
    ':': '00000/00100/00100/00000/00100/00100/00000',
    '.': '00000/00000/00000/00000/00000/00100/00100',
    ',': '00000/00000/00000/00000/00100/00100/01000',
    '+': '00000/00100/00100/11111/00100/00100/00000',
    '#': '01010/01010/11111/01010/11111/01010/01010',
    '(': '00010/00100/01000/01000/01000/00100/00010',
    ')': '01000/00100/00010/00010/00010/00100/01000',
    '_': '00000/00000/00000/00000/00000/00000/11111',
    '=': '00000/00000/11111/00000/11111/00000/00000',
}


# ---------------------------------------------------------------------------
# 极简光栅化
# ---------------------------------------------------------------------------
def px(buf: bytearray, x: int, y: int, v: int, r: int = 1) -> None:
    half = r // 2
    for dy in range(-half, half + 1):
        for dx in range(-half, half + 1):
            xx, yy = x + dx, y + dy
            if 0 <= xx < W and 0 <= yy < H:
                o = (yy * W + xx) * 3
                buf[o] = buf[o + 1] = buf[o + 2] = v


def line(buf, x0, y0, x1, y1, v, width=1) -> None:
    d = max(1, int(max(abs(x1 - x0), abs(y1 - y0))))
    for i in range(d + 1):
        t = i / d
        px(buf, round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), v, width)


def polyline(buf, pts, v, width=1) -> None:
    for i in range(len(pts) - 1):
        line(buf, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], v, width)


def rect(buf, x0, y0, x1, y1, v, width=1) -> None:
    line(buf, x0, y0, x1, y0, v, width)
    line(buf, x1, y0, x1, y1, v, width)
    line(buf, x1, y1, x0, y1, v, width)
    line(buf, x0, y1, x0, y0, v, width)


def text(buf, x, y, s, scale=1, v=BONE) -> None:
    cx = x
    for ch in s.upper():
        pat = FONT.get(ch, FONT[' '])
        for ry, row in enumerate(pat.split('/')):
            for rx, bit in enumerate(row):
                if bit == '1':
                    for dy in range(scale):
                        for dx in range(scale):
                            px(buf, cx + rx * scale + dx, y + ry * scale + dy, v)
        cx += 6 * scale


def ellipse_pts(cx, cy, rx, ry, n=180):
    return [(cx + math.cos(2 * math.pi * i / n) * rx,
             cy + math.sin(2 * math.pi * i / n) * ry) for i in range(n + 1)]


def segments(buf, pts, v, width, count, ratio, alternating=False) -> None:
    total = len(pts) - 1
    seg = total / count
    for k in range(count):
        r = ratio * (0.35 if alternating and k % 2 else 1.0)
        a = int(round(k * seg))
        b = int(round(k * seg + seg * r))
        sub = pts[a:min(b, len(pts))]
        if len(sub) >= 2:
            polyline(buf, sub, v, width)


def ellipse_styled(buf, cx, cy, rx, ry, pattern, v, width=3) -> None:
    n = 180
    pts = ellipse_pts(cx, cy, rx, ry, n)
    if pattern == 'solid':
        polyline(buf, pts, v, width)
    elif pattern == 'double':
        polyline(buf, pts, v, width)
        polyline(buf, ellipse_pts(cx, cy, rx * 0.86, ry * 0.86, n), v, width)
    elif pattern == 'dashed':
        segments(buf, pts, v, width, 8, 0.62)
    elif pattern == 'dotted':
        segments(buf, pts, v, width, 24, 0.28)
    elif pattern == 'dashdot':
        segments(buf, pts, v, width, 12, 0.62, alternating=True)
    elif pattern == 'split':
        upper = [p for i, p in enumerate(pts) if math.sin(2 * math.pi * i / n) < 0]
        lower = [p for i, p in enumerate(pts) if math.sin(2 * math.pi * i / n) >= 0]
        polyline(buf, lower, v, width)
        segments(buf, upper, v, width, 6, 0.55)
    else:
        polyline(buf, pts, v, width)


def glyph(buf, cx, cy, g, v, width=3) -> None:
    u = 12.0
    if g == 'dot':
        for dy in range(-6, 7):
            for dx in range(-6, 7):
                if dx * dx + dy * dy <= 36:
                    px(buf, round(cx + dx), round(cy + dy), v, 2)
    elif g == 'triangle':
        p = [(cx, cy - u), (cx + u * 0.9, cy + u * 0.7),
             (cx - u * 0.9, cy + u * 0.7), (cx, cy - u)]
        polyline(buf, p, v, width)
    elif g == 'square':
        p = [(cx - u, cy - u), (cx + u, cy - u), (cx + u, cy + u),
             (cx - u, cy + u), (cx - u, cy - u)]
        polyline(buf, p, v, width)
    elif g == 'diamond':
        p = [(cx, cy - u * 1.2), (cx + u, cy), (cx, cy + u * 1.2),
             (cx - u, cy), (cx, cy - u * 1.2)]
        polyline(buf, p, v, width)
    elif g == 'cross':
        line(buf, cx - u, cy, cx + u, cy, v, width)
        line(buf, cx, cy - u, cx, cy + u, v, width)
    elif g == 'ring':
        pts = ellipse_pts(cx, cy, u, u, 40)
        polyline(buf, pts, v, width)


# ---------------------------------------------------------------------------
# PNG 编码（RGB8，filter 0）
# ---------------------------------------------------------------------------
def chunk(typ: bytes, data: bytes) -> bytes:
    return (struct.pack('>I', len(data)) + typ + data
            + struct.pack('>I', zlib.crc32(typ + data) & 0xffffffff))


def write_png(path: str, buf: bytearray) -> None:
    raw = bytearray()
    for y in range(H):
        raw.append(0)
        raw += buf[y * W * 3:(y + 1) * W * 3]
    png = (b'\x89PNG\r\n\x1a\n'
           + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress(bytes(raw), 9))
           + chunk(b'IEND', b''))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(png)


def luma(hex_color: str) -> int:
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    return round(0.2126 * r + 0.7152 * g + 0.0722 * b)


# ---------------------------------------------------------------------------
# 从 GDScript 单一事实源读取六色组定义
# ---------------------------------------------------------------------------
def read_styles() -> list[dict]:
    src = open(STYLE_SRC, encoding='utf-8').read()
    # STYLES 每个块按 pattern / glyph / label / tag / hex 顺序出现；
    # 其余键（name_zh / pattern_zh / glyph_zh）不在捕获组里，自动跳过。
    pairs = re.findall(r'"(pattern|glyph|label|tag|hex)":\s*"([^"]+)"', src)
    if len(pairs) != 30:
        raise RuntimeError(f'NightRippleStyle.gd 的 STYLES 结构变了：'
                           f'期望 6 组 × 5 键，实际 {len(pairs)} 个键；请同步本脚本。')
    out = []
    for i in range(0, 30, 5):
        d = dict(pairs[i:i + 5])
        out.append(d)
    return out


GROUP_NAMES = [
    'PLAYER / FOOTSTEP / HIT', 'RABID GROWL', 'OSK / GUNSHOT',
    'TIN CAN LURE', 'SEARCH NOISE', 'HALF-HUMAN MOAN',
]


def main() -> int:
    styles = read_styles()
    print('=== 从 NightRippleStyle.gd 读到 6 个色组 ===')
    for i, s in enumerate(styles, 1):
        print(f'  {i}. {s["tag"]:7s} {s["hex"]}  luma={luma(s["hex"]):3d}  '
              f'pattern={s["pattern"]:8s} glyph={s["glyph"]}')
    lums = [luma(s['hex']) for s in styles]
    print(f'  琥珀三档亮度 = {lums[3]} / {lums[4]} / {lums[5]}，暗红 = {lums[1]} '
          f'（去色后几乎不可分，正是 P0 现象）')

    buf = bytearray([BG]) * (W * H * 3)
    # 标题区
    text(buf, 24, 16, 'SYNTHETIC GREYSCALE VALIDATION SHEET', 3)
    text(buf, 24, 56, 'NOT AN ENGINE CAPTURE - GENERATED COMPOSITE - NO SHADERS / PARTICLES / HUD', 1, 168)
    text(buf, 24, 72, 'SOURCE: scripts/night/NightRippleStyle.gd + tools/art_gen/gen_ripple_greyscale.py', 1, 150)
    text(buf, 24, 88, 'COLOUR REMOVED: 6 LINE PATTERNS + 6 CENTRE GLYPHS MUST STAY DISTINCT', 1, 150)
    line(buf, 12, 106, W - 12, 106, FRAME, 1)

    # 3 列 x 2 行
    for idx, s in enumerate(styles):
        col, row = idx % 3, idx // 3
        x0, y0 = col * 400 + 12, 116 + row * 292
        x1, y1 = x0 + 376, y0 + 278
        rect(buf, x0, y0, x1, y1, FRAME, 1)
        text(buf, x0 + 12, y0 + 12, f'{idx + 1}  {s["tag"]}', 2)
        text(buf, x0 + 12, y0 + 40,
             f'HEX {s["hex"].upper()}   LUMA {luma(s["hex"])}', 1, 156)
        cx, cy = x0 + 188, y0 + 150
        # 只画冗余层：统一骨白高对比，不沿用暗红 #b91c1c（亮度 61）这种低亮度原色。
        ellipse_styled(buf, cx, cy, 110, 68, s['pattern'], BONE, 3)
        glyph(buf, cx, cy, s['glyph'], BONE, 3)
        text(buf, x0 + 12, y0 + 230, f'PATTERN: {s["pattern"].upper()}', 1, 190)
        text(buf, x0 + 12, y0 + 246, f'GLYPH: {s["glyph"].upper()}', 1, 190)
        text(buf, x0 + 12, y0 + 262, f'GROUP: {GROUP_NAMES[idx]}', 1, 150)

    # 底部说明
    line(buf, 12, 706, W - 12, 706, FRAME, 1)
    text(buf, 24, 716,
         'ORIGINAL COLOUR-ONLY RIPPLES HAVE LUMAS 212 / 61 / 196 / 193 / 198 / 220.', 1, 168)
    text(buf, 24, 734,
         'AMBER 193 / 198 / 220 AND COLD BLUE 196 NEARLY MATCH; DARK RED 61 SINKS INTO THE NIGHT.', 1, 168)
    text(buf, 24, 752,
         'EACH CELL HAS A UNIQUE LINE STYLE AND A UNIQUE CENTRE GLYPH - READABLE WITH COLOUR REMOVED.', 1, 168)
    text(buf, 24, 776, 'SYNTHETIC COMPOSITE - NOT A GODOT ENGINE CAPTURE', 2, BONE)

    write_png(OUT, buf)
    print(f'\n=== 已写出 {OUT}  ({W}x{H} RGB, {os.path.getsize(OUT)} bytes) ===')
    print('标注：合成对照图，不是实机截图；仅验证去色后的形状可辨性，不代表引擎内实测。')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
