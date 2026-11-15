"""独立夜潜布局：温室大棚。坐标单位为米。"""

META = {'id': 'greenhouse',
 'zh': '温室大棚',
 'en': 'Greenhouse',
 'scene': 'res://scenes/night_greenhouse.tscn',
 'manifest': 'night_greenhouse_manifest.json',
 'facade': 'town',
 'objective_zh': '目标：北端苗床旁的黑麦箱',
 'extract_zh': '回温室南门撤离',
 'prize': 'rye'}

W = 29.0

H = 27.0

FACADE_BASE_Y = 3.0

FENCE_Y = None

TRACKS = []

SPAWN = (14, 24)

EXIT = (14, 25)

PROPS = [{'id': 'RyeCrate',
  'art': 'PRP_Crate_Wood_Stack',
  'pos': (14, 6),
  'fp': (1.7, 0.85),
  'layer': 1,
  'cont': 'crate',
  'guaranteed': 'rye'},
 {'id': 'SeedLocker',
  'art': 'PRP_Locker_ElectricCabinet',
  'pos': (6, 8),
  'fp': (0.9, 0.4),
  'layer': 1,
  'cont': 'locker'},
 {'id': 'Fertilizer',
  'art': 'PRP_SupplyCrates_Military',
  'pos': (25, 12),
  'fp': (1.9, 0.9),
  'layer': 1,
  'cont': 'supply'},
 {'id': 'WaterChest',
  'art': 'PRP_ColdStore_Chest',
  'pos': (23, 22),
  'fp': (2.6, 1.1),
  'layer': 1,
  'cont': 'fridge'},
 {'id': 'PlantBed1', 'art': 'PRP_Canteen_BenchTable', 'pos': (8, 12), 'fp': (2.2, 1.05), 'layer': 2},
 {'id': 'PlantBed2', 'art': 'PRP_Canteen_BenchTable', 'pos': (8, 16), 'fp': (2.2, 1.05), 'layer': 2},
 {'id': 'PlantBed3', 'art': 'PRP_Canteen_BenchTable', 'pos': (8, 20), 'fp': (2.2, 1.05), 'layer': 2},
 {'id': 'PlantBed4', 'art': 'PRP_Canteen_BenchTable', 'pos': (14, 11), 'fp': (2.2, 1.05), 'layer': 2},
 {'id': 'PlantBed5', 'art': 'PRP_Canteen_BenchTable', 'pos': (14, 16), 'fp': (2.2, 1.05), 'layer': 2},
 {'id': 'PlantBed6', 'art': 'PRP_Canteen_BenchTable', 'pos': (14, 21), 'fp': (2.2, 1.05), 'layer': 2},
 {'id': 'PlantBed7', 'art': 'PRP_Canteen_BenchTable', 'pos': (20, 12), 'fp': (2.2, 1.05), 'layer': 2},
 {'id': 'PlantBed8', 'art': 'PRP_Canteen_BenchTable', 'pos': (20, 16), 'fp': (2.2, 1.05), 'layer': 2},
 {'id': 'PlantBed9', 'art': 'PRP_Canteen_BenchTable', 'pos': (20, 20), 'fp': (2.2, 1.05), 'layer': 2},
 {'id': 'HeatDrum',
  'art': 'PRP_Brazier_OilDrum',
  'pos': (6, 22),
  'fp': (0.6, 0.45),
  'layer': 2,
  'fire': True,
  'occlude': False}]

PATROLS = [{'id': 'OSK_Glass', 'mode': 'pingpong', 'pts': [(21, 8), (25, 8)], 'pause': 1.8}]

RABIDS = []

HALFS = []

SEARCHLIGHT = None

SLUSH = [(17, 12, 1, 2.0)]

TAR_STAINS = []

PATHS = [[(14, 24), (11, 21), (11, 9), (14, 7)]]

LIGHTS = {'brazier_route': (6, 22)}

LIGHT_RIG = ['facade_glow', 'brazier_route']

LIGHT_SEEDS = {}

AMBIENCE = ['wind', 'fire']

FACADE_FEATURES = {}

ZONES = [{'id': 'red', 'rects': [(18, 6, 29, 14)]}, {'id': 'white', 'rects': [(0, 0, 29.0, 27.0)]}]

INTERIOR = True

FLOOR = {'zones': [('concrete', 0, 13), ('terrazzo', 13, 27)]}
