from __future__ import annotations

import hashlib
import json
from pathlib import Path
from PIL import Image

ART = Path('godot_project/art')
MAP_ROOT = ART / '80_maps'
RUN_ROOT = ART / 'generation_runs/2026-11-18/asset_completion'
MAPS = {
    'BroadcastTower302': ('broadcast_tower_302', '302 号广播塔 · 围攻场地', '302 Broadcast Tower · siege grounds'),
    'EagleBeakCliff': ('eagle_beak_cliff', '鹰嘴崖 · 004 号车皮脱轨点', 'Eagle Beak Cliff · Car 004 derailment'),
    'StationBuranYard': ('station_buran_yard', '布拉风货场 · 西站铁路院', 'West Station · Buran rail yard'),
}

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def info(path: Path) -> tuple[list[int], str]:
    with Image.open(path) as image:
        return [image.width, image.height], image.mode

def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

for folder, (map_id, name_zh, name_en) in MAPS.items():
    package = MAP_ROOT / folder
    run = RUN_ROOT / folder
    map_path = package / 'map.png'
    night_path = package / 'map_night.png'
    source_path = package / 'cutout-source.png'
    map_size, _ = info(map_path)
    night_size, _ = info(night_path)
    source_size, source_mode = info(source_path)
    extracted = json.loads((run / 'prop-pack-final.json').read_text(encoding='utf-8'))
    props = []
    registry = {
        f'MAP_{folder}': {'path': f'res://art/80_maps/{folder}/map.png', 'size': map_size, 'pivot': None},
        f'MAP_{folder}_Night': {'path': f'res://art/80_maps/{folder}/map_night.png', 'size': night_size, 'pivot': None},
        f'CUTOUT_{folder}': {'path': f'res://art/80_maps/{folder}/cutout-source.png', 'size': source_size, 'pivot': None},
    }
    for item in extracted['accepted']:
        label = item['display_name']
        prop_id = f'PRP_{folder}_{label}'
        filename = f'{prop_id}.png'
        asset_path = ART / '30_props' / filename
        size, mode = info(asset_path)
        pivot = [int(item['anchor_px'][0]), int(item['anchor_px'][1])]
        props.append({
            'id': prop_id,
            'path': f'res://art/30_props/{filename}',
            'size': size,
            'pivot': pivot,
            'label': label,
            'alpha': 'RGBA true alpha',
            'source_sheet': 'cutout-source.png',
            'art_source': 'host_image',
            'route': 'image_gen',
            'anchor_source': item.get('anchor_source', 'measured'),
        })
        registry[prop_id] = {'path': f'res://art/30_props/{filename}', 'size': size, 'pivot': pivot}

    registry[f'MAP_{folder}_Night']['sha256'] = sha(night_path)
    registry[f'MAP_{folder}']['sha256'] = sha(map_path)
    registry[f'CUTOUT_{folder}']['sha256'] = sha(source_path)
    for item in props:
        asset_path = ART / item['path'].replace('res://art/', '')
        item['sha256'] = sha(asset_path)
        registry[item['id']]['sha256'] = item['sha256']

    manifest = {
        'schema': 'generate2dmap.artwork_manifest.v1',
        'id': map_id,
        'name': name_zh,
        'name_en': name_en,
        'art_source': 'host_image',
        'route': 'image_gen',
        'map': {
            'file': 'map.png', 'size': map_size,
            'path': f'res://art/80_maps/{folder}/map.png',
            'sha256': sha(map_path), 'art_source': 'existing', 'art_only': True,
        },
        'source_sheet': {
            'file': 'cutout-source.png', 'size': source_size,
            'path': f'res://art/80_maps/{folder}/cutout-source.png',
            'sha256': sha(source_path), 'alpha': f'{source_mode} true alpha',
            'prompt': 'cutout-prompt.txt', 'art_source': 'host_image', 'route': 'image_gen',
            'extraction_manifest': f'../../generation_runs/2026-11-18/asset_completion/{folder}/prop-pack-final.json',
        },
        'props': props,
        'variants': [{
            'id': f'MAP_{folder}_Night', 'file': 'map_night.png', 'size': night_size,
            'path': f'res://art/80_maps/{folder}/map_night.png', 'sha256': sha(night_path),
            'art_only': True, 'tone': 'night', 'prompt': 'generation-prompt-night.txt',
            'art_source': 'host_image', 'route': 'image_gen',
        }],
    }
    write_json(package / 'artwork-manifest.json', manifest)
    root_manifest = ART / f'night_{map_id}_manifest.json'
    write_json(root_manifest, registry)

    prop_lines = '\n'.join(f"| `{item['id']}.png` | {item['label']} | {item['size'][0]}×{item['size'][1]} | `{tuple(item['pivot'])}` |" for item in props)
    readme = f'''# {name_en}\n\n- 美术底图：`map.png`，1672×941，原地图包资源。\n- 夜色变体：`map_night.png`，1672×941；保留原构图，仅改为夜间冷蓝照明，暖光限于原有灯具。\n- 道具抠图源：`cutout-source.png`，{source_size[0]}×{source_size[1]} RGBA 真透明。\n- 提示词：`generation-prompt-night.txt`、`cutout-prompt.txt`；完整原图与切图验收记录位于 `godot_project/art/generation_runs/2026-11-18/asset_completion/{folder}/`。\n- 地图包：`map-bundle.json`（`generate2dmap.map_bundle.v2`）；几何与玩法数据以该文件为准。\n\n## 六件透明道具\n\n| 文件 | 用途 | 尺寸 | pivot（落地点） |\n| --- | --- | ---: | ---: |\n{prop_lines}\n\n道具以 `PRP_{folder}_<物件名>.png` 存入 `godot_project/art/30_props/`。pivot 是按道具底部支撑带测得的像素注册点，已写入本目录 `artwork-manifest.json`、地图级 registry 和全局 `asset_manifest.json`。所有道具为 RGBA 真透明。\n'''
    (package / 'README.md').write_text(readme, encoding='utf-8')
    print(f'{folder}: map/night/source + {len(props)} props; {root_manifest}')
