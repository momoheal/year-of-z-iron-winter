"""独立夜潜布局：鹰嘴崖死线。坐标单位为逻辑米。"""

META = dict(
    id="eagle_beak_cliff", zh="鹰嘴崖死线", en="Eagle's Crag Line",
    scene="res://scenes/night_eagle_beak_cliff.tscn",
    manifest="night_eagle_beak_cliff_manifest.json", facade="depot",
    objective_zh="目标：找到鹰嘴崖第三节闷罐车厢并带走幸存者",
    extract_zh="沿崖顶检修路撤离", prize="intel", danger=5,
)

W, H = 42.0, 38.25
FACADE_H = 600
FACADE_BASE_Y = 3.0
FENCE_Y = None
TRACKS = [13.0, 21.0, 28.0]
SPAWN = (36.0, 34.0)
EXIT = (31.7, 7.0)

PROPS = [
    dict(id="SwitchLever", art="PRP_EagleBeakCliff_SwitchLever", pos=(19.0, 24.0), fp=(0.85, 0.5), layer=1),
    dict(id="BogieWheels", art="PRP_EagleBeakCliff_BogieWheels", pos=(21.0, 18.6), fp=(2.0, 0.7), layer=1),
    dict(id="SignalLamp", art="PRP_EagleBeakCliff_SignalLamp", pos=(11.0, 12.0), fp=(0.3, 0.25), layer=1, occlude=False),
    dict(id="FreightCrates", art="PRP_EagleBeakCliff_FreightCrates", pos=(26.0, 19.0), fp=(2.1, 0.95), layer=1, cont="supply"),
    dict(id="CableSpool", art="PRP_EagleBeakCliff_CableSpool", pos=(30.5, 13.0), fp=(1.5, 0.8), layer=2, occlude=False),
	dict(id="TracksideMarker", art="PRP_EagleBeakCliff_TracksideMarker", pos=(38.0, 12.5), fp=(0.35, 0.25), layer=1, occlude=False),
    dict(id="WreckCrate", art="PRP_Crate_Wood_Stack", pos=(17.0, 26.0), fp=(1.7, 0.85), layer=1, cont="crate"),
	dict(id="BrakeVan", art="PRP_Buran_Boxcar03", pos=(12.0, 16.0), fp=(8.0, 2.4), layer=1, cont="car", guaranteed="intel", fade=True, reach=(0.0, 0.3)),
	dict(id="BrazierDrumsWreck", art="PRP_Brazier_OilDrum", pos=(20.5, 25.0), fp=(0.9, 0.6), layer=2, occlude=False, fire=True),
	dict(id="BrazierDrumsRidge", art="PRP_Brazier_OilDrum", pos=(32.0, 29.0), fp=(0.9, 0.6), layer=2, occlude=False, fire=True),
	dict(id="Watchtower", art="PRP_Watchtower_Searchlight", pos=(34.0, 8.4), fp=(2.6, 1.3), layer=1),
]

PATROLS = [
    dict(id="OSK_CragRidge", mode="pingpong", pts=[(28.0, 10.0), (36.0, 10.0)], pause=2.2),
    dict(id="OSK_Wreck", mode="loop", pts=[(11.0, 18.0), (19.0, 22.0), (28.0, 20.0), (20.0, 15.0)], pause=1.8),
]
RABIDS = [
    dict(id="Rabid_Wreck", home=(17.0, 19.0), radius=2.8, brute=True),
    dict(id="Rabid_Switchback", home=(27.0, 27.0), radius=2.6, brute=False),
    dict(id="Rabid_Crag", home=(8.0, 10.0), radius=2.2, brute=False),
    dict(id="Rabid_TrainEnd", home=(31.0, 16.0), radius=2.4, brute=False),
]
HALFS = [dict(id="Half_004Survivor", pos=(15.8, 20.8), tag="004")]
SEARCHLIGHT = dict(pos=(34.0, 8.4), sweep=(130.0, 228.0), period=10.5, range=30.0, half=10.0)

SLUSH = [(20.0, 23.0, 3.5, 1.2), (28.0, 13.0, 2.8, 0.9), (9.0, 31.0, 3.0, 1.0)]
TAR_STAINS = [(16.0, 18.0, 1.4), (24.0, 26.0, 1.1)]
PATHS = [[(36.0, 34.0), (31.0, 31.0), (26.0, 27.0), (21.0, 23.0), (17.0, 19.0), (12.0, 16.0)],
         [(21.0, 23.0), (25.0, 17.0), (30.0, 12.0), (31.7, 7.0)]]
ASPHALT = []
GRAVEL = [(17.0, 20.0, 5.0, 1.8), (25.0, 28.0, 4.0, 1.2)]
MELT_BANDS = None
LIGHTS = dict(signal=(11.0, 12.0), brazier_wreck=(20.5, 25.0), brazier_ridge=(32.0, 29.0))
LIGHT_RIG = ["facade_glow", "signal", "brazier_wreck", "brazier_ridge", "searchlight"]
LIGHT_SEEDS = {}
AMBIENCE = ["wind", "fire"]
FACADE_FEATURES = {}
ZONES = [
    dict(id="white", zh="白区 · 崖顶检修路", en="WHITE ZONE · RIDGE ROAD", rule="safe", rects=[(28.0, 0.0, 42.0, 12.0)], note_zh="贴着崖壁的检修便道"),
    dict(id="red", zh="红区 · 盘山铁道", en="RED ZONE · SWITCHBACK", rule="curfew", rects=[(14.0, 10.0, 42.0, 29.0)], note_zh="探照灯横扫弯道"),
    dict(id="black", zh="黑区 · 脱轨现场", en="BLACK ZONE · WRECK", rule="sunken", rects=[(0.0, 12.0, 28.0, 31.0)], note_zh="第三节车厢和被困的人都在脱轨现场"),
]


from .plate_registration import register as _register_plate
_register_plate(globals())
