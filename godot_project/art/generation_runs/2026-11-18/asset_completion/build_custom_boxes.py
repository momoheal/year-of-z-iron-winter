from __future__ import annotations

import json
from pathlib import Path
from PIL import Image

ROOT = Path('godot_project/art')
RUN = ROOT / 'generation_runs/2026-11-18/asset_completion'
MAPS = {
    'BroadcastTower302': ['Generator', 'RelayAntenna', 'RadioDesk', 'Searchlight', 'CableReel', 'SandbagBunker'],
    'EagleBeakCliff': ['SwitchLever', 'BogieWheels', 'SignalLamp', 'FreightCrates', 'CableSpool', 'TracksideMarker'],
    'StationBuranYard': ['SignalSwitch', 'FreightCrates', 'PlatformSignal', 'BogieBrake', 'MaintenanceTrolley', 'BrazierDrums'],
}

for map_id, labels in MAPS.items():
    image_path = ROOT / '80_maps' / map_id / 'cutout-source.png'
    image = Image.open(image_path).convert('RGBA')
    width, height = image.size
    cell_w, cell_h = width / 3, height / 2
    items = []
    for i, label in enumerate(labels):
        col, row = i % 3, i // 3
        x0, y0 = round(col * cell_w), round(row * cell_h)
        x1, y1 = round((col + 1) * cell_w), round((row + 1) * cell_h)
        cell = image.crop((x0, y0, x1, y1))
        alpha = cell.getchannel('A').point(lambda value: 255 if value > 16 else 0)
        bbox = alpha.getbbox()
        if not bbox:
            raise RuntimeError(f'{map_id}/{label}: empty alpha cell')
        pad = 28
        bx0 = max(x0, x0 + bbox[0] - pad)
        by0 = max(y0, y0 + bbox[1] - pad)
        bx1 = min(x1, x0 + bbox[2] + pad)
        by1 = min(y1, y0 + bbox[3] + pad)
        items.append({'id': label, 'box': [bx0, by0, bx1, by1]})
    out = RUN / map_id / 'cutout_boxes.json'
    out.write_text(json.dumps({'items': items}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(map_id, [(i['id'], i['box']) for i in items])
