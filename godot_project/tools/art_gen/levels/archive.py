"""独立夜潜布局：档案馆电报局。坐标单位为米。"""

META = {'id': 'archive',
 'zh': '档案馆电报局',
 'en': 'Archive and Telegraph Office',
 'scene': 'res://scenes/night_archive.tscn',
 'manifest': 'night_archive_manifest.json',
 'facade': 'sanitarium',
 'objective_zh': '目标：西北侧 0420 号底柜的调度底单',
 'extract_zh': '回档案馆东南侧排风口撤离',
 'prize': 'intel'}

W = 33.0

H = 26.0

FACADE_BASE_Y = 3.0

FENCE_Y = None

TRACKS = []

SPAWN = (29, 22)

EXIT = (29, 24)

PROPS = [{'id': 'File0420',
  'art': 'PRP_Locker_ElectricCabinet',
  'pos': (5, 6),
  'fp': (0.9, 0.4),
  'layer': 1,
  'cont': 'locker',
  'guaranteed': 'intel'},
 {'id': 'TelegraphDesk',
  'art': 'PRP_DispatchBoard_Tin',
  'pos': (17, 6),
  'fp': (1.7, 0.65),
  'layer': 1,
  'cont': 'briefcase'},
 {'id': 'CopySafe',
  'art': 'PRP_SupplyCrates_Military',
  'pos': (8, 20),
  'fp': (1.9, 0.9),
  'layer': 1,
  'cont': 'safe'},
 {'id': 'RecordsCrate',
  'art': 'PRP_Crate_Wood_Stack',
  'pos': (22, 22),
  'fp': (1.7, 0.85),
  'layer': 1,
  'cont': 'crate'},
 {'id': 'RecordsShelf1',
  'art': 'PRP_SupplyCrates_Military',
  'pos': (8, 10),
  'fp': (1.9, 0.9),
  'layer': 1},
 {'id': 'RecordsShelf2',
  'art': 'PRP_SupplyCrates_Military',
  'pos': (12, 10),
  'fp': (1.9, 0.9),
  'layer': 1},
 {'id': 'RecordsShelf3',
  'art': 'PRP_SupplyCrates_Military',
  'pos': (16, 10),
  'fp': (1.9, 0.9),
  'layer': 1},
 {'id': 'RecordsShelf4',
  'art': 'PRP_SupplyCrates_Military',
  'pos': (20, 10),
  'fp': (1.9, 0.9),
  'layer': 1},
 {'id': 'RecordsShelf5',
  'art': 'PRP_SupplyCrates_Military',
  'pos': (13, 15),
  'fp': (1.9, 0.9),
  'layer': 1},
 {'id': 'RecordsShelf6',
  'art': 'PRP_SupplyCrates_Military',
  'pos': (17, 15),
  'fp': (1.9, 0.9),
  'layer': 1},
 {'id': 'RecordsShelf7',
  'art': 'PRP_SupplyCrates_Military',
  'pos': (21, 15),
  'fp': (1.9, 0.9),
  'layer': 1},
 {'id': 'RecordsShelf8',
  'art': 'PRP_SupplyCrates_Military',
  'pos': (25, 15),
  'fp': (1.9, 0.9),
  'layer': 1},
 {'id': 'RecordsShelf9',
  'art': 'PRP_SupplyCrates_Military',
  'pos': (8, 18),
  'fp': (1.9, 0.9),
  'layer': 1},
 {'id': 'RecordsShelf10',
  'art': 'PRP_SupplyCrates_Military',
  'pos': (12, 18),
  'fp': (1.9, 0.9),
  'layer': 1},
 {'id': 'HeatDrum',
  'art': 'PRP_Brazier_OilDrum',
  'pos': (27, 23),
  'fp': (0.6, 0.45),
  'layer': 2,
  'fire': True,
  'occlude': False}]

PATROLS = [{'id': 'OSK_ReadingRoom', 'mode': 'pingpong', 'pts': [(13, 13), (24, 13)], 'pause': 1.8},
 {'id': 'OSK_Entrance', 'mode': 'pingpong', 'pts': [(25, 8), (29, 8)], 'pause': 1.8}]

RABIDS = []

HALFS = []

SEARCHLIGHT = None

SLUSH = []

TAR_STAINS = []

PATHS = [[(29, 22), (28, 18), (26, 11), (23, 7), (7, 7)], [(7, 7), (5, 13), (5, 21), (29, 24)]]

LIGHTS = {'brazier_route': (27, 23)}

LIGHT_RIG = ['facade_glow', 'brazier_route']

LIGHT_SEEDS = {}

AMBIENCE = ['wind', 'fire']

FACADE_FEATURES = {}

ZONES = [{'id': 'black', 'rects': [(0, 3, 9, 9)]},
 {'id': 'red', 'rects': [(12, 8, 29, 17)]},
 {'id': 'white', 'rects': [(0, 0, 33.0, 26.0)]}]

INTERIOR = True

FLOOR = {'zones': [('terrazzo', 0, 9), ('painted', 9, 17), ('concrete', 17, 26)]}
