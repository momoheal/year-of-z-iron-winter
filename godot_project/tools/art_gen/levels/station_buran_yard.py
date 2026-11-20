"""独立夜潜布局：布拉风货场。坐标单位为逻辑米，地面由完整地图画作覆盖。"""

META = dict(
    id="station_buran_yard", zh="布拉风货场", en="Buran Station Yard",
    scene="res://scenes/night_station_buran_yard.tscn",
    manifest="night_station_buran_yard_manifest.json", facade="depot",
    objective_zh="目标：核实布拉风号最后一份调度记录",
    extract_zh="沿南侧月台撤离", prize="intel", danger=4,
)

W, H = 42.0, 38.25
FACADE_H = 600
FACADE_BASE_Y = 3.0
FENCE_Y = None
TRACKS = [17.5, 23.5, 30.0]
SPAWN = (3.2, 34.2)
EXIT = (38.0, 34.1)

PROPS = [
    dict(id="SignalSwitch", art="PRP_StationBuranYard_SignalSwitch", pos=(8.0, 20.8), fp=(1.2, 0.55), layer=1),
    dict(id="FreightCrates", art="PRP_StationBuranYard_FreightCrates", pos=(18.0, 25.0), fp=(2.2, 1.0), layer=1, cont="supply"),
    dict(id="PlatformSignal", art="PRP_StationBuranYard_PlatformSignal", pos=(5.0, 15.0), fp=(0.35, 0.25), layer=1, occlude=False),
    dict(id="BogieBrake", art="PRP_StationBuranYard_BogieBrake", pos=(28.0, 23.0), fp=(1.8, 0.8), layer=1, cont="car"),
    dict(id="MaintenanceTrolley", art="PRP_StationBuranYard_MaintenanceTrolley", pos=(34.0, 29.5), fp=(2.4, 0.8), layer=2, occlude=False),
    dict(id="BrazierDrums", art="PRP_StationBuranYard_BrazierDrums", pos=(11.5, 31.0), fp=(0.9, 0.6), layer=2, occlude=False, fire=True),
	dict(id="BrazierDrumsEast", art="PRP_Brazier_OilDrum", pos=(37.0, 30.5), fp=(0.9, 0.6), layer=2, occlude=False, fire=True),
    dict(id="CoalCrates", art="PRP_Crate_Wood_Stack", pos=(36.0, 13.5), fp=(1.7, 0.85), layer=1, cont="crate"),
    dict(id="DispatchLocker", art="PRP_Locker_ElectricCabinet", pos=(11.0, 8.0), fp=(0.9, 0.4), layer=1, cont="locker", guaranteed="intel"),
	dict(id="Watchtower", art="PRP_Watchtower_Searchlight", pos=(35.0, 12.2), fp=(2.6, 1.3), layer=1),
]

PATROLS = [
    dict(id="OSK_Platform", mode="pingpong", pts=[(12.0, 16.5), (33.0, 16.5)], pause=2.0),
    dict(id="OSK_Boxcars", mode="loop", pts=[(31.0, 25.0), (37.0, 25.0), (37.0, 31.0), (29.0, 31.0)], pause=1.8),
]
RABIDS = [
    dict(id="Rabid_Platform", home=(21.0, 20.0), radius=2.4, brute=False),
    dict(id="Rabid_Boxcar", home=(30.0, 28.0), radius=2.6, brute=True),
    dict(id="Rabid_South", home=(16.0, 33.0), radius=2.3, brute=False),
]
HALFS = [dict(id="Half_0420Witness", pos=(24.5, 31.7), tag="0420")]
SEARCHLIGHT = dict(pos=(35.0, 12.2), sweep=(132.0, 228.0), period=12.0, range=28.0, half=12.0)

SLUSH = [(13.0, 27.0, 3.0, 1.2), (31.0, 18.0, 2.4, 1.0)]
TAR_STAINS = [(7.0, 30.0, 1.0), (34.0, 26.0, 1.2)]
PATHS = [[(3.2, 34.2), (9.0, 31.0), (16.0, 28.0), (24.0, 27.0), (32.0, 31.0), (38.0, 34.1)]]
ASPHALT = []
GRAVEL = [(19.0, 24.0, 5.0, 1.2), (30.0, 30.0, 4.0, 1.0)]
MELT_BANDS = None
LIGHTS = dict(brazier_route=(11.5, 31.0), brazier_east=(37.0, 30.5),
	lamp_platform=(5.0, 15.0), signal=(7.8, 20.0))
LIGHT_RIG = ["facade_glow", "brazier_route", "brazier_east", "lamp_platform", "signal", "searchlight"]
LIGHT_SEEDS = dict(lamp_platform=21)
AMBIENCE = ["wind", "fire", "buzz"]
FACADE_FEATURES = {}
ZONES = [
    dict(id="white", zh="白区 · 月台", en="WHITE ZONE · PLATFORM", rule="safe", rects=[(0.0, 0.0, 42.0, 14.0)], note_zh="站房与北侧月台"),
    dict(id="red", zh="红区 · 编组线", en="RED ZONE · SIDINGS", rule="curfew", rects=[(0.0, 14.0, 42.0, 27.0)], note_zh="清杀队巡逻的编组线"),
    dict(id="black", zh="黑区 · 货车尾端", en="BLACK ZONE · BOXCAR TAILS", rule="sunken", rects=[(0.0, 27.0, 42.0, 38.25)], note_zh="车厢与旧检修棚"),
]


from .plate_registration import register as _register_plate
_register_plate(globals())
