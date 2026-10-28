"""角色素材一致性 / 可用性检查（CHR_01_Aleksei / CHR_05_OSK + night_explore.tscn 接线）。

用法（在 godot_project/tools/art_gen 下）：
    python3 check_chars.py

检查项（任一失败 → 退出码 1，杜绝“不一致”混进场景）：
  A. 硬规格：文件名/路径、576×336、RGBA、8 列 × 3 行、每帧 72×112、pivot (36,108)
  B. 可用性：24 帧均非空；脚底落在地面线；帧内容不越出单元格（不串帧）；背景透明
  C. 一致性：站立帧高/落地线一致；S/E/N 剪影量级一致；两张表地面线互相一致；
     冷调低饱和风格带；阿列克谢大衣为深蓝黑、ОСК 为中性铅灰
  D. 装配：manifest 尺寸/pivot/frames 与实际文件一致；night_explore.tscn 引用存在、
     hframes/vframes/offset 与精灵表布局一致
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.abspath(os.path.join(HERE, "..", ".."))

FW, FH = 72, 112
GX, GY = 8, 3
PIVOT = (36, 108)
SHEET_W, SHEET_H = FW * GX, FH * GY

SHEETS = {
    "CHR_01_Aleksei_Sheet": os.path.join(PROJ, "art", "10_characters", "CHR_01_Aleksei", "CHR_01_Aleksei_Sheet.png"),
    "CHR_05_OSK_Sheet": os.path.join(PROJ, "art", "10_characters", "CHR_05_OSK", "CHR_05_OSK_Sheet.png"),
}
SCENE = os.path.join(PROJ, "scenes", "night_explore.tscn")
MANIFEST = os.path.join(PROJ, "art", "night_yard_manifest.json")

_pass = 0
_fail: list[str] = []


def check(cond: bool, name: str, detail: str = "") -> None:
    global _pass
    if cond:
        _pass += 1
        print(f"  PASS  {name}")
    else:
        _fail.append(name + (f" — {detail}" if detail else ""))
        print(f"  FAIL  {name}  {detail}")


def frames_of(img: Image.Image):
    """按 8×3 切帧，返回 24 个 (row, col, rgba-ndarray)。"""
    a = np.asarray(img, np.float32)
    out = []
    for r in range(GY):
        for c in range(GX):
            out.append((r, c, a[r * FH:(r + 1) * FH, c * FW:(c + 1) * FW]))
    return out


def bbox_of(cell: np.ndarray):
    al = cell[..., 3] > 16
    ys, xs = np.where(al)
    if ys.size == 0:
        return None
    return xs.min(), ys.min(), xs.max(), ys.max()


def main() -> int:
    print("== character sheets: spec & usability ==")
    data = {}
    for key, path in SHEETS.items():
        ok = os.path.isfile(path)
        check(ok, f"{key}: 文件存在", path)
        if not ok:
            continue
        img = Image.open(path)
        check(img.mode == "RGBA", f"{key}: RGBA 透明通道", img.mode)
        check(img.size == (SHEET_W, SHEET_H), f"{key}: 画布 {SHEET_W}x{SHEET_H}",
              f"{img.size[0]}x{img.size[1]}")
        cells = frames_of(img)
        data[key] = cells

        empty = [(r, c) for r, c, a in cells if (a[..., 3] > 16).mean() < 0.004]
        check(not empty, f"{key}: 24 帧均非空", str(empty[:4]))

        # 脚底落地线：站立帧（列 0-4）alpha 下沿应贴住 pivot y=108（±4px）
        bad_feet, bottoms = [], []
        for r, c, a in cells:
            bb = bbox_of(a)
            if bb is None:
                continue
            bottoms.append(bb[3])
            if c <= 4 and not (PIVOT[1] - 5 <= bb[3] <= PIVOT[1] + 4):
                bad_feet.append((r, c, bb[3]))
        check(not bad_feet, f"{key}: 站立帧脚底贴住 pivot y={PIVOT[1]}（±5）", str(bad_feet[:4]))
        check(max(bottoms) - min(bottoms) <= 8, f"{key}: 全表落地线离散 ≤ 8px",
              f"spread={max(bottoms) - min(bottoms)}")

        # 不串帧：单元格边缘 1px 不应有邻居“漏”进来的实心像素（内容贴边 < 22%）
        bleed = []
        for r, c, a in cells:
            al = a[..., 3] > 16
            edge = max(al[0, :].mean(), al[-1, :].mean(), al[:, 0].mean(), al[:, -1].mean())
            if edge > 0.22:
                bleed.append((r, c, round(float(edge), 2)))
        check(not bleed, f"{key}: 帧内容不越界（不串帧）", str(bleed[:4]))

        # 顶边留白（头顶不出血到上一帧）
        tops = [bbox_of(a)[1] for _, _, a in cells if bbox_of(a)]
        check(min(tops) >= 2, f"{key}: 头顶留白 ≥ 2px", f"min_top={min(tops)}")

        # 背景透明（四角）
        arr = np.asarray(img, np.float32)
        corners = [arr[0, 0, 3], arr[0, -1, 3], arr[-1, 0, 3], arr[-1, -1, 3]]
        check(max(corners) < 8, f"{key}: 背景透明（无烘焙底色/投影）", str(corners))

    print("== character sheets: cross-frame consistency ==")
    for key, cells in data.items():
        # 站立剪影面积（列 0）三行同量级
        areas = [float((a[..., 3] > 16).mean()) for r, c, a in cells if c == 0]
        check(max(areas) <= min(areas) * 1.55 + 0.02, f"{key}: S/E/N 待机剪影量级一致",
              "areas=" + str([round(x, 3) for x in areas]))
        # 走路帧（列 1-4）高度稳定
        hs = []
        for r, c, a in cells:
            if 1 <= c <= 4:
                bb = bbox_of(a)
                hs.append(bb[3] - bb[1])
        check(max(hs) - min(hs) <= 14, f"{key}: 行走帧高度稳定", f"spread={max(hs) - min(hs)}")

    if len(data) == 2:
        b1 = [bbox_of(a)[3] for _, _, a in data["CHR_01_Aleksei_Sheet"] if bbox_of(a)]
        b2 = [bbox_of(a)[3] for _, _, a in data["CHR_05_OSK_Sheet"] if bbox_of(a)]
        check(abs(sum(b1) / len(b1) - sum(b2) / len(b2)) <= 3.0,
              "两角色地面线互相一致（同场景同地平）",
              f"{sum(b1)/len(b1):.1f} vs {sum(b2)/len(b2):.1f}")

    print("== palette / style band ==")
    for key, path in SHEETS.items():
        if not os.path.isfile(path):
            continue
        a = np.asarray(Image.open(path).convert("RGBA"), np.float32)
        px = a[a[..., 3] > 200][:, :3] / 255.0
        mx, mn = px.max(1), px.min(1)
        sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
        check(float(sat.mean()) < 0.42, f"{key}: 冷调低饱和（mean sat {sat.mean():.2f} < 0.42）",
              f"{sat.mean():.2f}")
        if "Aleksei" in key:
            coat = px[(px[:, 2] > px[:, 0])]                      # 偏蓝像素（大衣）
            check(len(coat) > 0.15 * len(px) and float(coat[:, 2].mean() - coat[:, 0].mean()) > 0.04,
                  f"{key}: 大衣为深蓝-黑（非旧绿棉服）",
                  f"blue_px={len(coat)/len(px):.2f}")
        else:
            grey = px[abs(px[:, 0] - px[:, 2]) < 0.08]
            check(len(grey) > 0.45 * len(px), f"{key}: 铅灰中性色为主（防护服）",
                  f"neutral={len(grey)/len(px):.2f}")

    print("== manifest + night_explore.tscn wiring ==")
    man = json.load(open(MANIFEST, encoding="utf-8"))
    # 全量对账：manifest 每条记录与磁盘文件尺寸一致（场景碰撞/遮挡形状按此硬编码）
    bad_all = []
    for k, e in man.items():
        p = os.path.join(PROJ, e["path"][len("res://"):])
        if not os.path.isfile(p):
            bad_all.append((k, "missing"))
            continue
        if "size" in e:
            sz = Image.open(p).size
            if tuple(e["size"]) != sz:
                bad_all.append((k, f"{e['size']} vs {list(sz)}"))
    check(not bad_all, f"manifest 全量对账（{len(man)} 条资产尺寸/存在性一致）", str(bad_all[:4]))
    for key, path in SHEETS.items():
        e = man.get(key)
        check(e is not None, f"manifest 有 {key} 条目")
        if e:
            img = Image.open(path)
            check(tuple(e["size"]) == img.size, f"manifest 尺寸与 {key} 实际一致",
                  f"{e['size']} vs {list(img.size)}")
            check(tuple(e["pivot"]) == PIVOT, f"manifest pivot 为 {PIVOT}", str(e["pivot"]))
            check(e.get("hframes") == GX and e.get("vframes") == GY,
                  f"manifest {key} h/vframes = {GX}/{GY}",
                  f"{e.get('hframes')}/{e.get('vframes')}")
            rel = os.path.relpath(path, PROJ).replace("\\", "/")
            check(e["path"] == "res://" + rel, f"manifest 路径与文件名不变", e["path"])

    if os.path.isfile(SCENE):
        t = open(SCENE, encoding="utf-8").read()
        import re
        missing = [p for p in set(re.findall(r'path="(res://[^"]+)"', t))
                   if not os.path.isfile(os.path.join(PROJ, p[len("res://"):]))]
        check(not missing, "night_explore.tscn 全部 res:// 引用存在", str(missing[:4]))
        for key in SHEETS:
            rel = "res://" + os.path.relpath(SHEETS[key], PROJ).replace("\\", "/")
            check(f'path="{rel}"' in t, f"模板引用 {key}（同名覆盖即替换）", rel)
        # 角色 Sprite2D：hframes/vframes/offset 与精灵表布局、pivot 一致
        ext = dict(re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', t))
        id_of = {v: k for k, v in ext.items()}          # ExtResource id -> res 路径
        blocks = ["[node " + b for b in t.split("\n[node ")[1:]]

        def _tex_ids(block: str) -> list[str]:
            return re.findall(r'texture = ExtResource\("([^"]+)"\)', block)

        char_sp = [b for b in blocks
                   if 'type="Sprite2D"' in b.split("\n")[0]
                   and any("CHR_01_Aleksei_Sheet" in id_of.get(i, "") or
                           "CHR_05_OSK_Sheet" in id_of.get(i, "") for i in _tex_ids(b))]
        check(len(char_sp) >= 3, "模板中角色 Sprite 节点 ≥ 3（1 玩家 + 2 ОСК）", str(len(char_sp)))
        bad = [b.split("\n")[0] for b in char_sp
               if "hframes = 8" not in b or "vframes = 3" not in b
               or f"offset = Vector2(0, {- (PIVOT[1] - FH // 2)})" not in b]
        check(not bad, f"角色 Sprite hframes=8 vframes=3 offset=(0,{-(PIVOT[1]-FH//2)})（pivot {PIVOT}）",
              str(bad[:2]))
    else:
        check(False, "night_explore.tscn 存在", SCENE)

    print(f"==== RESULT: {_pass} passed, {len(_fail)} failed ====")
    for f in _fail:
        print("  FAILED:", f)
    if _fail:
        print("CHARS_CHECK_FAIL")
        return 1
    print("CHARS_CHECK_PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
