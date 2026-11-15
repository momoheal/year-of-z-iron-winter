"""独立夜潜布局：铁道下穿积冰道。坐标单位为米。"""

META = {'id': 'underpass',
 'zh': '铁道下穿积冰道',
 'en': 'Icy Rail Underpass',
 'scene': 'res://scenes/night_underpass.tscn',
 'manifest': 'night_underpass_manifest.json',
 'facade': 'sanitarium',
 'objective_zh': '目标：东侧值班柜的调度单',
 'extract_zh': '回涵洞西口撤离',
 'prize': 'intel'}

W = 38.0

H = 20.0

FACADE_BASE_Y = 3.0

FENCE_Y = None

TRACKS = []

SPAWN = (3.5, 10)

EXIT = (3, 13)

PROPS = [{'id': 'DispatchLocker',
  'art': 'PRP_Locker_ElectricCabinet',
  'pos': (33, 6.8),
  'fp': (0.9, 0.4),
  'layer': 1,
  'cont': 'locker',
  'guaranteed': 'intel'},
 {'id': 'BarrierNorth', 'art': 'PRP_Sandbag_Line', 'pos': (15, 8), 'fp': (5, 0.9), 'layer': 2},
 {'id': 'BarrierSouth', 'art': 'PRP_Sandbag_Line', 'pos': (22, 14), 'fp': (5, 0.9), 'layer': 2},
 {'id': 'DrainCrate',
  'art': 'PRP_Crate_Wood_Stack',
  'pos': (10, 15),
  'fp': (1.7, 0.85),
  'layer': 1,
  'cont': 'crate'},
 {'id': 'Supply',
  'art': 'PRP_SupplyCrates_Military',
  'pos': (28, 15),
  'fp': (1.9, 0.9),
  'layer': 1,
  'cont': 'supply'},
 {'id': 'Pier1', 'art': 'PRP_VaultColumn', 'pos': (8, 9), 'fp': (1.1, 1.1), 'layer': 1},
 {'id': 'Pier2', 'art': 'PRP_VaultColumn', 'pos': (13, 12), 'fp': (1.1, 1.1), 'layer': 1},
 {'id': 'Pier3', 'art': 'PRP_VaultColumn', 'pos': (19, 8), 'fp': (1.1, 1.1), 'layer': 1},
 {'id': 'Pier4', 'art': 'PRP_VaultColumn', 'pos': (25, 12), 'fp': (1.1, 1.1), 'layer': 1},
 {'id': 'Pier5', 'art': 'PRP_VaultColumn', 'pos': (30, 9), 'fp': (1.1, 1.1), 'layer': 1},
 {'id': 'HeatDrum',
  'art': 'PRP_Brazier_OilDrum',
  'pos': (4, 15),
  'fp': (0.6, 0.45),
  'layer': 2,
  'fire': True,
  'occlude': False}]

PATROLS = [{'id': 'OSK_Tunnel', 'mode': 'pingpong', 'pts': [(15, 10), (25, 10)], 'pause': 1.8}]

RABIDS = []

HALFS = []

SEARCHLIGHT = None

SLUSH = [(11, 10, 2.5, 1.6), (24, 11, 3, 1.7), (30, 14, 2, 1.6)]

TAR_STAINS = []

PATHS = [[(3.5, 10), (6, 6), (19, 5), (32, 6)], [(32, 6), (31, 16), (4, 16), (3, 13)]]

LIGHTS = {'brazier_route': (4, 15)}

LIGHT_RIG = ['facade_glow', 'brazier_route']

LIGHT_SEEDS = {}

AMBIENCE = ['wind', 'fire']

FACADE_FEATURES = {}

ZONES = [{'id': 'red', 'rects': [(12, 8, 29, 14)]}, {'id': 'white', 'rects': [(0, 0, 38.0, 20.0)]}]

INTERIOR = True

FLOOR = {'zones': [('concrete', 0, 20)]}
