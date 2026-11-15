#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""apply_v24.py — 根治「弹匣 / 尸体」两处画面错误（2026-11-15）。

背景（见 docs/art/2026-11-14_精灵表v2复核.md 第八节）：
  v2.3 把亮银大月牙退回标准深色弹匣，等于把「像布带」改成「看不见」；
  尸体用纵向 x1.4 拉伸把 30px 扁片拉成 43px，但源图姿势本来就是四肢撑地爬行，
  拉伸只改变体量不改变语义。用户判定「弹夹和尸体都是错的」。

v2.4 的做法是重新出图（.artwork/src_gpt/v2.4/，5 张），不再做几何/调色硬凑：

  1. 弹匣：正面双手持枪时 AK 弧弹匣被握把的手挡在深色制服前，物理上读不出来。
     新源图让弹匣从机匣下方垂出、凸到身体轮廓之外的白色背景上，标准尺寸、
     深色发蓝钢 + 肋纹 + 一道细亮边高光，靠轮廓与材质而非整体提亮获得可读性。
  2. 尸体：新源图是真正瘫软横躺的死人（四肢放松、头歪一侧），不再是爬行/俯卧撑；
     三具姿势互不相同，视角与站立帧同为略俯视 3/4。
  3. 体量：横躺源图宽高比 1.4~2.2，直接按 64px 宽等比缩放会退回 30px 扁片。
     这里用**轻度负角旋转**（-10° / -15°）让对角躺姿的包围盒变高，
     是纯几何旋转，不拉伸人形；最终 64x45 / 64x45 / 64x48。

只改 4 张 *_Sheet.png 中的 5 类单元格，基线固定为
.artwork/backup/v2.3_出图前_2026-11-15/，因此完全幂等、可复现。
不动 CHR_01（撬棍已合格）、CHR_05 E 行 c0-8 真侧面帧、manifest / 场景 / 代码接线。

--mag-side（可选，默认关闭）：
  正面双手持枪时，标准 AK 弧弹匣在 64px 帧里叠在同色制服上，几乎读不出来。
  开启后把 CHR_05 c9/c10 换成 90° 侧面「站姿平瞄」帧，弹匣落到白背景前形成剪影，
  小尺寸下清晰可读。代价是 c9/c10 从正面朝向变成侧面（E 行更连贯，S/N 行跳转），
  属需要用户拍板的取舍，所以默认不启用。

用法（任意工作目录）：
    python apply_v24.py [--dry-run] [--mag-side]
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
BASE = PROJ.parent / ".artwork" / "backup" / "v2.3_出图前_2026-11-15"
SRC = PROJ.parent / ".artwork" / "src_gpt" / "v2.4"
sys.path.insert(0, str(PROJ / "tools"))
from sprite_sheet_build import ensure_alpha  # noqa: E402

CW, CH = 72, 112
PIVOT_X, PIVOT_Y = 36, 107
MAX_W = 64                 # check_chars.py 红线 <= 66，留 2px 余量
MIN_CORPSE_H, MAX_CORPSE_H = 40, 75

FILES = {
    "mag_aim":   "IMAGE_1_is_the_current_game_sp_2026-11-15T08-22-07.png",
    "mag_low":   "IMAGE_1_is_the_current_game_sp_2026-11-15T08-25-53.png",
    "corpse_03": "IMAGE_1_shows_the_standing_ver_2026-11-15T08-22-20.png",
    "corpse_04": "IMAGE_1_shows_the_standing_ver_2026-11-15T08-26-04.png",
    "corpse_05": "IMAGE_1_shows_the_standing_ver_2026-11-15T08-26-17.png",
    # --mag-side 使用的 90° 侧面站姿平瞄帧（弹匣对白背景，剪影可读）
    "mag_side":  "IMAGE_1_is_a_game_sprite_of_a__2026-11-15T08-51-38.png",
}

# (表名, 列, 源图 key, 目标高, 旋转角)；三行一律共用同一帧（敌人红线）
PLAN: list[tuple[str, int, str, int | None, float]] = [
    ("CHR_03_Rabid",    11, "corpse_03", None, -15.0),
    ("CHR_04_HalfHuman", 11, "corpse_04", None,   0.0),
    ("CHR_05_OSK",       9, "mag_aim",   104,   0.0),
    ("CHR_05_OSK",      10, "mag_low",   104,   0.0),
    ("CHR_05_OSK",      11, "corpse_05", None, -10.0),
]
SHEETS = sorted({p[0] for p in PLAN})


def body_of(key: str, angle: float) -> Image.Image:
    """白底抠图 → 取主体 → 轻度旋转 → 重新取包围盒。旋转用透明填充，不带白角。"""
    path = SRC / FILES[key]
    if not path.exists():
        raise FileNotFoundError(f"缺少 v2.4 出图：{path}")
    im = ensure_alpha(Image.open(path).convert("RGBA"))
    im = crop_body(im)
    if angle:
        im = im.rotate(angle, resample=Image.BICUBIC, expand=True)
        im = crop_body(im)
    return im


def crop_body(im: Image.Image) -> Image.Image:
    a = np.array(im)[..., 3]
    ys, xs = np.where(a > 96)
    if ys.size < 100:
        raise ValueError("抠图后主体过小")
    return im.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def fit(body: Image.Image, target_h: int | None) -> Image.Image:
    w, h = body.size
    k = (target_h / h) if target_h else 1.0
    k = min(k, MAX_W / w)
    return body.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)


def put(img: Image.Image, r: int, c: int, body: Image.Image) -> None:
    """清空目标格后贴入：水平居中、底边贴 y=107。必须先清空，否则 alpha 叠加。"""
    w, h = body.size
    px, py = PIVOT_X - w // 2, PIVOT_Y - (h - 1)
    if px < 0 or py < 0 or px + w > CW or py + h > CH:
        raise ValueError(f"帧 {r}-{c} 尺寸越界：{body.size} @ ({px},{py})")
    img.paste(Image.new("RGBA", (CW, CH), (0, 0, 0, 0)), (c * CW, r * CH))
    img.alpha_composite(body, (c * CW + px, r * CH + py))


def stats(img: Image.Image) -> dict:
    """用与 check_chars.py 相同的 alpha>16 阈值量测，避免边缘半透明造成误差。"""
    a = np.array(img)[..., 3]
    widths, tail_h, tail_ratio, empty = [], [], [], 0
    for r in range(3):
        for c in range(12):
            m = a[r * CH:(r + 1) * CH, c * CW:(c + 1) * CW] > 16
            ys, xs = np.where(m)
            if ys.size == 0:
                empty += 1
                continue
            w = int(xs.max() - xs.min() + 1)
            h = int(ys.max() - ys.min() + 1)
            widths.append(w)
            if c == 11:
                tail_h.append(h)
                tail_ratio.append(round(w / max(1, h), 2))
    ious = []
    for c in range(9):
        m0 = a[0:CH, c * CW:(c + 1) * CW] > 16
        m1 = a[CH:2 * CH, c * CW:(c + 1) * CW] > 16
        uni = float((m0 | m1).sum())
        ious.append(float((m0 & m1).sum() / uni) if uni else 1.0)
    base = a[0:CH, 9 * CW:12 * CW]
    unified = all(np.array_equal(base, a[r * CH:(r + 1) * CH, 9 * CW:12 * CW])
                  for r in (1, 2))
    return {"max_w": max(widths), "tail_h": tail_h, "tail_ratio": tail_ratio,
            "SE_iou": round(float(np.mean(ious)), 3), "empty": empty,
            "unified": unified}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--mag-side", action="store_true",
                    help="CHR_05 c9/c10 改用 90° 侧面站姿平瞄帧（弹匣对白背景可读）")
    a = ap.parse_args()

    imgs = {}
    for name in SHEETS:
        base = BASE / f"{name}_Sheet.png"
        if not base.exists():
            raise FileNotFoundError(f"缺少 v2.3 基线：{base}")
        imgs[name] = Image.open(base).convert("RGBA")

    plan = list(PLAN)
    if a.mag_side:
        # 侧面帧只有一张瞄准姿，c9/c10 共用；保持 c9-11 三行统一红线。
        plan = [p for p in plan if not (p[0] == "CHR_05_OSK" and p[1] in (9, 10))]
        plan += [("CHR_05_OSK", 9, "mag_side", 104, 0.0),
                 ("CHR_05_OSK", 10, "mag_side", 104, 0.0)]
        print("[--mag-side] c9/c10 → 90° 侧面站姿平瞄（弹匣剪影可读）")

    for sheet, col, key, target_h, angle in plan:
        body = fit(body_of(key, angle), target_h)
        if col == 11:
            assert MIN_CORPSE_H <= body.height <= MAX_CORPSE_H, \
                f"{key} 尸体帧高 {body.height} 越界（应为 {MIN_CORPSE_H}~{MAX_CORPSE_H}）"
            assert body.width / body.height >= 1.15, \
                f"{key} 尸体不够横向（w/h={body.width / body.height:.2f}）"
        print(f"  [{key:9s}] rot={angle:+.0f}° → 帧 {body.width}x{body.height}")
        for r in range(3):
            put(imgs[sheet], r, col, body)

    print(f"[apply] 共替换 {len(plan) * 3} 个单元格")
    for name in SHEETS:
        s = stats(imgs[name])
        print(f"  {name:20s} maxW={s['max_w']:2d} tailH={s['tail_h']} "
              f"tailW/H={s['tail_ratio']} S/E IoU={s['SE_iou']:.3f} "
              f"三行统一={s['unified']} 空帧={s['empty']}")
        assert s["max_w"] <= 66, f"{name} 内容超宽"
        assert s["empty"] == 0, f"{name} 存在空帧"
        assert s["SE_iou"] <= 0.90, f"{name} S/E 无朝向差异"
        if name != "CHR_01_Aleksei":
            assert all(MIN_CORPSE_H <= h <= MAX_CORPSE_H for h in s["tail_h"]), \
                f"{name} 尸体帧体量异常：{s['tail_h']}"
            assert min(s["tail_ratio"]) >= 1.15, f"{name} 尸体非横向：{s['tail_ratio']}"
            assert s["unified"], f"{name} c9-11 三行不统一"
        if not a.dry_run:
            imgs[name].save(ART / name / f"{name}_Sheet.png")
    print("[done] 语义红线全部满足" + ("（dry-run，未写盘）" if a.dry_run else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
