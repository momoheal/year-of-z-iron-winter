"""独立夜潜布局：白桦林废弃板房。坐标单位为米。"""

META = {'id': 'birch',
 'zh': '白桦林废弃板房',
 'en': 'Birch Grove Shacks',
 'scene': 'res://scenes/night_birch.tscn',
 'manifest': 'night_birch_manifest.json',
 'facade': 'town',
 'objective_zh': '目标：板房旁的急救箱',
 'extract_zh': '循林间拖痕到东南侧撤离',
 'prize': 'band'}

W = 36.0

H = 32.0

FACADE_BASE_Y = 3.0

FENCE_Y = None

TRACKS = []

SPAWN = (5, 5)

EXIT = (28, 29)

PROPS = [{'id': 'AidCache',
  'art': 'PRP_MedCache',
  'pos': (23, 22),
  'fp': (1.2, 0.7),
  'layer': 1,
  'cont': 'medcab',
  'guaranteed': 'band'},
 {'id': 'HunterShack', 'art': 'PRP_Shanty_Shed', 'pos': (24, 19), 'fp': (3.6, 1.6), 'layer': 1},
 {'id': 'WoodCrate',
  'art': 'PRP_Crate_Wood_Stack',
  'pos': (9, 24),
  'fp': (1.7, 0.85),
  'layer': 1,
  'cont': 'crate'},
 {'id': 'AbandonedLocker',
  'art': 'PRP_Locker_ElectricCabinet',
  'pos': (17, 8),
  'fp': (0.9, 0.4),
  'layer': 1,
  'cont': 'locker'},
 {'id': 'SledSupplies',
  'art': 'PRP_SupplyCrates_Military',
  'pos': (29, 24),
  'fp': (1.9, 0.9),
  'layer': 1,
  'cont': 'supply'},
 {'id': 'SnowTree1', 'art': 'PRP_Pine_Snow', 'pos': (5, 12), 'fp': (0.95, 0.8), 'layer': 1},
 {'id': 'SnowTree2', 'art': 'PRP_Pine_Snow', 'pos': (8, 15), 'fp': (0.95, 0.8), 'layer': 1},
 {'id': 'SnowTree3', 'art': 'PRP_Pine_Snow', 'pos': (10, 9), 'fp': (0.95, 0.8), 'layer': 1},
 {'id': 'SnowTree4', 'art': 'PRP_Pine_Snow', 'pos': (12, 14), 'fp': (0.95, 0.8), 'layer': 1},
 {'id': 'SnowTree5', 'art': 'PRP_Pine_Snow', 'pos': (13, 20), 'fp': (0.95, 0.8), 'layer': 1},
 {'id': 'SnowTree6', 'art': 'PRP_Pine_Snow', 'pos': (17, 17), 'fp': (0.95, 0.8), 'layer': 1},
 {'id': 'SnowTree7', 'art': 'PRP_Pine_Snow', 'pos': (18, 24), 'fp': (0.95, 0.8), 'layer': 1},
 {'id': 'SnowTree8', 'art': 'PRP_Pine_Snow', 'pos': (21, 11), 'fp': (0.95, 0.8), 'layer': 1},
 {'id': 'SnowTree9', 'art': 'PRP_Pine_Snow', 'pos': (25, 8), 'fp': (0.95, 0.8), 'layer': 1},
 {'id': 'SnowTree10', 'art': 'PRP_Pine_Snow', 'pos': (28, 14), 'fp': (0.95, 0.8), 'layer': 1},
 {'id': 'SnowTree11', 'art': 'PRP_Pine_Snow', 'pos': (30, 18), 'fp': (0.95, 0.8), 'layer': 1},
 {'id': 'SnowTree12', 'art': 'PRP_Pine_Snow', 'pos': (32, 22), 'fp': (0.95, 0.8), 'layer': 1},
 {'id': 'HeatDrum',
  'art': 'PRP_Brazier_OilDrum',
  'pos': (10, 24),
  'fp': (0.6, 0.45),
  'layer': 2,
  'fire': True,
  'occlude': False}]

PATROLS = [{'id': 'OSK_Grove', 'mode': 'pingpong', 'pts': [(18, 11), (28, 11)], 'pause': 1.8}]

RABIDS = [{'id': 'Rabid1', 'home': (31, 25), 'radius': 2.0, 'brute': False}]

HALFS = []

SEARCHLIGHT = None

SLUSH = []

TAR_STAINS = []

PATHS = [[(5, 5), (7, 17), (13, 24), (23, 23), (28, 29)]]

LIGHTS = {'brazier_route': (10, 24)}

LIGHT_RIG = ['facade_glow', 'brazier_route']

LIGHT_SEEDS = {}

AMBIENCE = ['wind', 'fire']

FACADE_FEATURES = {}

ZONES = [{'id': 'black', 'rects': [(16, 18, 36, 32)]},
 {'id': 'red', 'rects': [(16, 8, 33, 15)]},
 {'id': 'white', 'rects': [(0, 0, 36.0, 32.0)]}]

SLAB_BAND = (3.0, 6.0)


from .plate_registration import register as _register_plate
_register_plate(globals())
