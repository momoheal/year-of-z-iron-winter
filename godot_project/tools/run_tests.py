"""一键跑通 Godot 冒烟测试：先自动导入资产，再枚举 tests/*_smoke.gd 逐个执行。

解决「新克隆跑不了测试」的问题：
  1. 仓库 .gitignore 忽略了 .godot/ 缓存，headless -s 模式不会自动导入 PNG，
     直接在 preload 阶段大面积失败。本脚本先跑一次 `--headless --import`。
  2. 旧的 run_smoke_tests.bat 只列了 5 套老测试，本脚本自动枚举全部 *_smoke.gd。
  3. 测试全绿不代表没错误：stderr 里仍可能有 SCRIPT ERROR（每帧报错不影响 PASS），
     本脚本单独统计 stderr 的 SCRIPT ERROR / Parse Error 并计入失败。

用法：
    python godot_project/tools/run_tests.py                 # 全部
    python godot_project/tools/run_tests.py campaign gym    # 只跑名字含这些关键字的
    python godot_project/tools/run_tests.py --godot "C:\\path\\to\\godot_console.exe"
环境变量 GODOT 可指定 Godot 可执行文件（console 版优先）。
退出码 0 = 全绿且无脚本错误；否则 1（可用于 CI）。
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.abspath(os.path.join(HERE, ".."))          # godot_project/
TESTS = os.path.join(PROJ, "tests")
TIMEOUT = 240  # 单套测试超时秒数

# 候选 Godot 路径（console 版优先，headless 下输出更干净）
GODOT_CANDIDATES = [
    os.environ.get("GODOT", ""),
    r"C:\Users\admin\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
    r"C:\Users\admin\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe",
    "godot", "godot4", "godot-console", "Godot",
]


def find_godot() -> str:
    for i, a in enumerate(sys.argv):
        if a == "--godot" and i + 1 < len(sys.argv):
            return sys.argv[i + 1]
        if a.startswith("--godot="):
            return a.split("=", 1)[1]
    for c in GODOT_CANDIDATES:
        if not c:
            continue
        if os.path.isabs(c) or os.path.sep in c:
            if os.path.exists(c):
                return c
        else:
            from shutil import which
            hit = which(c)
            if hit:
                return hit
    sys.exit("找不到 Godot：用 --godot 指定，或设环境变量 GODOT。")


def run(godot: str, args: list[str], timeout: int) -> tuple[int, str, str]:
    cmd = [godot, "--headless", "--path", PROJ] + args
    try:
        p = subprocess.run(cmd, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=timeout)
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"").decode("utf-8", "replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
        return -1, out, f"TIMEOUT after {timeout}s"


def count_checks(stdout: str) -> tuple[int, int]:
    """从各种 RESULT 行里提取 (passed, failed)。"""
    m = re.search(r"RESULT:\s*(\d+)\s+passed,\s*(\d+)\s+failed", stdout)
    if m:
        return int(m.group(1)), int(m.group(2))
    m = re.search(r"\((\d+)\s+checks?\)", stdout)          # night_zones 自有格式
    if m and "PASS" in stdout:
        return int(m.group(1)), 0
    m = re.search(r"(\d+)\s+checks?\s+failed", stdout)
    if m:
        return 0, int(m.group(1))
    return 0, 0


def main() -> int:
    godot = find_godot()
    filters = [a for a in sys.argv[1:] if not a.startswith("-") and not a.endswith(".exe")]
    print(f"[godot] {godot}", flush=True)
    print(f"[proj ] {PROJ}", flush=True)

    print("\n=== 1) 导入资产（--import）===", flush=True)
    rc, out, err = run(godot, ["--import"], TIMEOUT)
    steps = len(re.findall(r"Import|import", out))
    print(f"  import 退出码 {rc}（约 {steps} 条导入日志）", flush=True)
    if rc != 0 and "ERROR" in err:
        print(err[-2000:], flush=True)

    suites = sorted(f for f in os.listdir(TESTS) if f.endswith("_smoke.gd"))
    if filters:
        suites = [s for s in suites if any(k in s for k in filters)]
    print(f"\n=== 2) 跑 {len(suites)} 套测试 ===", flush=True)

    rows = []
    all_ok = True
    for s in suites:
        t = time.time()
        rc, out, err = run(godot, ["-s", f"tests/{s}"], TIMEOUT)
        dt = time.time() - t
        passed, failed = count_checks(out)
        script_errs = len(re.findall(r"SCRIPT ERROR|Parse Error", err))
        ok = failed == 0 and script_errs == 0 and rc == 0 and passed > 0
        all_ok = all_ok and ok
        rows.append((s, passed, failed, script_errs, dt, ok))
        flag = "PASS" if ok else "FAIL"
        print(f"  [{flag}] {s:32s} {passed:4d} 通过 / {failed} 失败 / "
              f"{script_errs} 脚本错误  ({dt:.1f}s)", flush=True)
        if not ok:
            tail = (out + "\n" + err)[-1500:]
            print("    --- 输出尾部 ---\n" + "\n".join("    " + l for l in tail.splitlines()), flush=True)

    total_p = sum(r[1] for r in rows)
    total_f = sum(r[2] for r in rows)
    total_e = sum(r[3] for r in rows)
    print(f"\n=== 汇总：{total_p} 通过 / {total_f} 失败 / {total_e} 脚本错误，"
          f"共 {len(rows)} 套 ===", flush=True)
    print("结果：" + ("全部通过 ✅" if all_ok else "存在失败 ❌"), flush=True)
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
