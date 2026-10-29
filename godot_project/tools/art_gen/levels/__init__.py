"""levels — 关卡规格注册表（P4.1：让美术管线一次能出多张图）。

一个「关卡规格」= 一个纯数据模块（levels/<id>.py），里面只有字面量：

    META              关卡身份（id / 中英文名 / 目标 / 撤离口 / 关键物资 / 立面种类 …）
    W, H              地图尺寸（逻辑米）
    FACADE_BASE_Y     北侧立面的墙脚线
    FENCE_Y/GAP/SEGMENTS  铁丝网（None = 这一侧不设网）
    TRACKS            铁轨中心线（米）→ 也是脚步材质
    SPAWN / EXIT      进出点
    PROPS             道具（id / art / pos / fp / layer / cont / guaranteed / reach /
                      fade / occlude / fire / ao）
    SLUSH / TAR_STAINS / PATHS / ASPHALT / GRAVEL / MELT_BANDS
                      地面配方（后四项是新增的可选层，yard 全为空 → 像素不变）
    LIGHTS / LIGHT_RIG / LIGHT_SEEDS
    PATROLS / RABIDS / HALFS / SEARCHLIGHT
    FACADE_FEATURES   立面上的关键点（门 / 终端 / 公告栏 / 通风口 …，按立面种类取用）

用法：
    import layout as LY
    LY.activate_level("marshalling")     # 把 levels/marshalling.py 的数据灌进 layout 模块
    LY.PROPS ...

`layout.py` 是兼容层：老的 `import layout as LY` 一行不用改。默认关卡 = yard，
可以用环境变量 NOVORSK_LEVEL 或 `--level` 覆盖（gen_assets.py / build_scene.py）。
"""
from __future__ import annotations

import importlib

# 关卡 id → 模块名。新地图：写一个 levels/<id>.py，然后在这里登记一行。
LEVELS = ["yard", "marshalling", "manor"]


def load(name: str):
    """导入并返回关卡规格模块（不做副作用）。"""
    if name not in LEVELS:
        raise SystemExit(f"未知关卡 '{name}'；已登记：{', '.join(LEVELS)}")
    return importlib.import_module(f"{__name__}.{name}")


def attrs_of(spec) -> dict:
    """关卡规格里属于「布局数据」的属性（去掉模块内建与下划线开头的私有导入）。"""
    return {k: v for k, v in vars(spec).items() if not k.startswith("_") and k != "levels"}


def meta(name: str) -> dict:
    return load(name).META
