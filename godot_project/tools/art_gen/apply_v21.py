#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""apply_v21.py — 把 v2.1 重出的 AI 帧切帧装入 12x3 精灵表（2026-11-14）。

对应 docs/art/2026-11-14_精灵表v2复核.md 的 P1 / P2 / P3 / P4：

  P3  CHR_05 c9/c10 换成正确 AKM（标准尺寸深色弧形弹匣、木护木、消音器）
  P4  CHR_01 c9-11 换成锻造铁撬棍（扁凿头 + 弯钩爪头，无树皮），三行按朝向各一帧
  P1  三个敌人 c11 换成真正横躺的尸体（横向、透视补偿后帧高约 42-50px）
  P2  CHR_05 E 行 c0-8 换成真 90° 侧面的 4x3 网格出图（替换 v2.1 的 0.84 收窄近似）

v2.3 修正（2026-11-15，见 docs/art/2026-11-14_精灵表v2复核.md 第七节）：
  - 弹匣退回 14:28/14:29 标准版。14:39 的「放大 1.5 倍亮银弹匣」在 72px 下
    读起来像挂在胸前的浅蓝布带/围裙，是明显错误，已弃用。程序化的局部提亮
    （椭圆/多边形/掩膜三种）都会把弹匣周围制服一起提亮成灰色补丁，同样弃用。
    小尺寸对比度不足是已知遗留，不再用几何/调色手段硬凑。
  - 尸体不再只按宽度等比缩放（那样得到 62x30px 的贴地扁片，与 100px 高的
    站立帧体量断裂）。改为纵向透视补偿 x1.4，得到约 64x42~50px；不旋转，
    因为旋转 20° 以上会把「躺平」变成「爬行/俯卧撑」，更像活人。

源图在 .artwork/src_gpt/v2.1/。单格图用 sprite_sheet_build.ensure_alpha 做白底硬抠
（dist>45 + 1px 腐蚀）；P2 的 12 格网格复用 sprite_assemble.cells_of 切格。
与 sprite_assemble.py 同一套抠图逻辑。

只改 4 张 *_Sheet.png，不动 manifest / 场景 / 代码接线。可重复执行（幂等）：
每次都从固定的源图重新生成目标单元格，缩放基准取自不受本次替换影响的 S/N 行走行。

用法（任意工作目录）：
    python apply_v21.py [--dry-run]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
PROJ = HERE.parent.parent
ART = PROJ / "art" / "10_characters"
SRC = PROJ.parent / ".artwork" / "src_gpt" / "v2.1"
sys.path.insert(0, str(PROJ / "tools"))
from sprite_sheet_build import ensure_alpha  # noqa: E402

CW, CH = 72, 112
PIVOT_X, PIVOT_Y = 36, 107       # 落地线，与 check_chars.py 的 b=107 一致
MAX_W = 64                       # 红线 <= 66，留 2px 余量
MAX_CORPSE_H = 70                # 尸体体量上限：排除跪姿活人
MIN_CORPSE_H = 40                # 尸体体量下限：排除贴地扁片
CORPSE_STRETCH = 1.4             # 纵向透视补偿（不旋转，避免读成爬行）

# v2.1 出图文件（按生成时间命名，固定映射保证可复现）
SIDE_GRID = "IMAGE_1_is_the_STYLE_and_CHARA_2026-11-14T14-42-13.png"
SIDE_MAP = [0, 1, 2, 3, 4, 5, 6, 7, 1]   # 目标 c0-8 ← 源格；c8 复制 c1 闭合行走循环

FILES = {
    # 标准尺寸深色弧弹匣（形状/比例/金属质感正确）。14:39 的放大亮银版已弃用：
    # 它在 72px 下像浅蓝布带；程序化提亮则会把胸口一起提亮成灰补丁。
    "osk_aim":   "IMAGE_1_is_the_exact_character_2026-11-14T14-28-00.png",
    "osk_low":   "IMAGE_1_is_the_exact_character_2026-11-14T14-29-39.png",
    "alek_S":    "IMAGE_1_is_the_exact_character_2026-11-14T14-31-12.png",
    "alek_E":    "IMAGE_1_is_the_exact_character_2026-11-14T14-31-34.png",
    "alek_N":    "IMAGE_1_is_the_exact_character_2026-11-14T14-31-54.png",
    "corpse_03": "IMAGE_1_shows_the_same_rabid_i_2026-11-14T14-32-23.png",
    "corpse_04": "IMAGE_1_shows_the_SAME_grey_pa_2026-11-14T14-33-15.png",
    "corpse_05": "IMAGE_1_is_a_bad_top_down_view_2026-11-14T14-33-39.png",
}

# (表名, 行, 列, 源图 key, 拟合参数)
# 敌方 c9-11 三行必须像素一致（check_chars.py 红线），因此 rows 一律写 range(3)。
# 主角表按朝向各一帧，保有正面 / 侧面 / 背面差异。
PLAN: list[tuple[str, list[int], list[int], str, dict]] = []
for row, key in enumerate(("alek_S", "alek_E", "alek_N")):
    PLAN.append(("CHR_01_Aleksei", [row], [9, 10, 11], key, {"target_h": 72}))

CORPSE_FIT = {"target_w": 64, "max_h": MAX_CORPSE_H, "stretch": CORPSE_STRETCH}
PLAN += [
    ("CHR_03_Rabid",    [0, 1, 2], [11], "corpse_03", dict(CORPSE_FIT)),
    ("CHR_04_HalfHuman", [0, 1, 2], [11], "corpse_04", dict(CORPSE_FIT)),
    ("CHR_05_OSK",      [0, 1, 2], [9],  "osk_aim",   {"target_h": 104}),
    ("CHR_05_OSK",      [0, 1, 2], [10], "osk_low",   {"target_h": 104}),
    ("CHR_05_OSK",      [0, 1, 2], [11], "corpse_05", dict(CORPSE_FIT)),
]

SHEETS = sorted({p[0] for p in PLAN})


def body_of(key: str) -> Image.Image:
    """白底抠图 → 取主体包围盒。"""
    path = SRC / FILES[key]
    if not path.exists():
        raise FileNotFoundError(f"缺少 v2.1 出图：{path}")
    im = ensure_alpha(Image.open(path).convert("RGBA"))
    a = np.array(im)[..., 3]
    ys, xs = np.where(a > 96)
    if ys.size < 100:
        raise ValueError(f"{path.name} 抠图后主体过小")
    return im.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def fit(body: Image.Image, target_h: int | None = None,
        target_w: int | None = None, max_h: int | None = None,
        stretch: float = 1.0) -> Image.Image:
    """按目标高/宽等比缩放，并卡住 64px 宽度上限与尸体高度上限。

    stretch 是尸体的纵向透视补偿：源图是略俯视的横躺人体，直接等比缩到 64px 宽
    只剩约 30px 高，与 100px 高的站立帧体量断裂。纵向 x1.4 把「俯视压扁」补偿回来，
    得到约 64x42~50px；不旋转，旋转会把躺平读成爬行。
    """
    if stretch != 1.0:
        body = body.resize((body.width, max(1, round(body.height * stretch))),
                           Image.LANCZOS)
    w, h = body.size
    k = target_h / h if target_h else (target_w / w if target_w else 1.0)
    k = min(k, MAX_W / w)
    if max_h:
        k = min(k, max_h / h)
    return body.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)


def put(img: Image.Image, r: int, c: int, body: Image.Image) -> None:
    """清空目标格后贴入：水平居中、脚底贴 y=107。必须先清空，否则 alpha 叠加。"""
    w, h = body.size
    px, py = PIVOT_X - w // 2, PIVOT_Y - (h - 1)
    if px < 0 or py < 0 or px + w > CW or py + h > CH:
        raise ValueError(f"帧 {r}-{c} 尺寸越界：{body.size} @ ({px},{py})")
    img.paste(Image.new("RGBA", (CW, CH), (0, 0, 0, 0)), (c * CW, r * CH))
    img.alpha_composite(body, (c * CW + px, r * CH + py))


def side_target_h(img: Image.Image) -> float:
    """缩放基准取 S/N 行 c1-8 的帧高中位数；不读 E 行，保证重复执行结果一致。"""
    a = np.array(img)[..., 3]
    hs = []
    for r in (0, 2):
        for c in range(1, 9):
            ys, _ = np.where(a[r * CH:(r + 1) * CH, c * CW:(c + 1) * CW] > 8)
            hs.append(int(ys.max() - ys.min() + 1))
    return float(np.median(hs))


def apply_side(img: Image.Image, target_h: float) -> None:
    """P2：CHR_05 的 E 行 c0-8 换成 4x3 网格里的真 90° 侧面行走帧。"""
    from sprite_assemble import cells_of
    cells = cells_of(SRC / SIDE_GRID, True, 3, 4)
    if len(cells) != 12 or any(x is None for x in cells):
        raise ValueError(f"{SIDE_GRID} 没有切出 12 个非空格")
    for c, si in enumerate(SIDE_MAP):
        put(img, 1, c, fit(cells[si], target_h=target_h))


def stats(img: Image.Image) -> dict:
    a = np.array(img)[..., 3]
    widths, corpse_h, ious = [], [], []
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
        ious.append(float((m0 & m1).sum() / max(1, (m0 | m1).sum())))
    return {"max_w": max(widths), "corpse_h": corpse_h,
            "SE_iou": round(float(np.mean(ious)), 3), "empty": 36 - len(widths)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    cache: dict[str, Image.Image] = {}
    imgs: dict[str, Image.Image] = {
        name: Image.open(ART / name / f"{name}_Sheet.png").convert("RGBA")
        for name in SHEETS
    }

    touched = 0
    for sheet, rows, cols, key, kw in PLAN:
        if key not in cache:
            raw = body_of(key)
            cache[key] = fit(raw, **kw)
            print(f"  [{key:9s}] 源 {raw.size} → 帧 {cache[key].size}")
        for r in rows:
            for c in cols:
                put(imgs[sheet], r, c, cache[key])
                touched += 1

    side_h = side_target_h(imgs["CHR_05_OSK"])
    apply_side(imgs["CHR_05_OSK"], side_h)
    touched += len(SIDE_MAP)
    print(f"[P2] CHR_05 E 行 c0-8 → 真 90° 侧面（基准高 {side_h:.0f}px）")

    print(f"[apply] 共替换 {touched} 个单元格")
    for name in SHEETS:
        s = stats(imgs[name])
        print(f"  {name:20s} maxW={s['max_w']:2d}  corpseH={s['corpse_h']}  "
              f"S/E IoU={s['SE_iou']:.3f}  空帧={s['empty']}")
        assert s["max_w"] <= 66, f"{name} 内容超宽"
        if name == "CHR_01_Aleksei":
            # 主角 c11 是蹲伏而非尸体，沿用高度上限即可
            assert all(h <= 80 for h in s["corpse_h"]), f"{name} 蹲伏帧过高"
        else:
            assert all(MIN_CORPSE_H <= h <= 80 for h in s["corpse_h"]), \
                f"{name} 尸体帧体量异常（应为 {MIN_CORPSE_H}~80px，不是扁片也不是跪姿）"
        assert s["SE_iou"] <= 0.90, f"{name} S/E 无朝向差异"
        assert s["empty"] == 0, f"{name} 存在空帧"
        if not a.dry_run:
            out = ART / name / f"{name}_Sheet.png"
            imgs[name].save(out)
    print("[done] 语义红线全部满足" + ("（dry-run，未写盘）" if a.dry_run else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
