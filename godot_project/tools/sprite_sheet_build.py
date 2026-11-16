#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""sprite_sheet_build.py — 把 AI 生成的网格图切帧并拼成引擎规格精灵表。

引擎规格（硬约束）：
  每帧 72×112，pivot 脚底中心 (36,108)
  12 列 × 3 行 = 36 帧，864×336
  行序 0=S 1=E 2=N
  列序 0=待机 1-8=行走 9=蹲伏/攻击预备 10=蹲走A/死亡 11=蹲走B/硬直

用法：
  python sprite_sheet_build.py <源图> <输出png> [--rows 3] [--cols 12] \
      [--preview 预览.png] [--report] [--bgkey auto|none] [--scale-h 100]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

CELL_W, CELL_H = 72, 112
PIVOT_X, PIVOT_Y = 36, 108


# ---------------------------------------------------------------- 背景处理
def ensure_alpha(img: Image.Image, bgkey: str = "auto") -> Image.Image:
    """保证出图带 alpha。若源图本身透明就直接用；否则按角落色抠背景。"""
    img = img.convert("RGBA")
    a = np.array(img)
    if a[..., 3].min() < 250:  # 已经有真透明
        return img
    if bgkey == "none":
        return img

    rgb = a[..., :3].astype(np.int16)
    # 取四角与边缘中位色作为背景色估计
    edge = np.concatenate([rgb[0, :, :], rgb[-1, :, :], rgb[:, 0, :], rgb[:, -1, :]])
    bg = np.median(edge, axis=0)
    dist = np.abs(rgb - bg).sum(axis=2)

    # 白底出图：直接按颜色全域抠掉，否则腿/臂围出的封闭白块会残留
    neutral_white = bg.min() > 228 and (bg.max() - bg.min()) < 14
    if neutral_white:
        solid = dist > 45
        # 1px 腐蚀，去掉残留在轮廓上的白边/半透明雾
        er = solid.copy()
        er[1:, :] &= solid[:-1, :]
        er[:-1, :] &= solid[1:, :]
        er[:, 1:] &= solid[:, :-1]
        er[:, :-1] &= solid[:, 1:]
        out = a.copy()
        out[..., 3] = np.where(er, 255, 0).astype(np.uint8)
        return Image.fromarray(out, "RGBA")

    near = dist < 34

    # 只抠「与边框连通」的背景，避免把角色身上的白色高光一起抠掉
    h, w = near.shape
    ds = 4
    small = near[::ds, ::ds].copy()
    reach = np.zeros_like(small, dtype=bool)
    reach[0, :] = small[0, :]
    reach[-1, :] = small[-1, :]
    reach[:, 0] = small[:, 0]
    reach[:, -1] = small[:, -1]
    for _ in range(max(small.shape) * 2):
        grown = reach.copy()
        grown[1:, :] |= reach[:-1, :]
        grown[:-1, :] |= reach[1:, :]
        grown[:, 1:] |= reach[:, :-1]
        grown[:, :-1] |= reach[:, 1:]
        grown &= small
        if grown.sum() == reach.sum():
            break
        reach = grown
    big = np.repeat(np.repeat(reach, ds, axis=0), ds, axis=1)[:h, :w]
    if big.shape != near.shape:
        pad = np.zeros_like(near)
        pad[: big.shape[0], : big.shape[1]] = big
        big = pad

    alpha = np.where(big, 0, 255).astype(np.uint8)
    # 软边：离背景色越近越透明（只作用在边缘 2px 内）
    out = a.copy()
    out[..., 3] = alpha
    return Image.fromarray(out, "RGBA")


def trim_transparent(img: Image.Image) -> Image.Image:
    a = np.array(img)[..., 3]
    ys, xs = np.where(a > 8)
    if len(xs) == 0:
        return img
    return img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


# ---------------------------------------------------------------- 网格检测
def _runs(profile: np.ndarray, thr: float) -> list[tuple[int, int]]:
    """在投影曲线上找连续 >thr 的区段。"""
    on = profile > thr
    runs, start = [], None
    for i, v in enumerate(on):
        if v and start is None:
            start = i
        elif not v and start is not None:
            runs.append((start, i))
            start = None
    if start is not None:
        runs.append((start, len(on)))
    return runs


def detect_grid(mask: np.ndarray, rows: int, cols: int) -> tuple[list, list, str]:
    """返回 (列边界列表 length cols+1, 行边界列表 length rows+1, 检测方式)"""
    h, w = mask.shape
    colp = mask.sum(axis=0)
    rowp = mask.sum(axis=1)
    cr = _runs(colp, max(1.0, colp.max() * 0.04))
    rr = _runs(rowp, max(1.0, rowp.max() * 0.04))

    def mids(runs, total, n, axis):
        # 区段数 > n 时，反复合并「间隙最窄」的相邻区段（细长姿势会被投影切成多段）
        runs = [list(r) for r in runs]
        while len(runs) > n and len(runs) > 1:
            gaps = [runs[i + 1][0] - runs[i][1] for i in range(len(runs) - 1)]
            k = int(np.argmin(gaps))
            runs[k] = [runs[k][0], runs[k + 1][1]]
            del runs[k + 1]
        centers = [(s + e) / 2 for s, e in runs]
        if len(centers) == n:
            bounds = [0.0]
            for i in range(n - 1):
                bounds.append((runs[i][1] + runs[i + 1][0]) / 2)
            bounds.append(float(total))
            return bounds
        # 区段数 < n：按「内容包围盒」等分，避免整幅画布等分导致切片错位
        if axis == "x":
            cols = mask.any(axis=0)
        else:
            cols = mask.any(axis=1)
        idx = np.where(cols)[0]
        if idx.size:
            x0, x1 = int(idx[0]), int(idx[-1]) + 1
            return [x0 + (x1 - x0) * i / n for i in range(n + 1)]
        return [total * i / n for i in range(n + 1)]

    if len(cr) == cols and len(rr) == rows:
        mode = "projection-exact"
    else:
        mode = f"fallback(检测到 {len(cr)}列/{len(rr)}行)"
    colb = mids(cr, w, cols, "x")
    rowb = mids(rr, h, rows, "y")
    return colb, rowb, mode


# ---------------------------------------------------------------- 主流程
def build(src: Path, out: Path, rows=3, cols=12, preview: Path | None = None,
          bgkey="auto", scale_h=100.0, report=False):
    raw = Image.open(src)
    img = ensure_alpha(raw, bgkey)
    alpha = np.array(img)[..., 3]
    mask = alpha > 24

    colb, rowb, mode = detect_grid(mask, rows, cols)
    cells = []
    for r in range(rows):
        for c in range(cols):
            x0, x1 = int(round(colb[c])), int(round(colb[c + 1]))
            y0, y1 = int(round(rowb[r])), int(round(rowb[r + 1]))
            sub = img.crop((x0, y0, x1, y1))
            sm = np.array(sub)[..., 3] > 24
            if sm.sum() < 20:
                cells.append({"img": None, "h": 0, "w": 0, "cov": 0.0})
                continue
            ys, xs = np.where(sm)
            bbox = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
            body = sub.crop(bbox)
            cells.append({
                "img": body,
                "h": bbox[3] - bbox[1],
                "w": bbox[2] - bbox[0],
                "cov": float(sm.sum()) / sm.size,
            })

    # 统一缩放：以站立/行走帧（列 0-8）的高度中位数为基准
    walk_h = [c["h"] for i, c in enumerate(cells) if c["img"] and (i % cols) <= 8]
    if not walk_h:
        walk_h = [c["h"] for c in cells if c["img"]]
    if not walk_h:
        raise SystemExit("源图里没检测到任何角色像素，检查出图/抠背景参数")
    ref_h = float(np.median(walk_h))
    scale = scale_h / ref_h

    sheet = Image.new("RGBA", (CELL_W * cols, CELL_H * rows), (0, 0, 0, 0))
    info = []
    for i, c in enumerate(cells):
        r, col = divmod(i, cols)
        if c["img"] is None:
            info.append({"idx": i, "row": r, "col": col, "empty": True})
            continue
        w = max(1, int(round(c["w"] * scale)))
        h = max(1, int(round(c["h"] * scale)))
        if w > CELL_W:
            k = CELL_W / w
            w, h = CELL_W, max(1, int(round(h * k)))
        if h > CELL_H - 2:
            k = (CELL_H - 2) / h
            w, h = max(1, int(round(w * k))), CELL_H - 2
        body = c["img"].resize((w, h), Image.LANCZOS)
        px = CELL_W // 2 - w // 2
        py = PIVOT_Y - h
        sheet.alpha_composite(body, (col * CELL_W + px, r * CELL_H + py))
        info.append({"idx": i, "row": r, "col": col, "w": w, "h": h,
                     "cov": round(c["cov"], 3)})

    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)

    if preview:
        make_preview(sheet, preview, rows, cols)

    print(f"[grid] {mode}")
    print(f"[scale] 参考高度 {ref_h:.1f}px → 因子 {scale:.3f}")
    empties = [d["idx"] for d in info if d.get("empty")]
    print(f"[cells] {len(info) - len(empties)}/{len(info)} 有内容"
          + (f"；空格编号 {empties}" if empties else ""))
    if report:
        print(json.dumps(info, ensure_ascii=False))
    return sheet


def make_preview(sheet: Image.Image, dst: Path, rows=3, cols=12, zoom=4):
    z = sheet.resize((sheet.width * zoom, sheet.height * zoom), Image.NEAREST)
    bg = Image.new("RGBA", z.size, (24, 26, 30, 255))
    bg.alpha_composite(z)
    d = ImageDraw.Draw(bg)
    for c in range(cols + 1):
        x = c * CELL_W * zoom
        d.line([(x, 0), (x, bg.height)], fill=(255, 0, 128, 120), width=1)
    for r in range(rows + 1):
        y = r * CELL_H * zoom
        d.line([(0, y), (bg.width, y)], fill=(255, 0, 128, 160), width=1)
    for r in range(rows):
        for c in range(cols):
            d.text((c * CELL_W * zoom + 6, r * CELL_H * zoom + 4),
                   f"{r}-{c}", fill=(120, 220, 255, 255))
    dst.parent.mkdir(parents=True, exist_ok=True)
    bg.convert("RGB").save(dst)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--rows", type=int, default=3)
    ap.add_argument("--cols", type=int, default=12)
    ap.add_argument("--preview")
    ap.add_argument("--bgkey", default="auto")
    ap.add_argument("--scale-h", type=float, default=100.0)
    ap.add_argument("--report", action="store_true")
    a = ap.parse_args()
    build(Path(a.src), Path(a.out), a.rows, a.cols,
          Path(a.preview) if a.preview else None, a.bgkey, a.scale_h, a.report)


if __name__ == "__main__":
    main()
