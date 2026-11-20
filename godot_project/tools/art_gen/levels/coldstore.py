"""四号铁路冷库。按 Coldstore/map.png 的 46 × 34 米画幅登记接地点。"""

META = dict(
    id="coldstore",
    zh="城北四号铁路冷库",
    en="Rail Cold Storage No.4",
    scene="res://scenes/night_coldstore.tscn",
    manifest="night_coldstore_manifest.json",
    facade="coldstore",                              # 北侧立面：冷库主楼（保温板 + 冷风机）
    objective_zh="目标：南库封存的医疗耗材箱（abx）· 档案 0892 说这里在册人数 0，可柱后还有活人",
    extract_zh="回铁路专用线侧铁丝网豁口撤离",
    prize="abx",                                     # 封存抗生素 =「真药到底在哪」的另一半答案
    danger=2,
)

W, H = 46.0, 34.0
FACADE_H = 600
FACADE_BASE_Y = 9.3
FENCE_Y = 32.0
FENCE_GAP = (20.5, 25.0)
TRACKS = [28.8]
BALLAST_W = (1.9, 1.5)
SLAB_BAND = (9.3, 11.0)
FROST_ZONES = [(9.3, 16.6), (22.0, 30.5)]
SPAWN = (6.0, 11.0)
EXIT = (22.6, 32.7)

# These solids follow the painted yard walls. Leave the central passage open.
PLATE_WALLS = [
    ("WestDivider", 1.0, 16.8, 20.4, 21.1),
    ("EastDivider", 24.9, 16.8, 45.0, 21.1),
    ("WestPerimeter", 0, 9.3, 1.2, 32.0),
    ("EastPerimeter", 44.7, 9.3, 46, 32.0),
]
PLATE_CAMERA = True

def prop(name, art, pos, fp, *, baked=True, **options):
    return dict(id=name, art=art, pos=pos, fp=fp, layer=options.pop("layer", 1), baked=baked, **options)

PROPS = [
    prop("CardTerminal", "PRP_CardTerminal", (28.9, 9.65), (0.65, 0.35)),
    prop("DutyBooth", "PRP_Shanty_Shed", (31.0, 10.45), (2.7, 1.35)),
    prop("RationBox", "PRP_SupplyCrates_Military", (36.8, 9.6), (2.9, 1.0), cont="supply"),
    prop("DrainSlit", "PRP_DrainSlit", (33.9, 10.65), (1.6, 0.35), baked=False),
    prop("Locker", "PRP_Locker_ElectricCabinet", (3.1, 10.2), (0.9, 0.4), baked=False, cont="locker"),
    prop("Rack01", "PRP_Crate_Wood_Stack", (9.0, 14.95), (3.05, 2.2), cont="crate"),
    prop("Rack02", "PRP_Crate_Wood_Stack", (22.2, 15.05), (3.4, 2.25), cont="crate"),
    prop("Rack03", "PRP_Crate_Wood_Stack", (35.0, 15.0), (3.6, 2.15), cont="crate"),
    prop("Dumpster", "PRP_Dumpster_Steel", (42.0, 13.85), (2.05, 1.75), cont="dumpster"),
    prop("Column01", "PRP_VaultColumn", (7.7, 22.35), (1.2, 1.4)),
    prop("Column02", "PRP_VaultColumn", (15.35, 22.35), (1.25, 1.4)),
    prop("Column03", "PRP_VaultColumn", (27.0, 22.35), (1.2, 1.4)),
    prop("Column04", "PRP_VaultColumn", (34.15, 22.35), (1.2, 1.4)),
    prop("DutyFire", "PRP_Brazier_OilDrum", (9.8, 23.3), (0.6, 0.5), fire=True),
    prop("WorkerFire", "PRP_Brazier_OilDrum", (31.1, 23.3), (0.6, 0.5), fire=True),
    prop("SealedMeds", "PRP_SealedMedCrate", (4.1, 24.65), (2.15, 1.9), cont="medcab", guaranteed="abx", reach=(0, 0.65)),
    prop("ColdVaultDoor", "PRP_ColdVaultDoor", (40.7, 22.65), (4.4, 1.8)),
    prop("Freezer", "PRP_ColdStore_Chest", (37.4, 22.5), (2.0, 0.9), baked=False, cont="fridge"),
    prop("Corpse", "PRP_Corpse_Tarp", (29.4, 28.2), (1.5, 0.5), baked=False, cont="corpse", layer=0),
    prop("Reefer", "PRP_Buran_Boxcar03", (23.0, 29.35), (9.1, 4.15)),
]
FENCE_SEGMENTS = [(float(x), "a") for x in range(0, 46, 4)]
SLUSH = [(9.8, 23.6, 1.4, 0.8), (31.1, 23.6, 1.4, 0.8),
         (23.0, 21.8, 1.8, 0.8), (20.7, 10.1, 1.8, 0.8)]
TAR_STAINS = []
PATHS = [[SPAWN, (6, 16), (19, 16), (22.5, 17), (22.5, 22.5), (4.1, 25.2)],
         [(4.1, 25.2), (16, 25), (16, 30), (22.6, 30.5), EXIT]]
ASPHALT = []
GRAVEL = []
MELT_BANDS = None
LIGHTS = dict(lamp_dock=(20.7, 9.6), lamp_hall=(40.7, 21.8),
              brazier_duty=(9.8, 23.3), brazier_worker=(31.1, 23.3))
LIGHT_RIG = list(LIGHTS)
LIGHT_SEEDS = dict(lamp_dock=5, lamp_hall=17)
LIGHT_COLORS = dict(lamp_hall=(0.72, 0.85, 1.0))
AMBIENCE = ["wind", "fire", "buzz"]
PATROLS = [
    dict(id="OSK_Dock", mode="loop", pts=[(26, 11.4), (32, 11.4), (32, 15.8), (26, 15.8)], pause=2),
    dict(id="OSK_Rail", mode="pingpong", pts=[(34, 28.2), (41, 28.2)], pause=2.4),
]
RABIDS = [dict(id="Rabid_Rail", home=(39, 27.4), radius=2.2, brute=False),
          dict(id="Rabid_Store", home=(7.0, 27.4), radius=2.2, brute=False)]
HALFS = []
ZONES = [
    dict(id="white", zh="白区 · 安全区", en="WHITE ZONE · SAFE", rule="safe",
         rects=[(0, 0, 46, 11.5), (0, 11.5, 13, 21)], note_zh="北侧月台和西侧雪道"),
    dict(id="red", zh="红区 · 管制带", en="RED ZONE · CURFEW", rule="curfew",
         rects=[(13, 11.5, 46, 21)], note_zh="穿过堆场，沿中央墙口进入南库"),
    dict(id="black", zh="黑区 · 沉降带", en="BLACK ZONE · SUNKEN", rule="sunken",
         rects=[(0, 21, 46, 34)], note_zh="南库、铁路专用线和撤离口"),
]
MARKET = None
SURVIVORS = [(26.1, 23.45), (27.6, 23.65)]
SEARCHLIGHT = None
FACADE_FEATURES = dict(door_x=23, office_x=31, unit_x=35)
