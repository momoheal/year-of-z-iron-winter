"""独立夜潜布局：锅炉房后巷。坐标单位为米。"""

META = {'id': 'boiler',
 'zh': '锅炉房后巷',
 'en': 'Boiler Room Back Alley',
 'scene': 'res://scenes/night_boiler.tscn',
 'manifest': 'night_boiler_manifest.json',
 'facade': 'coldstore',
 'objective_zh': '目标：北侧检修角的煤油',
 'extract_zh': '回西南侧锅炉房通风口撤离',
 'prize': 'kero'}

W = 30.0

H = 25.0

FACADE_BASE_Y = 3.0

FENCE_Y = None

TRACKS = []

SPAWN = (4, 21)

EXIT = (4, 22)

PROPS = [{'id': 'FuelLocker',
  'art': 'PRP_Locker_ElectricCabinet',
  'pos': (6.5, 6.2),
  'fp': (0.9, 0.4),
  'layer': 1,
  'cont': 'locker',
  'guaranteed': 'kero'},
 {'id': 'SteamPipe', 'art': 'PRP_SteamPipe_Long', 'pos': (14, 11.5), 'fp': (9, 0.65), 'layer': 2},
 {'id': 'UtilityCrate',
  'art': 'PRP_Crate_Wood_Stack',
  'pos': (11, 19),
  'fp': (1.7, 0.85),
  'layer': 1,
  'cont': 'crate'},
 {'id': 'ValveCache',
  'art': 'PRP_SupplyCrates_Military',
  'pos': (23, 7),
  'fp': (1.9, 0.9),
  'layer': 1,
  'cont': 'supply'},
 {'id': 'ScrapBin',
  'art': 'PRP_Dumpster_Steel',
  'pos': (21, 17),
  'fp': (1.7, 0.9),
  'layer': 1,
  'cont': 'dumpster'},
 {'id': 'ServicePier1', 'art': 'PRP_VaultColumn', 'pos': (8, 12), 'fp': (1.1, 1.1), 'layer': 1},
 {'id': 'ServicePier2', 'art': 'PRP_VaultColumn', 'pos': (9, 16), 'fp': (1.1, 1.1), 'layer': 1},
 {'id': 'ServicePier3', 'art': 'PRP_VaultColumn', 'pos': (18, 13), 'fp': (1.1, 1.1), 'layer': 1},
 {'id': 'HeatDrum',
  'art': 'PRP_Brazier_OilDrum',
  'pos': (4, 16),
  'fp': (0.6, 0.45),
  'layer': 2,
  'fire': True,
  'occlude': False}]

PATROLS = [{'id': 'OSK_Utility', 'mode': 'pingpong', 'pts': [(19, 14), (25, 14)], 'pause': 1.8}]

RABIDS = []

HALFS = []

SEARCHLIGHT = None

SLUSH = [(14, 11.8, 2.3, 1.1)]

TAR_STAINS = []

PATHS = [[(4, 21), (5, 14), (6, 8)], [(6, 8), (15, 8), (23, 7)]]

LIGHTS = {'brazier_route': (4, 16)}

LIGHT_RIG = ['facade_glow', 'brazier_route']

LIGHT_SEEDS = {}

AMBIENCE = ['wind', 'fire']

FACADE_FEATURES = {}

ZONES = [{'id': 'red', 'rects': [(16, 10, 30, 19)]}, {'id': 'white', 'rects': [(0, 0, 30.0, 25.0)]}]

INTERIOR = True

FLOOR = {'zones': [('concrete', 0, 12), ('painted', 12, 25)]}
