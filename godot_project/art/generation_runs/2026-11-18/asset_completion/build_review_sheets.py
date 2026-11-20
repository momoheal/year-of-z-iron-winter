from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

art = Path('godot_project/art')
root = art / 'generation_runs/2026-11-18/asset_completion'
configs = {
    'BroadcastTower302': ['Generator','RelayAntenna','RadioDesk','Searchlight','CableReel','SandbagBunker'],
    'EagleBeakCliff': ['SwitchLever','BogieWheels','SignalLamp','FreightCrates','CableSpool','TracksideMarker'],
    'StationBuranYard': ['SignalSwitch','FreightCrates','PlatformSignal','BogieBrake','MaintenanceTrolley','BrazierDrums'],
}
try:
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 18)
except OSError:
    font = ImageFont.load_default()
for map_id, labels in configs.items():
    sheet = Image.new('RGB', (1080, 744), '#d8dce0')
    draw = ImageDraw.Draw(sheet)
    cell_w, cell_h = 360, 372
    for i, label in enumerate(labels):
        col, row = i % 3, i // 3
        x, y = col * cell_w, row * cell_h
        for yy in range(y, y + cell_h - 38, 24):
            for xx in range(x, x + cell_w, 24):
                shade = '#d8dce0' if ((xx // 24 + yy // 24) % 2) else '#c5cbd1'
                draw.rectangle((xx, yy, min(x + cell_w, xx + 24), min(y + cell_h - 38, yy + 24)), fill=shade)
        prop = Image.open(art / '30_props' / f'PRP_{map_id}_{label}.png').convert('RGBA')
        prop.thumbnail((310, 312), Image.Resampling.LANCZOS)
        px = x + (cell_w - prop.width) // 2
        py = y + (cell_h - 38 - prop.height) // 2
        sheet.paste(prop, (px, py), prop)
        draw.rectangle((x, y + cell_h - 38, x + cell_w, y + cell_h), fill='#263139')
        draw.text((x + 10, y + cell_h - 31), label, fill='white', font=font)
    out = root / map_id / 'props_review.png'
    sheet.save(out)
    print(out)

