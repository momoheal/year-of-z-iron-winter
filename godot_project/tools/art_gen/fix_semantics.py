#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""fix_semantics.py — 精灵表 v2 语义修正（2026-11-14 复核后的修复）。

对应 docs/art/2026-11-14_精灵表v2复核.md 的 P1 / P2 / P5 / P6：

  P5  敌方第 9-11 列三行不一致（tail2 覆盖了 N 行）
      → 三行统一。CHR_05 取 N 行的俯视躺姿作为共用尸体；其余取 S 行。
  P1  第 11 列不是倒地尸体 / 背面行是跪姿活人
      → 统一后按高度缩到 <= 78px，并做"倒地倾斜"让蜷缩读成侧躺而非端坐。
  P6  特殊姿势内容宽 70/72px，只剩 1px 余量
      → 等比回收到 <= 64px，脚底重新对齐 y=107。
  P2  CHR_05 的 E 行与 S 行剪影 IoU 0.978（没有转身）
      → E 行站立/行走帧收窄到 0.84 倍宽（侧身近似），c9-11 仍与 S 行共用。

只改 4 张 *_Sheet.png，不动 manifest / 场景 / 代码接线。
原始 v2 已备份在 .artwork/backup/v2_原始_2026-11-14/。

用法（任意工作目录）：
    python fix_semantics.py [--dry-run] [--no-tilt]
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
PROJ = HERE.parent.parent
ART = PROJ / "art" / "10_characters"

CW, CH = 72, 112
PIVOT_X, PIVOT_Y = 36, 107          # 落地线（与 check_chars.py 的 b=107 一致）
MAX_CONTENT_W = 64                  # P6：<= 66 断言留 2px 余量
MAX_CORPSE_H = 78                   # P1：<= 80 断言留 2px 余量
SIDE_SQUEEZE = 0.84                 # P2：侧身收窄比例
CORPSE_TILT = -18                   # P1：倒地倾斜角（度）

SHEETS = [
    "CHR_01_Aleksei",
    "CHR_03_Rabid",
    "CHR_04_HalfHuman",
    "CHR_05_OSK",
]
ENEMIES = SHEETS[1:]


def cell(img: Image.Image, r: int, c: int) -> Image.Image:
    return img.crop((c * CW, r * CH, (c + 1) * CW, (r + 1) * CH))


def put(img: Image.Image, r: int, c: int, body: Image.Image) -> None:
    """把一个已缩放好的 RGBA 图贴到单元格：水平居中，脚底贴 PIVOT_Y。"""
    w, h = body.size
    px = PIVOT_X - w // 2
    py = PIVOT_Y - (h - 1)
    # 显式裁掉负偏移，避免 PIL alpha_composite 绕回串帧
    cx = cy = 0
    if px < 0:
        cx, w, px = -px, w + px, 0
    if py < 0:
        cy, h, py = -py, h + py, 0
    if cx or cy:
        body = body.crop((cx, cy, cx + min(w, CW - px), cy + min(h, CH - py)))
    img.alpha_composite(body, (c * CW + px, r * CH + py))


def content_of(tile: Image.Image) -> Image.Image:
    """取 alpha bbox 里的实体，四周留 1px 透明边（避免缩放后硬切）。"""
    a = np.array(tile.convert("RGBA"))
    al = a[..., 3] > 8
    ys, xs = np.where(al)
    if ys.size == 0:
        return tile.convert("RGBA")
    x0, x1 = max(0, xs.min() - 1), min(tile.width, xs.max() + 2)
    y0, y1 = max(0, ys.min() - 1), min(tile.height, ys.max() + 2)
    return tile.convert("RGBA").crop((x0, y0, x1, y1))


def scaled(body: Image.Image, max_w: int, max_h: int | None = None) -> Image.Image:
    k = min(1.0, max_w / body.width)
    if max_h:
        k = min(k, max_h / body.height)
    if k >= 1.0:
        return body
    return body.resize((max(1, round(body.width * k)),
                        max(1, round(body.height * k))), Image.LANCZOS)


def tilted(body: Image.Image, degrees: float) -> Image.Image:
    """把蜷缩的尸体轻微倾斜，读成'侧倒在地'而不是'端正坐着'。"""
    rot = body.rotate(degrees, resample=Image.BICUBIC, expand=True)
    return content_of(rot)


def blank_cell() -> Image.Image:
    return Image.new("RGBA", (CW, CH), (0, 0, 0, 0))


def fix_one(name: str, dry: bool, do_tilt: bool) -> dict:
    path = ART / name / f"{name}_Sheet.png"
    img = Image.open(path).convert("RGBA")
    orig = img.copy()
    log = {"name": name}

    # --- P2：E 行站立/行走帧收窄，制造真实的朝向差异 ---
    if name == "CHR_05_OSK":
        for c in range(9):
            body = content_of(cell(orig, 1, c))
            nw = max(1, round(body.width * SIDE_SQUEEZE))
            body = body.resize((nw, body.height), Image.LANCZOS)
            # 必须先清空：alpha_composite 是叠加，不清空会把新帧叠在旧帧上
            img.paste(blank_cell(), (c * CW, 1 * CH))
            put(img, 1, c, scaled(body, MAX_CONTENT_W))
        log["P2"] = f"E 行 c0-8 收窄 {SIDE_SQUEEZE}（侧身近似）"

    # --- P5：敌方三行第 9-11 列统一 ---
    if name in ENEMIES:
        # CHR_05 的 N 行第 11 列是唯一真正"躺平"的俯视尸体，拿它当基准；
        # 其余角色用 S 行（S 与 E 原本就像素相同）。
        donor_cols = {11: 2} if name == "CHR_05_OSK" else {}
        for c in (9, 10, 11):
            src_row = donor_cols.get(c, 0)
            tile = cell(orig, src_row, c)
            for r in range(3):
                clear = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
                img.paste(clear, (c * CW, r * CH))
            for r in range(3):
                body = content_of(tile)
                if c == 11 and do_tilt:
                    body = tilted(body, CORPSE_TILT)
                body = scaled(body, MAX_CONTENT_W,
                              MAX_CORPSE_H if c == 11 else None)
                put(img, r, c, body)
        log["P5"] = "三行 c9-11 统一"

    # --- P6：玩家表 c9-11 也要收宽度（原本 58-59px 已达标，这里统一走一遍） ---
    if name == "CHR_01_Aleksei":
        for r in range(3):
            for c in (9, 10, 11):
                body = scaled(content_of(cell(orig, r, c)), MAX_CONTENT_W)
                img.paste(blank_cell(), (c * CW, r * CH))
                put(img, r, c, body)
        log["P6"] = "玩家 c9-11 宽度归一"

    if not dry:
        img.save(path)
        log["saved"] = str(path.relative_to(PROJ).as_posix())

    # --- 复核数据 ---
    a = np.array(img)[..., 3]
    widths, corpse_h, ios = [], [], []
    for r in range(3):
        for c in range(12):
            sub = a[r * CH:(r + 1) * CH, c * CW:(c + 1) * CW] > 8
            ys, xs = np.where(sub)
            if ys.size == 0:
                continue
            widths.append(int(xs.max() - xs.min() + 1))
            if c == 11:
                corpse_h.append(int(ys.max() - ys.min() + 1))
    for c in range(9):
        m0 = a[0:CH, c * CW:(c + 1) * CW] > 8
        m1 = a[CH:2 * CH, c * CW:(c + 1) * CW] > 8
        ios.append(float((m0 & m1).sum() / max(1, (m0 | m1).sum())))
    log["max_w"] = max(widths)
    log["corpse_h"] = corpse_h
    log["SE_iou"] = round(float(np.mean(ios)), 3)
    return log


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-tilt", action="store_true")
    a = ap.parse_args()
    print(f"[art] {ART}")
    for name in SHEETS:
        log = fix_one(name, a.dry_run, not a.no_tilt)
        print(f"  {name:20s} maxW={log['max_w']:2d}  "
              f"corpseH={log['corpse_h']}  S/E IoU={log['SE_iou']:.3f}  "
              f"{'; '.join(f'{k}={v}' for k, v in log.items() if k in ('P2', 'P5', 'P6'))}")
        assert log["max_w"] <= 66, f"{name} 内容超宽"
        assert all(h <= 80 for h in log["corpse_h"]), f"{name} 尸体帧过高"
        assert log["SE_iou"] <= 0.90, f"{name} S/E 无朝向差异"
    print("[done] 三条语义红线全部满足" + ("（dry-run，未写盘）" if a.dry_run else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
