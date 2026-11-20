from pathlib import Path
from PIL import Image
import json,hashlib
root=Path(r'C:/Users/admin/Documents/ChatGPT/year-of-z-iron-winter-github-repo/year-of-z-iron-winter')
run=root/'godot_project/art/generation_runs/2026-11-18/CHR_01'
art=root/'godot_project/art/10_characters/CHR_01_Aleksei'
report={'group':2,'route':'Codex image_gen (host_image)','runtime_wiring':'not_done','assets':[]}
name='CHR_01_Aleksei_Sheet_Expanded.png'
im=Image.open(art/name).convert('RGBA')
assert im.size==(864,1008), (name,im.size)
assert im.mode=='RGBA'
assert Image.open(art/'CHR_01_Aleksei_Sheet.png').convert('RGBA').tobytes()==im.crop((0,0,864,336)).tobytes()
frames=[]
for row in range(9):
 for col in range(12):
  cell=im.getchannel('A').crop((col*72,row*112,(col+1)*72,(row+1)*112))
  bbox=cell.getbbox()
  assert bbox is not None, (name,row,col,'empty')
  assert bbox[2]-bbox[0] <= 66, (name,row,col,'too wide',bbox)
  if row < 3:
   assert bbox[3] in (108,109), (name,row,col,'preserved base foot line',bbox)
  else:
   assert bbox[3] == 108, (name,row,col,'action foot anchor',bbox)
  assert bbox[1] >= 2, (name,row,col,'top bleed',bbox)
  frames.append({'row':row,'col':col,'bbox':list(bbox)})
rec={'file':name,'size':list(im.size),'mode':im.mode,'frame_count':len(frames),'grid':[12,9],
     'cell':[72,112],'pivot':[36,108],'all_nonempty':True,'feet_y':108,
     'row_order':['base_S','base_E','base_N','armed_S','armed_E','armed_N','swing_S','swing_E','swing_N'],
     'base_first_3_rows_pixel_identical':True,'base_feet_edge_exclusive_range':[108,109],
     'sha256':hashlib.sha256((art/name).read_bytes()).hexdigest()}
report['assets'].append(rec)
(run/'qa.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(name, rec)
print('PASS: 12x9 expanded sheet, 108 non-empty frames, 72x112 cells, pivot (36,108); base rows pixel-identical')
