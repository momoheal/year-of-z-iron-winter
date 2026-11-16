#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""sprite_assemble.py — 三个朝向的 12 格 AI 出图 → 引擎 12×3 精灵表。

每张朝向图按 4 列 × 3 行 = 12 格切分（与出图 prompt 对齐），
再按模板映射进 12 列：
    列 0      ← 源 0   待机
    列 1-7    ← 源 1-7 行走
    列 8      ← 源 1   行走循环闭合帧（同一姿势，标准做法）
    列 9      ← 源 8   蹲伏 / 攻击预备
    列 10     ← 源 9   蹲走A / 死亡
    列 11     ← 源 10  蹲走B / 硬直

用法：
  python sprite_assemble.py --out sheet.png --preview prev.png \
      --row0 front.png --row1 east.png --row2 back.png
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from sprite_sheet_build import CELL_W, CELL_H, PIVOT_X, PIVOT_Y, ensure_alpha, detect_grid

SRC_COLS, SRC_ROWS = 4, 3
ALPHA_TH = 96   # 低于此值视为抠图残渣，不参与包围盒/连通域判断
# 目标列 → 源格序号（源为 4×3 栅格，序号 = row*4+col）
DEFAULT_MAP = [0, 1, 2, 3, 4, 5, 6, 7, 1, 8, 9, 10]


def strip_shadow(cell: Image.Image) -> Image.Image:
    """抹掉脚底烘焙的浅灰投影：底部 12% 区域内「低饱和 + 偏亮」的像素置透明。"""
    a = np.array(cell, np.float32)
    h = a.shape[0]
    y0 = int(h * 0.88)
    reg = a[y0:, :, :3] / 255.0
    mx, mn = reg.max(2), reg.min(2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    lum = reg.mean(2)
    kill = (sat < 0.16) & (lum > 0.62)
    a[y0:, :, 3] = np.where(kill, 0, a[y0:, :, 3])
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def keep_largest_component(body: Image.Image) -> Image.Image:
    """只保留最大的连通块，去掉旁边的枪管/碎屑等孤立体。"""
    arr = np.array(body)
    mask = arr[..., 3] > ALPHA_TH
    if mask.sum() < 100:
        return body
    h, w = mask.shape
    seen = np.zeros((h, w), dtype=bool)
    best_size, best_seed = 0, None
    for y in range(h):
        row = mask[y]
        for x in np.where(row & ~seen[y])[0]:
            if seen[y, x]:
                continue
            stack = [(y, int(x))]
            seen[y, x] = True
            size = 0
            while stack:
                cy, cx = stack.pop()
                size += 1
                if cy > 0 and mask[cy - 1, cx] and not seen[cy - 1, cx]:
                    seen[cy - 1, cx] = True
                    stack.append((cy - 1, cx))
                if cy + 1 < h and mask[cy + 1, cx] and not seen[cy + 1, cx]:
                    seen[cy + 1, cx] = True
                    stack.append((cy + 1, cx))
                if cx > 0 and mask[cy, cx - 1] and not seen[cy, cx - 1]:
                    seen[cy, cx - 1] = True
                    stack.append((cy, cx - 1))
                if cx + 1 < w and mask[cy, cx + 1] and not seen[cy, cx + 1]:
                    seen[cy, cx + 1] = True
                    stack.append((cy, cx + 1))
            if size > best_size:
                best_size, best_seed = size, (y, int(x))
    if best_seed is None:
        return body
    # 重跑一次只保留最大块
    keep = np.zeros((h, w), dtype=bool)
    stack = [best_seed]
    keep[best_seed] = True
    while stack:
        cy, cx = stack.pop()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not keep[ny, nx]:
                keep[ny, nx] = True
                stack.append((ny, nx))
    out = arr.copy()
    out[..., 3] = np.where(keep, out[..., 3], 0)
    ys, xs = np.where(keep)
    return Image.fromarray(out, "RGBA").crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def trim_sliver(body: Image.Image) -> Image.Image:
    """去掉脱离主体的残影（上一行脚底/笔触碎屑）：只保留纵向像素量最大的连续带。"""
    al = np.array(body)[..., 3]
    prof = al.sum(axis=1).astype(np.float64)
    if prof.max() <= 0:
        return body
    on = prof > prof.max() * 0.02
    best, cur, start = (0, 0), 0.0, None
    for i, v in enumerate(on):
        if v and start is None:
            start = i
        elif not v and start is not None:
            mass = prof[start:i].sum()
            if mass > best[1]:
                best = ((start, i), mass)
            start = None
    if start is not None:
        mass = prof[start:].sum()
        if mass > best[1]:
            best = ((start, len(on)), mass)
    if best[1] <= 0:
        return body
    y0, y1 = best[0]
    if y1 - y0 < body.height:
        body = body.crop((0, y0, body.width, y1))
    return body


def cells_of(path: Path, shadow_trim: bool, src_rows=SRC_ROWS, src_cols=SRC_COLS) -> list[Image.Image]:
    img = ensure_alpha(Image.open(path))
    alpha = np.array(img)[..., 3]
    colb, rowb, mode = detect_grid(alpha > 24, src_rows, src_cols)
    print(f"  [{path.name}] 网格 {mode}")
    out = []
    for r in range(src_rows):
        for c in range(src_cols):
            x0, x1 = int(round(colb[c])), int(round(colb[c + 1]))
            y0, y1 = int(round(rowb[r])), int(round(rowb[r + 1]))
            sub = img.crop((x0, y0, x1, y1))
            sm = np.array(sub)[..., 3] > ALPHA_TH
            if sm.sum() < 50:
                print(f"    警告：源格 {r}-{c} 为空")
                out.append(None)
                continue
            ys, xs = np.where(sm)
            body = sub.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
            body = keep_largest_component(body)
            body = trim_sliver(body)
            if shadow_trim:
                body = strip_shadow(body)
                m2 = np.array(body)[..., 3] > ALPHA_TH
                if m2.sum() > 50:
                    ys, xs = np.where(m2)
                    body = body.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
            out.append(body)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--preview")
    ap.add_argument("--row0", required=True, help="S 面朝镜头")
    ap.add_argument("--row1", required=True, help="E 侧面朝右")
    ap.add_argument("--row2", required=True, help="N 背对镜头")
    ap.add_argument("--scale-h", type=float, default=100.0)
    ap.add_argument("--no-shadow-trim", action="store_true")
    ap.add_argument("--tail2", help="可选的补充图：用于替换第 3 行（背面）的蹲伏/特殊姿势")
    ap.add_argument("--tail2-rows", type=int, default=1)
    ap.add_argument("--tail2-cols", type=int, default=4)
    ap.add_argument("--tail-all", help="补充图：替换全部三行第 10-12 列（敌方死亡/攻击姿势）")
    ap.add_argument("--tail-all-rows", type=int, default=1)
    ap.add_argument("--tail-all-cols", type=int, default=4)
    ap.add_argument("--map", default=",".join(str(i) for i in DEFAULT_MAP))
    a = ap.parse_args()

    mapping = [int(x) for x in a.map.split(",")]
    assert len(mapping) == 12, "映射表必须是 12 项"

    rows_src = [Path(a.row0), Path(a.row1), Path(a.row2)]
    src = [cells_of(p, not a.no_shadow_trim) for p in rows_src]

    # 2026-11-14 语义修正：敌方表的 c9-11 必须三行统一（check_chars.py 有红线）。
    # 旧逻辑「先 tail-all 再 tail2」会让 N 行被背面专用图覆盖 → 尸体在背面行
    # 变成跪姿活人，且转向时姿势/尺寸跳变。故 tail-all 与 tail2 互斥：
    #   · 敌人（--tail-all）：三行共用同一组特殊姿势，忽略 tail2
    #   · 玩家（只用 --tail2）：保留背面专用蹲伏，玩家表不查三行统一
    if a.tail_all:
        tail = cells_of(Path(a.tail_all), not a.no_shadow_trim, a.tail_all_rows, a.tail_all_cols)
        for r in range(3):
            for k in range(3):
                if k < len(tail) and tail[k] is not None:
                    src[r][8 + k] = tail[k]
        print("  [tail-all] 已替换三行第 10-12 列（三行统一）")
        if a.tail2:
            print("  [tail-all] 已忽略 --tail2：敌方特殊姿势必须三行一致")
    elif a.tail2:
        tail = cells_of(Path(a.tail2), not a.no_shadow_trim, a.tail2_rows, a.tail2_cols)
        for k in range(3):
            if k < len(tail) and tail[k] is not None:
                src[2][8 + k] = tail[k]
        print("  [tail2] 已用背面专用姿势覆盖第 3 行第 10-12 列")

    # 组装 36 个目标格
    dest: list[Image.Image | None] = []
    for r in range(3):
        for c in range(12):
            dest.append(src[r][mapping[c]])

    # 统一缩放：以行走列（1-8）高度中位数为基准，保证帧间大小不跳
    walk_h = [d.height for i, d in enumerate(dest) if d is not None and 1 <= (i % 12) <= 8]
    ref_h = float(np.median(walk_h))
    scale = a.scale_h / ref_h
    print(f"[scale] 参考高度 {ref_h:.1f} → 因子 {scale:.3f}")

    sheet = Image.new("RGBA", (CELL_W * 12, CELL_H * 3), (0, 0, 0, 0))
    bottoms = []
    for i, d in enumerate(dest):
        r, c = divmod(i, 12)
        if d is None:
            continue
        w = max(1, int(round(d.width * scale)))
        h = max(1, int(round(d.height * scale)))
        # 超宽/超高的极端姿势（举臂、横躺）单独缩放到单元格内，绝不让头顶出血。
        # 2026-11-14：宽度上限从 CELL_W-2(70) 收到 CELL_W-6(66)，
        # 对应 check_chars.py「帧内容宽度 ≤ 66px」红线，避免只剩 1px 余量。
        max_h = PIVOT_Y - 4
        max_w = CELL_W - 6
        if w > max_w:
            k = max_w / w
            w, h = max_w, max(1, int(round(h * k)))
        if h > max_h:
            k = max_h / h
            w, h = max(1, int(round(w * k))), max_h
        body = d.resize((w, h), Image.LANCZOS)
        px = PIVOT_X - w // 2
        py = PIVOT_Y - h
        # PIL 对负偏移的 alpha_composite 不可靠，先显式裁掉超出单元格的部分
        cx, cy = 0, 0
        if px < 0:
            cx, w = -px, w + px
            px = 0
        if py < 0:
            cy, h = -py, h + py
            py = 0
        if cx or cy:
            body = body.crop((cx, cy, cx + min(w, CELL_W - px), cy + min(h, CELL_H - py)))
            w, h = body.size
        sheet.alpha_composite(body, (c * CELL_W + px, r * CELL_H + py))
        bottoms.append(py + h)

    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(f"[out] {out} {sheet.size}")
    if bottoms:
        print(f"[feet] 落地线 {min(bottoms)}~{max(bottoms)}（pivot y={PIVOT_Y}）")

    if a.preview:
        zoom = 3
        z = sheet.resize((sheet.width * zoom, sheet.height * zoom), Image.NEAREST)
        bg = Image.new("RGBA", z.size, (26, 28, 33, 255))
        bg.alpha_composite(z)
        dr = ImageDraw.Draw(bg)
        for c in range(13):
            dr.line([(c * CELL_W * zoom, 0), (c * CELL_W * zoom, bg.height)], fill=(255, 0, 128, 110))
        for r in range(4):
            dr.line([(0, r * CELL_H * zoom), (bg.width, r * CELL_H * zoom)], fill=(255, 0, 128, 150))
        p = Path(a.preview)
        p.parent.mkdir(parents=True, exist_ok=True)
        bg.convert("RGB").save(p)
        print(f"[preview] {p}")


if __name__ == "__main__":
    main()
