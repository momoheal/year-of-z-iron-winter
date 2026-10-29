"""layout.py — 关卡布局的兼容入口（P4.1 之后，真正的数据在 levels/<id>.py）。

老代码里的 `import layout as LY` / `LY.PROPS` 一行都不用改：本模块在导入时把
「当前关卡」的数据灌进自己的名字空间。当前关卡按下面的顺序决定：

    1. `LY.activate_level("marshalling")`（gen_assets.py / build_scene.py 的 --level 走这条）
    2. 环境变量 `NOVORSK_LEVEL`
    3. 默认 `yard`（L03 夜间广轨货场 = 已经出过图的那一版）

新地图：在 levels/ 下加一个纯数据模块，并在 levels.LEVELS 里登记。
"""
from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import levels  # noqa: E402

LEVEL_ID = ""            # 当前关卡 id（activate_level 设置）
_KEYS: set = set()       # 当前灌进来的关卡属性名（换关卡时用来清掉上一关独有的字段）


def activate_level(name: str):
    """把 levels/<name>.py 的数据灌进本模块，返回规格模块。"""
    global LEVEL_ID, _KEYS
    spec = levels.load(name)
    attrs = levels.attrs_of(spec)
    g = globals()
    for k in list(_KEYS):
        if k not in attrs:
            g.pop(k, None)
    g.update(attrs)
    g["LEVEL_ID"] = name
    LEVEL_ID = name
    _KEYS = set(attrs) | {"LEVEL_ID"}
    return spec


def has(name: str, default=None):
    """读可选的关卡字段（老关卡没写的字段一律走 default）。"""
    return globals().get(name, default)


activate_level(os.environ.get("NOVORSK_LEVEL") or "yard")
