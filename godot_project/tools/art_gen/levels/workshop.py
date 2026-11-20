"""独立夜潜布局：机修车间。坐标单位为米。"""

META = {'id': 'workshop',
 'zh': '机修车间',
 'en': 'Machine Workshop',
 'scene': 'res://scenes/night_workshop.tscn',
 'manifest': 'night_workshop_manifest.json',
 'facade': 'depot',
 'objective_zh': '目标：东北侧工位的莫辛枪机',
 'extract_zh': '回车间西门撤离',
 'prize': 'bolt'}

W = 37.0

H = 24.0

FACADE_BASE_Y = 3.0

FENCE_Y = None

TRACKS = []

SPAWN = (4, 20)

EXIT = (3, 19)

PROPS = [{'id': 'PartsBin',
  'art': 'PRP_SupplyCrates_Military',
  'pos': (31, 6),
  'fp': (1.9, 0.9),
  'layer': 1,
  'cont': 'supply',
  'guaranteed': 'bolt'},
 {'id': 'Forklift', 'art': 'PRP_Forklift_Parked', 'pos': (25, 15), 'fp': (2.3, 1.4), 'layer': 1},
 {'id': 'OilBin',
  'art': 'PRP_Dumpster_Steel',
  'pos': (10, 6),
  'fp': (1.7, 0.9),
  'layer': 1,
  'cont': 'dumpster'},
 {'id': 'ToolLocker',
  'art': 'PRP_Locker_ElectricCabinet',
  'pos': (22, 20),
  'fp': (0.9, 0.4),
  'layer': 1,
  'cont': 'locker'},
 {'id': 'IncomingStock',
  'art': 'PRP_Crate_Wood_Stack',
  'pos': (10, 20),
  'fp': (1.7, 0.85),
  'layer': 1,
  'cont': 'crate'},
 {'id': 'Bench1', 'art': 'PRP_Canteen_Table', 'pos': (11, 10), 'fp': (2.3, 1.0), 'layer': 1},
 {'id': 'Bench2', 'art': 'PRP_Canteen_Table', 'pos': (11, 14), 'fp': (2.3, 1.0), 'layer': 1},
 {'id': 'Bench3', 'art': 'PRP_Canteen_Table', 'pos': (18, 8), 'fp': (2.3, 1.0), 'layer': 1},
 {'id': 'Bench4', 'art': 'PRP_Canteen_Table', 'pos': (18, 15), 'fp': (2.3, 1.0), 'layer': 1},
 {'id': 'Bench5', 'art': 'PRP_Canteen_Table', 'pos': (25, 9), 'fp': (2.3, 1.0), 'layer': 1},
 {'id': 'Bench6', 'art': 'PRP_Canteen_Table', 'pos': (31, 12), 'fp': (2.3, 1.0), 'layer': 1},
 {'id': 'HeatDrum',
  'art': 'PRP_Brazier_OilDrum',
  'pos': (5, 16),
  'fp': (0.6, 0.45),
  'layer': 2,
  'fire': True,
  'occlude': False}]

PATROLS = [{'id': 'OSK_Aisle', 'mode': 'pingpong', 'pts': [(15, 12), (23, 12)], 'pause': 1.8},
 {'id': 'OSK_Loading', 'mode': 'pingpong', 'pts': [(27, 18), (33, 18)], 'pause': 1.8}]

RABIDS = []

HALFS = []

SEARCHLIGHT = None

SLUSH = []

TAR_STAINS = []

PATHS = [[(4, 20), (6, 8), (7, 5), (23, 5), (31, 7)]]

LIGHTS = {'brazier_route': (5, 16)}

LIGHT_RIG = ['facade_glow', 'brazier_route']

LIGHT_SEEDS = {}

AMBIENCE = ['wind', 'fire']

FACADE_FEATURES = {}

ZONES = [{'id': 'red', 'rects': [(13, 10, 35, 21)]}, {'id': 'white', 'rects': [(0, 0, 37.0, 24.0)]}]

INTERIOR = True

FLOOR = {'zones': [('painted', 0, 8), ('concrete', 8, 24)]}


from .plate_registration import register as _register_plate
_register_plate(globals())
