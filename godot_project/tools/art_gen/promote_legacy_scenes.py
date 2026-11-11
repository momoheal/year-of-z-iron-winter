"""把六张旧 RaidSim 灰盒地图提升为实体贴图 NightExplore 场景。
复用已经验收的美术场景作为空间母版，只替换关卡身份、目标、撤离提示和必出物资。
"""
from pathlib import Path
import re

PROJ = Path(__file__).resolve().parents[2]
SCENES = PROJ / "scenes"
SPECS = {
    "boiler": {
        "template": "night_coldstore.tscn", "zh": "锅炉房", "en": "Boiler Room",
        "objective": "目标：锅炉房油渣与取暖燃料（kero）",
        "extract": "回锅炉房通风口撤离", "prize": "kero",
    },
    "underpass": {
        "template": "night_sanitarium.tscn", "zh": "涵洞", "en": "The Underpass",
        "objective": "目标：涵洞前的调度单与车道情报（intel）",
        "extract": "回涵洞西口撤离", "prize": "intel",
    },
    "birch": {
        "template": "night_explore.tscn", "zh": "白桦林", "en": "Birch Grove",
        "objective": "目标：林间巡逻队掉落的绷带（bandage）",
        "extract": "回白桦林南侧拖痕撤离", "prize": "bandage",
    },
    "workshop": {
        "template": "night_canteen.tscn", "zh": "机务段钳工房", "en": "Depot Workshop",
        "objective": "目标：台钳上的铸铁道钉撬棍（crowbar）",
        "extract": "回机务段钳工房西门撤离", "prize": "crowbar",
    },
    "greenhouse": {
        "template": "night_market.tscn", "zh": "温室", "en": "The Greenhouse",
        "objective": "目标：温室里最后一箱黑麦（rye）",
        "extract": "回温室破碎的南门撤离", "prize": "rye",
    },
    "archive": {
        "template": "night_sanitarium.tscn", "zh": "档案库", "en": "The Archive",
        "objective": "目标：拉娜的 0420 号病历与调车记录（log）",
        "extract": "回档案库排风口撤离", "prize": "log",
    },
}

for level_id, spec in SPECS.items():
    src = SCENES / spec["template"]
    text = src.read_text(encoding="utf-8-sig")
    replacements = {
        "level_id": level_id,
        "level_zh": spec["zh"],
        "level_en": spec["en"],
        "objective_zh": spec["objective"],
        "extract_zh": spec["extract"],
        "prize": spec["prize"],
    }
    # 场景自身标识：战役配置、环境节拍和美术/玩法回归都以它查询 LevelBeats。
    text = text.replace("[node name=\"NightExplore\" type=\"Node2D\"]", "[node name=\"NightExplore\" type=\"Node2D\"]\nloc_id = \"%s\"" % level_id, 1)
    for key, value in replacements.items():
        text, n = re.subn(rf'metadata/{re.escape(key)} = "[^"]*"', f'metadata/{key} = "{value}"', text, count=1)
        if n != 1:
            raise RuntimeError(f"{src.name}: 未找到 metadata/{key}")
    text, n = re.subn(r'metadata/guaranteed = "[^"]*"', f'metadata/guaranteed = "{spec["prize"]}"', text, count=1)
    if n != 1:
        raise RuntimeError(f"{src.name}: 未找到必出物资容器")
    dst = SCENES / f"night_{level_id}.tscn"
    dst.write_text(text, encoding="utf-8", newline="\n")
    print(f"PROMOTED {level_id}: {spec['template']} -> {dst.name}")
