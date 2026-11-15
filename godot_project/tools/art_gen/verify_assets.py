#!/usr/bin/env python3
"""verify_assets — 资产体检与总清单（纯标准库，零第三方依赖）。

    python verify_assets.py              # 校验 + 写出 art/asset_manifest.json
    python verify_assets.py --no-write   # 只校验，不落盘
    python verify_assets.py --quiet      # 只输出问题

为什么单独存在：check_levels.py 依赖 numpy / Pillow（经 layout / levels / gen_env），
换一台没装依赖的机器直接 ModuleNotFoundError。本脚本只用 re + struct + json + os，
任何 Python 3.8+ 都能跑，可以放心接进 CI 的第一道门。

检查项：
  FAIL  manifest 声明的 size != 图像真实尺寸（PNG IHDR / JPEG SOF 实读，不信任声明）
  FAIL  manifest 指向的文件不存在
  FAIL  pivot 出画布
  FAIL  代码 / 场景显式引用了 res://art/... 但文件不存在（测试桩 __missing__ 一类自动跳过）
  WARN  资产存在但既未登记进 manifest、也无任何代码引用（真孤儿）
  WARN  同一资产族内尺寸不统一（立绘 / 精灵表 / CG 有明确规格，才做强校验）

引用分四级，比"有/无"更能说明问题：
  code     —— 可静态确定：完整路径、完整文件名，或"前缀常量 + 后缀字面量"拼接
  runtime  —— 由 printf 模板拼出（PRT_%s_%s.png），参数在运行时决定，静态不可判定
  manifest —— 只被 night_*_manifest.json 登记（运行时经 manifest 动态取用）
  none     —— 三者皆无 = 孤儿

为什么必须有 runtime 这一级：NightMonuments.portrait_path() 用
`PRT_DIR + "PRT_%s_%s.png" % [who, mood]` 拼头像，mood 取值里 wry（冷嘲）
在剧本中出现 47 次。只认完整路径的话，整套 _Wry 立绘会被误判成孤儿；
反过来硬当成 code 又会掩盖真孤儿。单列一级，既不失守也不撒谎。
同理，Campaign.MATE_TEX 是"前缀常量 + Walk0/Walk1 后缀"，前缀与后缀
两个字面量都在代码里，属于可确定，算 code。

输出：art/asset_manifest.json —— 机器可读的唯一事实源，给替换流程与 AI 出图做守门。
"""
from __future__ import annotations

import json
import os
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.abspath(os.path.join(HERE, "..", ".."))
ART = os.path.join(PROJ, "art")
OUT = os.path.join(ART, "asset_manifest.json")

# 代码里视为"真实引用"的来源（不含 manifest —— 清单登记 != 运行时使用）
CODE_EXTS = (".gd", ".tscn", ".tres")
# 不参与扫描的文件
SKIP_NAMES = {"asset_manifest.json"}
# 测试里故意构造的缺失路径，不是真缺陷
STUB_PAT = re.compile(r"__(?:missing|nonexistent|dummy|placeholder|test)__", re.I)
# 媒体扩展名
MEDIA_EXTS = (".png", ".jpg", ".jpeg", ".wav", ".ogg", ".mp3")
# res://art/... 的字符串字面量（不完整路径也算，如前缀常量或模板）
RES_LIT = re.compile(r'"(res://art/[^"\\]*)"')
# printf 占位符：%s %d %02d
PLACEHOLDER = re.compile(r"%[sd]|%0?\d+d")
# 任意短字符串字面量（用来确认拼接用的后缀，如 "Walk0"）
SIMPLE_LIT = re.compile(r'"([^"\\\n]{1,64})"')

FAILS: list[str] = []
WARNS: list[str] = []


def fail(msg: str) -> None:
    FAILS.append(msg)


def warn(msg: str) -> None:
    WARNS.append(msg)


# ---------------------------------------------------------------------------
# 1. 真实尺寸：PNG 读 IHDR，JPEG 扫 SOF
# ---------------------------------------------------------------------------
def png_size(path: str):
    with open(path, "rb") as f:
        head = f.read(24)
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    if head[12:16] != b"IHDR":
        raise ValueError("PNG missing IHDR")
    w, h = struct.unpack(">II", head[16:24])
    return int(w), int(h)


def jpg_size(path: str):
    with open(path, "rb") as f:
        data = f.read()
    if data[:2] != b"\xff\xd8":
        raise ValueError("not a JPEG")
    i, n = 2, len(data)
    while i + 9 < n:
        if data[i] != 0xFF:
            i += 1
            continue
        marker = data[i + 1]
        if marker == 0xFF:
            i += 1
            continue
        if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
            i += 2
            continue
        seg_len = struct.unpack(">H", data[i + 2:i + 4])[0]
        if 0xC0 <= marker <= 0xCF and marker not in (0xC4, 0xC8, 0xCC):
            h, w = struct.unpack(">HH", data[i + 5:i + 9])
            return int(w), int(h)
        i += 2 + seg_len
    raise ValueError("no SOF marker found")


def image_size(path: str):
    ext = os.path.splitext(path)[1].lower()
    try:
        if ext == ".png":
            return png_size(path)
        if ext in (".jpg", ".jpeg"):
            return jpg_size(path)
    except Exception as exc:                                   # noqa: BLE001
        fail(f"读不到图像尺寸：{os.path.relpath(path, PROJ)}（{exc}）")
    return None


# ---------------------------------------------------------------------------
# 2. 资产族：用途决定规格，比一级目录更准
# ---------------------------------------------------------------------------
def family_of(rel: str) -> str:
    parts = rel.split("/")
    top = parts[0]
    base = parts[-1]
    if top == "10_characters":
        if "/portraits/" in "/" + rel:
            return "concept" if base.endswith("_Concept.png") else "portrait"
        return "character_sheet"
    if top == "20_tileset":
        return "tileset"
    if top == "30_props":
        return "prop"
    if top == "50_vfx":
        return "vfx"
    if top == "60_ui":
        return "cg" if "/cg/" in "/" + rel else "ui"
    if top == "70_audio":
        return "audio"
    return "other"


# 有明确规格、值得做强一致的资产族
STRICT_FAMILIES = ("portrait", "character_sheet", "cg")


# ---------------------------------------------------------------------------
# 3. 扫描
# ---------------------------------------------------------------------------
def scan_assets() -> dict:
    out = {}
    for root, _dirs, files in os.walk(ART):
        for fn in files:
            if fn.endswith(".import") or fn in SKIP_NAMES:
                continue
            if not fn.lower().endswith(MEDIA_EXTS):
                continue
            ap = os.path.join(root, fn)
            scan = os.path.relpath(ap, ART).replace("\\", "/")
            out[scan] = ap
    return out


def collect_code_text() -> str:
    chunks = []
    for root, dirs, files in os.walk(PROJ):
        dirs[:] = [d for d in dirs if d not in (".git", ".godot", "__pycache__")]
        for fn in files:
            if not fn.endswith(CODE_EXTS):
                continue
            try:
                with open(os.path.join(root, fn), encoding="utf-8", errors="ignore") as f:
                    chunks.append(f.read())
            except OSError:
                continue
    return "\n".join(chunks)


def build_ref_rules(code_text: str):
    """从代码里抽出三类"非完整路径"的加载规则。

    返回 (prefixes, path_templates, name_templates, simple_lits)：
      prefixes        —— 以 _ 或 / 结尾的路径常量，如 "res://art/30_props/PRP_Ash_"
      path_templates  —— 含 res:// 的完整路径模板，按全路径匹配
      name_templates  —— 裸文件名模板（"PRT_%s_%s.png" 配目录常量用），按文件名匹配
      simple_lits     —— 代码里出现过的全部短字符串字面量，用来确认后缀拼接口令
    """
    prefixes, path_tpl, name_tpl = [], [], []
    for lit in sorted(set(RES_LIT.findall(code_text))):
        if PLACEHOLDER.search(lit):
            path_tpl.append((_to_regex(lit), lit))
        elif lit.endswith(("_", "/")):
            prefixes.append(lit)
    for lit in sorted(set(SIMPLE_LIT.findall(code_text))):
        if "/" in lit or not PLACEHOLDER.search(lit):
            continue
        if not lit.lower().endswith(MEDIA_EXTS):
            continue
        name_tpl.append((_to_regex(lit), lit))
    return prefixes, path_tpl, name_tpl, set(SIMPLE_LIT.findall(code_text))


def _to_regex(lit: str):
    buf, last = [], 0
    for m in PLACEHOLDER.finditer(lit):
        buf.append(re.escape(lit[last:m.start()]))
        buf.append(".+?")
        last = m.end()
    buf.append(re.escape(lit[last:]))
    return re.compile("^" + "".join(buf) + "$")


def prefix_concat_hit(res: str, prefixes, simple_lits) -> bool:
    """前缀常量 + 后缀字面量：如 PRP_Ash_ + "Walk0" + ".png"。

    两个条件都要满足，缺一不算：只看前缀会把整个目录都标成"已引用"，
    反而掩盖真孤儿；后缀必须真是代码里的字面量（"Walk0"），凭空猜不出来。
    """
    for p in prefixes:
        if not res.startswith(p):
            continue
        rest = res[len(p):]
        if "/" in rest:
            continue
        if rest.rsplit(".", 1)[0] in simple_lits:
            return True
    return False


def template_hit(res: str, name: str, path_tpl, name_tpl):
    """printf 模板匹配，返回命中的模板字面量（用于在清单里留痕）。"""
    for rx, lit in path_tpl:
        if rx.match(res):
            return lit
    for rx, lit in name_tpl:
        if rx.match(name):
            return lit
    return None


def load_manifests():

    decl, names = {}, []
    for fn in sorted(os.listdir(ART)):
        if not (fn.startswith("night_") and fn.endswith("_manifest.json")):
            continue
        names.append(fn)
        try:
            with open(os.path.join(ART, fn), encoding="utf-8") as f:
                man = json.load(f)
        except (OSError, ValueError) as exc:
            fail(f"manifest 读不了：{fn}（{exc}）")
            continue
        for key, v in man.items():
            if not isinstance(v, dict) or "path" not in v:
                continue
            prev = decl.get(key)
            if prev and prev["path"] != v["path"]:
                warn(f"manifest 键冲突：{key} 在 {prev['manifest']} 与 {fn} 指向不同文件")
            decl[key] = {"path": v["path"], "size": v.get("size"),
                         "pivot": v.get("pivot"), "manifest": fn}
    return decl, names


# ---------------------------------------------------------------------------
# 4. 主流程
# ---------------------------------------------------------------------------
def main(argv) -> int:
    write = "--no-write" not in argv
    quiet = "--quiet" in argv

    assets = scan_assets()
    code_text = collect_code_text()
    decl, man_names = load_manifests()
    if not assets:
        fail(f"art/ 下没扫到任何资产，路径可能不对：{ART}")

    entries = {}
    prefixes, path_tpl, name_tpl, simple_lits = build_ref_rules(code_text)
    for rel, ap in sorted(assets.items()):
        real = image_size(ap) if rel.lower().endswith((".png", ".jpg", ".jpeg")) else None
        res = "res://art/" + rel
        base = os.path.basename(rel)
        ref_by = None
        tpl = None
        if res in code_text or base in code_text:
            ref = "code"
            ref_by = "完整路径" if res in code_text else "完整文件名"
        elif prefix_concat_hit(res, prefixes, simple_lits):
            ref = "code"
            ref_by = "前缀常量+后缀字面量"
        elif any(rel in v["path"] for v in decl.values()):
            # manifest 是白纸黑字的契约，排在 runtime 之前：
            # 否则巧合撞上 %s 模板就会被降级成"运行时可加载"，丢掉已登记的确定性
            ref = "manifest"
            ref_by = "manifest 登记"
        elif (tpl := template_hit(res, base, path_tpl, name_tpl)):
            ref = "runtime"
            ref_by = tpl
        else:
            ref = "none"
        entries[rel] = {
            "path": res,
            "family": family_of(rel),
            "real_size": list(real) if real else None,
            "declared_size": None,
            "pivot": None,
            "manifest": None,
            "ref": ref,
            "ref_by": ref_by,
            "bytes": os.path.getsize(ap),
        }

    # manifest 声明 vs 真实 -------------------------------------------------
    for key, v in sorted(decl.items()):
        rel = os.path.normpath(v["path"].replace("res://art/", "").replace("res://", "art/"))
        rel = rel.replace("\\", "/")
        if rel.startswith("art/"):
            rel = rel[4:]
        if rel not in entries:
            fail(f"manifest 键 {key} 指向的文件不存在：{v['path']}（{v['manifest']}）")
            continue
        e = entries[rel]
        e["declared_size"], e["pivot"], e["manifest"] = v["size"], v["pivot"], v["manifest"]
        if v["size"] and e["real_size"] and list(v["size"]) != list(e["real_size"]):
            fail(f"尺寸不一致：{key} 声明 {v['size']}，实际 {e['real_size']}（{rel}）")
        if v["pivot"] and v["size"]:
            px, py = v["pivot"]
            w, h = v["size"]
            if not (0 <= px <= w and 0 <= py <= h):
                fail(f"pivot 出画布：{key} pivot={v['pivot']} size={v['size']}")

    # 代码引用但文件缺失 ----------------------------------------------------
    for root, dirs, files in os.walk(PROJ):
        dirs[:] = [d for d in dirs if d not in (".git", ".godot", "__pycache__")]
        for fn in files:
            if not fn.endswith(CODE_EXTS):
                continue
            fp = os.path.join(root, fn)
            try:
                with open(fp, encoding="utf-8", errors="ignore") as f:
                    txt = f.read()
            except OSError:
                continue
            for m in set(re.findall(r"res://art/[A-Za-z0-9_./-]+\.(?:png|jpg|jpeg|wav|ogg)", txt)):
                if STUB_PAT.search(m):
                    continue
                if not os.path.exists(os.path.join(PROJ, m.replace("res://", ""))):
                    fail(f"引用了不存在的资产：{m}（{os.path.relpath(fp, PROJ)}）")

    # 族内尺寸一致性 --------------------------------------------------------
    for fam in STRICT_FAMILIES:
        sizes = {}
        for rel, e in entries.items():
            if e["family"] == fam and e["real_size"]:
                sizes.setdefault(tuple(e["real_size"]), []).append(rel)
        if len(sizes) > 1:
            detail = "；".join(f"{w}x{h}×{len(v)}（例：{v[0]}）"
                               for (w, h), v in sorted(sizes.items(), key=lambda kv: -len(kv[1])))
            warn(f"{fam} 族尺寸不统一：{detail}")

    # 孤儿 ------------------------------------------------------------------
    orphans = sorted(r for r, e in entries.items() if e["ref"] == "none")
    runtime = sorted(r for r, e in entries.items() if e["ref"] == "runtime")

    # 写清单 ----------------------------------------------------------------
    manifest = {
        "_meta": {
            "generated_by": "tools/art_gen/verify_assets.py",
            "asset_count": len(entries),
            "manifest_files": man_names,
            "ref_levels": {
                "code": "可静态确定：完整路径 / 完整文件名 / 前缀常量+后缀字面量",
                "runtime": "printf 模板拼接（如 PRT_%s_%s.png），参数运行时决定",
                "manifest": "仅 night_*_manifest.json 登记，运行时经 manifest 取用",
                "none": "孤儿：无任何引用",
            },
            "note": "real_size 由 PNG IHDR / JPEG SOF 实读；declared_size 来自 night_*_manifest.json。"
                    "ref 分级是静态分析的结论；runtime 级需人工确认参数取值是否覆盖到。",
        },
        "assets": entries,
    }
    if write:
        with open(OUT, "w", encoding="utf-8") as f:
            json.dump(manifest, f, ensure_ascii=False, indent=1, sort_keys=True)

    # 报告 ------------------------------------------------------------------
    if not quiet:
        print(f"清单{'已写出' if write else '未写出'}：{os.path.relpath(OUT, PROJ)}")
        print(f"资产 {len(entries)} 条｜manifest {len(man_names)} 份｜声明键 {len(decl)} 个")
        fam = {}
        for e in entries.values():
            fam[e["family"]] = fam.get(e["family"], 0) + 1
        print("族：" + "  ".join(f"{k}={v}" for k, v in sorted(fam.items())))
        print("引用：" + "  ".join(f"{k}={sum(1 for e in entries.values() if e['ref']==k)}"
                                   for k in ("code", "runtime", "manifest", "none")))
        if runtime:
            by_tpl = {}
            for r in runtime:
                by_tpl.setdefault(entries[r]["ref_by"], []).append(r)
            print(f"模板可加载 {len(runtime)} 条（参数运行时定，列出来供人工核对）：")
            for tpl, rs in sorted(by_tpl.items()):
                print(f"   {tpl} → {len(rs)} 条：{', '.join(os.path.basename(x) for x in rs[:6])}"
                      + (" …" if len(rs) > 6 else ""))
        if orphans:
            print(f"孤儿 {len(orphans)} 条（前 20）：")
            for r in orphans[:20]:
                print("   ·", r)
    for w in WARNS:
        print("  warn:", w)
    if FAILS:
        print(f"VERIFY_ASSETS FAIL（{len(FAILS)} 项）")
        for f_ in FAILS:
            print("  -", f_)
        return 1
    print(f"VERIFY_ASSETS PASS（{len(entries)} 条资产）")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
