"""独立夜潜布局：302 高地广播塔。坐标单位为逻辑米。"""

META = dict(
    id="broadcast_tower_302", zh="302 高地广播塔", en="Broadcast Tower 302",
    scene="res://scenes/night_broadcast_tower_302.tscn",
    manifest="night_broadcast_tower_302_manifest.json", facade="depot",
    objective_zh="目标：让 302 台发出第三节车厢的真实名单",
    extract_zh="守住南侧铁门并撤离", prize="photo", danger=5,
)

W, H = 42.0, 38.25
FACADE_H = 600
FACADE_BASE_Y = 3.0
FENCE_Y = None
TRACKS = []
SPAWN = (21.0, 34.2)
EXIT = (21.0, 34.2)

PROPS = [
    dict(id="Generator", art="PRP_BroadcastTower302_Generator", pos=(10.5, 18.5), fp=(2.0, 1.0), layer=1, cont="locker"),
    dict(id="RelayAntenna", art="PRP_BroadcastTower302_RelayAntenna", pos=(21.0, 8.0), fp=(1.0, 0.55), layer=1, occlude=False),
    dict(id="RadioDesk", art="PRP_BroadcastTower302_RadioDesk", pos=(21.0, 18.0), fp=(2.0, 0.9), layer=1, cont="briefcase", guaranteed="photo"),
	dict(id="Watchtower", art="PRP_BroadcastTower302_Searchlight", pos=(34.2, 11.5), fp=(0.5, 0.4), layer=1, occlude=False),
    dict(id="CableReel", art="PRP_BroadcastTower302_CableReel", pos=(28.0, 24.0), fp=(1.5, 0.9), layer=2, occlude=False),
    dict(id="SandbagBunker", art="PRP_BroadcastTower302_SandbagBunker", pos=(21.0, 30.7), fp=(4.0, 1.2), layer=2),
	dict(id="BrazierDrumsSouth", art="PRP_Brazier_OilDrum", pos=(21.0, 31.0), fp=(0.9, 0.6), layer=2, occlude=False, fire=True),
	dict(id="BrazierDrumsWest", art="PRP_Brazier_OilDrum", pos=(8.5, 28.0), fp=(0.9, 0.6), layer=2, occlude=False, fire=True),
    dict(id="RationCrates", art="PRP_SupplyCrates_Military", pos=(8.5, 26.0), fp=(1.9, 0.9), layer=1, cont="supply"),
    dict(id="RelayLocker", art="PRP_Locker_ElectricCabinet", pos=(30.0, 18.8), fp=(0.9, 0.4), layer=1, cont="locker"),
]

PATROLS = [
    dict(id="OSK_TowerRing", mode="loop", pts=[(14.0, 21.0), (28.0, 21.0), (28.0, 28.5), (14.0, 28.5)], pause=1.7),
    dict(id="OSK_Antenna", mode="pingpong", pts=[(17.0, 10.5), (25.0, 10.5)], pause=1.5),
]
RABIDS = [
    dict(id="Rabid_Generator", home=(8.0, 19.5), radius=2.4, brute=False),
    dict(id="Rabid_Barricade", home=(25.0, 30.0), radius=2.6, brute=True),
    dict(id="Rabid_Perimeter", home=(35.0, 25.0), radius=2.5, brute=False),
]
HALFS = [dict(id="Half_TowerWorker", pos=(14.0, 25.0), tag="302")]
SEARCHLIGHT = dict(pos=(34.2, 11.5), sweep=(126.0, 234.0), period=9.5, range=32.0, half=10.0)

SLUSH = [(9.0, 24.0, 2.8, 1.0), (32.0, 28.0, 3.0, 1.2), (21.0, 14.0, 2.8, 1.1)]
TAR_STAINS = [(13.0, 28.0, 1.2), (31.0, 20.0, 1.0)]
PATHS = [[(21.0, 34.2), (21.0, 30.5), (16.0, 26.0), (12.0, 21.0), (15.0, 17.0), (21.0, 16.0), (21.0, 8.0)],
         [(21.0, 30.5), (28.0, 27.0), (34.0, 20.0), (34.2, 11.5)]]
ASPHALT = []
GRAVEL = [(9.0, 15.0, 4.0, 1.4), (33.0, 15.0, 3.0, 1.2)]
MELT_BANDS = None
LIGHTS = dict(lamp_west=(7.0, 12.0), lamp_east=(35.0, 12.0),
	brazier_south=(21.0, 31.0), brazier_west=(8.5, 28.0))
LIGHT_RIG = ["facade_glow", "lamp_west", "lamp_east", "brazier_south", "brazier_west", "searchlight"]
LIGHT_SEEDS = dict(lamp_west=302, lamp_east=303)
AMBIENCE = ["wind", "fire", "buzz"]
FACADE_FEATURES = {}
ZONES = [
    dict(id="white", zh="白区 · 南门集结点", en="WHITE ZONE · SOUTH GATE", rule="safe", rects=[(0.0, 30.5, 42.0, 38.25)], note_zh="广播塔南门，撤离点就在铁门外"),
    dict(id="red", zh="红区 · 环塔壕沟", en="RED ZONE · INNER RING", rule="curfew", rects=[(0.0, 20.0, 42.0, 30.5)], note_zh="清杀队沿沙袋和变电机组巡逻"),
    dict(id="black", zh="黑区 · 天线阵列", en="BLACK ZONE · TRANSMITTER", rule="sunken", rects=[(0.0, 0.0, 42.0, 20.0)], note_zh="发射机和 302 米天线控制室"),
]


from .plate_registration import register as _register_plate
_register_plate(globals())
