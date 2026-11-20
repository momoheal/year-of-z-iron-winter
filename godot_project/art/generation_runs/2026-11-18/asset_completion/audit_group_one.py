import json
from pathlib import Path
from PIL import Image, ImageChops, ImageStat
import sys
root=Path('godot_project/art')
ids=['BroadcastTower302','EagleBeakCliff','StationBuranYard']
global_manifest=json.loads((root/'asset_manifest.json').read_text(encoding='utf-8'))['assets']
errors=[]
for name in ids:
    package=root/'80_maps'/name
    art=json.loads((package/'artwork-manifest.json').read_text(encoding='utf-8'))
    if len(art.get('props',[])) != 6: errors.append(f'{name}: expected 6 props')
    for rel,size,mode in [
        (f'80_maps/{name}/map_night.png',[1672,941],'RGB'),
        (f'80_maps/{name}/cutout-source.png',None,'RGBA'),
    ]:
        path=root/rel
        image=Image.open(path)
        if mode not in image.mode: errors.append(f'{rel}: mode {image.mode}, expected {mode}')
        if size and list(image.size)!=size: errors.append(f'{rel}: size {image.size}, expected {size}')
        if 'A' in image.mode and image.getchannel('A').getextrema()[0] != 0: errors.append(f'{rel}: missing transparent pixels')
    base=Image.open(package/'map.png').convert('RGB')
    night=Image.open(package/'map_night.png').convert('RGB')
    diff=ImageChops.difference(base,night)
    if not any(ImageStat.Stat(diff).mean): errors.append(f'{name}: night image identical to day image')
    for prop in art['props']:
        rel=prop['path'].replace('res://art/','')
        image=Image.open(root/rel)
        if image.mode!='RGBA': errors.append(f'{rel}: mode={image.mode}')
        if list(image.size)!=prop['size']: errors.append(f'{rel}: declared size mismatch')
        px,py=prop['pivot']
        if not (0<=px<=image.width and 0<=py<=image.height): errors.append(f'{rel}: pivot out of bounds')
        if image.getchannel('A').getextrema()[0] != 0: errors.append(f'{rel}: alpha has no zero pixels')
        entry=global_manifest.get(rel)
        if not entry: errors.append(f'{rel}: missing from global asset_manifest')
        elif entry['pivot'] != prop['pivot']: errors.append(f'{rel}: global pivot mismatch')
        elif entry['declared_size'] != prop['size']: errors.append(f'{rel}: global size mismatch')
    print(f'{name}: {art["map"]["size"][0]}x{art["map"]["size"][1]}, night diff mean={sum(ImageStat.Stat(diff).mean)/3:.1f}, props={len(art["props"])}, global registrations OK')
if errors:
    print('\n'.join(errors)); sys.exit(1)
print('Group 1 asset audit PASS')
