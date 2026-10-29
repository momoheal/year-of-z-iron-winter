"""L07 · 松林庄园 · 二号恒温库（manor）—— 第三张节点化地图。

危险度 5 / 夜长 120 分钟（≈288 秒）/ 寒冷 0.3（高墙挡了风，冻不死人 —— 杀你的是人）/
解锁条件 flag `manor_tip`（黑市 / 安娜给的线索）。

战役既有文案 = 本关剧本锚点：

    hint_zh  「墙外 −35℃，墙里 26℃。409 批腹透液就在那儿。」
    hint2_zh 「电网高墙 + 特勤值守。被发现基本等于死。」
    story    《焦油黑雪》：叉车把「临期十五天」的牛排、黄油和 409 批腹透液
             整铲推进 2000℃ 焚化炉销账。
    蓝图 L07 「铁路黑市 & 电网门 / 二号恒温特供库 / 二楼行政监控钢廊 / 2000℃ 焚化车间」
             （prototypes/Z年纪事_核心关卡俯视角平面动线图.html）

所以场景里必须有：恒温库防爆门前的**409 批托盘**（关键物资 dial）、特供牛排冷柜、
无缝钢管堆、停着的铲货叉车（掩体）、**2000℃ 炉口**（回温点 + 进料口里藏着的焚化炉照片）、
二楼钢廊的值守剪影与钢廊灯、电网高墙上被剪开的一格（进出）。

平面图（46 × 38 米，x 向东 y 向南；北侧 = 恒温库 + 焚化车间立面）：

      0        8        16       24       32       40       46
    0 ┌───────────────────────────────────────────────────────┐
    3 │ №2 恒温库防爆门   冷柜   钢管堆      炉口 进料口  烟囱 │  装卸 apron（混凝土）
    6 │ 灯  409托盘▬  牛排冷柜▬  ▬▬▬▬▬▬    叉车   灰斗   灯 │  沥青主道
    9 │ 松        钢廊阴影落下            焚化院（焦土）      │
   12 │ 松   火堆                冻尸      半人0771          松│
   16 │ 松                    叉车掩体            报废特勤车  │
   20 │ 松   半人0128      中央车道↓        冻观赏池          │
   24 │ 松        木箱(asp)      ↓        ▬▬ 池塘 ▬▬     松 │
   28 │ 松                    ↓                火堆(东)  松 │
   31 │ 松   松         松      ↓       松               塔│
   34 │ ━ 电网 ━ ✂剪开✂ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
   38 └───────────────────────────────────────────────────────┘
            ↑ 出生 (7.2, 35.6) / 撤离 (7.2, 34.8)
"""

META = dict(
    id="manor",
    zh="松林庄园 · 二号恒温库",
    en="Pine Manor · Depot No.2",
    scene="res://scenes/night_manor.tscn",
    manifest="night_manor_manifest.json",
    facade="manor",                                # 恒温库保温板 + 焚化车间砖墙
    objective_zh="目标：二号恒温库防爆门前托盘上的 409 批腹透液 · 二楼钢廊上一直有人",
    extract_zh="回西侧电网剪开的那一格撤离",
    prize="dial",                                  # 瑞士 409 批腹膜透析液
    danger=5,
)

W, H = 46.0, 38.0
FACADE_H = 600

FACADE_BASE_Y = 3.0          # 库墙 / 车间墙的墙脚线
FENCE_Y = 34.0               # 电网高墙
FENCE_GAP = (6.0, 8.5)       # 剪开的一格（叶莲娜的门禁磁卡不管用，还得用钳子）
TRACKS = []                  # 庄园里没有铁轨（暗门在车间里面，不在这张图上）
SLAB_BAND = (3.0, 7.8)       # 只有装卸 apron 是混凝土，其余是压实的雪与松针

SPAWN = (7.2, 35.6)          # 电网外
EXIT = (7.2, 34.8)           # 剪开的豁口

PROPS = [
    # --- 装卸 apron / 主道（y 3~8）---
    dict(id="BatchPallet", art="PRP_SupplyCrates_Military", pos=(13.0, 4.6), fp=(1.9, 0.9), layer=1,
         cont="fridge", reach=(0.0, 0.4), guaranteed="dial"),        # ★ 409 批托盘
    dict(id="BeefFreezer", art="PRP_ColdStore_Chest", pos=(18.5, 4.4), fp=(2.6, 1.1), layer=1,
         cont="fridge"),                                             # 特供谷饲牛排冷柜
    dict(id="GateBox", art="PRP_Locker_ElectricCabinet", pos=(4.5, 32.6), fp=(0.9, 0.4), layer=1,
         cont="locker"),                                             # 电网配电箱（断电 = 掩护）
    dict(id="PipeRack", art="PRP_SteamPipe_Long", pos=(24.0, 9.0), fp=(12.0, 0.55), layer=2,
         ao="pipe"),                                                 # 机车厂无缝钢管（蹲下能藏）
    dict(id="LampWest", art="PRP_StreetLamp_Sodium", pos=(6.0, 6.6), fp=(0.3, 0.25), layer=1,
         occlude=False, ao="post"),
    dict(id="LampEast", art="PRP_StreetLamp_Sodium", pos=(40.0, 6.6), fp=(0.3, 0.25), layer=1,
         occlude=False, ao="post"),
    # --- 焚化院（y 8~14）---
    dict(id="Forklift", art="PRP_Forklift_Parked", pos=(30.5, 10.5), fp=(3.0, 1.6), layer=1,
         fade=True),                                                 # 铲货叉车：蓝图里的移动掩体（本转先停着）
    dict(id="IncineratorFeed", art="PRP_Incinerator_Feed", pos=(37.5, 5.0), fp=(3.0, 1.4), layer=1,
         cont="hidden", reach=(0.0, 0.4), guaranteed="photo"),       # ★ 进料口里藏着的焚化炉照片
    dict(id="AshBins", art="PRP_Dumpster_Steel", pos=(41.5, 8.0), fp=(1.9, 1.1), layer=1,
         cont="dumpster"),
    dict(id="FrozenBody", art="PRP_Corpse_Tarp", pos=(35.5, 12.5), fp=(1.7, 0.5), layer=0,
         cont="corpse"),                                             # 「零过期损耗」
    dict(id="Brazier", art="PRP_Brazier_OilDrum", pos=(14.0, 12.0), fp=(0.6, 0.45), layer=2,
         occlude=False, fire=True),
    # --- 松林 / 池塘 / 车道（y 14~33）---
    dict(id="BurntCar", art="PRP_Car_Moskvich_Wreck", pos=(40.0, 16.0), fp=(4.4, 1.7), layer=1,
         cont="car", fade=True),
    dict(id="CrateStack", art="PRP_Crate_Wood_Stack", pos=(10.5, 26.0), fp=(1.7, 0.85), layer=1,
         cont="crate", guaranteed="asp"),     # 必出阿司匹林：喂半人退烧要用
    dict(id="BrazierEast", art="PRP_Brazier_OilDrum", pos=(36.0, 28.0), fp=(0.6, 0.45), layer=2,
         occlude=False, fire=True),
    dict(id="Watchtower", art="PRP_Watchtower_Searchlight", pos=(44.0, 32.4), fp=(2.6, 1.3), layer=1,
         fade=True),
    # --- 松林（会挡探照灯的光）---
    dict(id="Pine01", art="PRP_Pine_Snow", pos=(2.6, 10.0), fp=(2.2, 1.6), layer=1, ao="post"),
    dict(id="Pine02", art="PRP_Pine_Snow", pos=(3.4, 17.5), fp=(2.2, 1.6), layer=1, ao="post"),
    dict(id="Pine03", art="PRP_Pine_Snow", pos=(2.6, 25.0), fp=(2.2, 1.6), layer=1, ao="post"),
    dict(id="Pine04", art="PRP_Pine_Snow", pos=(5.2, 30.5), fp=(2.2, 1.6), layer=1, ao="post"),
    dict(id="Pine05", art="PRP_Pine_Snow", pos=(43.6, 22.0), fp=(2.2, 1.6), layer=1, ao="post"),
    dict(id="Pine06", art="PRP_Pine_Snow", pos=(44.2, 29.0), fp=(2.2, 1.6), layer=1, ao="post"),
    dict(id="Pine07", art="PRP_Pine_Snow", pos=(43.0, 12.0), fp=(2.2, 1.6), layer=1, ao="post"),
    dict(id="Pine08", art="PRP_Pine_Snow", pos=(26.0, 30.5), fp=(2.2, 1.6), layer=1, ao="post"),
    dict(id="Pine09", art="PRP_Pine_Snow", pos=(15.0, 30.0), fp=(2.2, 1.6), layer=1, ao="post"),
]

# 电网段：(x0, 资产)。剪开的那格两侧用垂丝变体
FENCE_SEGMENTS = [(0.0, "elec"), (4.0, "elec_cut"), (8.5, "elec_cut"), (12.5, "elec"), (16.5, "elec"),
                  (20.5, "elec"), (24.5, "elec"), (28.5, "elec"), (32.5, "elec"), (36.5, "elec"),
                  (40.5, "elec"), (44.5, "elec")]

# 冻雪泥 / 黑冰：观赏池整面冻住 + 火堆融雪圈 + 炉口前的水渍 + 豁口的水坑
SLUSH = [
    (33.0, 24.0, 5.5, 3.0),    # 冻观赏池（抄近路 = 冰面噪声 ×2）
    (14.0, 12.0, 2.0, 1.4),
    (36.0, 28.0, 2.0, 1.4),
    (34.0, 5.6, 3.4, 1.5),     # 炉口烤化的雪水又冻上
    (7.2, 33.2, 2.0, 1.0),
]

# 焦土 / 煤灰
TAR_STAINS = [(34.0, 9.5, 2.2), (38.0, 12.0, 1.4), (10.0, 8.0, 1.0), (26.0, 30.0, 1.3)]

PATHS = [
    [(7.2, 35.2), (7.6, 32.0), (9.0, 28.0), (12.0, 22.0), (14.0, 16.0), (14.0, 10.0), (13.0, 6.6)],
    [(13.0, 6.6), (20.0, 6.2), (26.0, 6.2), (30.0, 6.4)],
    [(20.5, 8.0), (20.5, 16.0), (20.5, 22.0), (20.5, 31.0)],
    [(20.5, 22.0), (26.0, 20.6), (31.0, 20.4), (36.0, 22.0), (36.0, 26.0)],
    [(30.0, 6.4), (34.0, 7.0), (34.0, 9.0)],
    [(9.0, 28.0), (15.0, 29.6), (20.5, 31.0)],
]

ASPHALT = [
    dict(pts=[(1.5, 6.2), (44.5, 6.2)], w=3.2),      # 装卸主道（扫过雪）
    dict(pts=[(20.5, 7.0), (20.5, 32.0)], w=3.0),    # 中央车道：apron 直插电网门
]

GRAVEL = [
    (34.0, 8.6, 5.0, 2.2),     # 炉口前的煤渣 apron
    (6.0, 20.0, 4.0, 3.0),     # 松针地（西）
    (42.0, 20.0, 3.0, 3.0),    # 松针地（东）
]

MELT_BANDS = []                # 没有暖管；炉口的融雪直接画在 SLUSH 里

LIGHTS = dict(
    brazier=(14.0, 12.0),
    brazier_east=(36.0, 28.0),
    furnace=(34.0, 4.6),       # 2000℃ 炉口：第三个回温点（也是全图最亮的地方）
    catwalk=(12.0, 3.6),       # 二楼行政钢廊的灯（从头顶压下来）
    lamp_west=(6.0, 6.6),
    lamp_east=(40.0, 6.6),
)
LIGHT_RIG = ["facade_glow", "furnace", "catwalk", "lamp_west", "lamp_east", "brazier",
             "brazier_east", "searchlight"]
LIGHT_SEEDS = dict(lamp_west=23, lamp_east=29)

AMBIENCE = ["wind", "fire", "buzz"]      # 高墙里风小（cfg.cold=0.3），没有蒸汽管

# 特勤巡逻：4 组。OSK_Depot 的环线正对着 409 托盘 —— 想拿货就得卡它的背身窗口。
PATROLS = [
    dict(id="OSK_Gate", mode="pingpong", pts=[(4.0, 32.6), (18.0, 32.6)], pause=2.4),
    dict(id="OSK_Depot", mode="loop", pts=[(6.0, 5.4), (24.0, 5.4), (24.0, 8.8), (6.0, 8.8)],
         pause=1.6),
    dict(id="OSK_Drive", mode="pingpong", pts=[(20.5, 10.0), (20.5, 30.0)], pause=2.0),
    dict(id="OSK_Kiln", mode="loop", pts=[(30.0, 9.0), (42.0, 9.0), (42.0, 19.0), (30.0, 19.0)],
         pause=1.8),
]

# 狂暴者：4 只（1 壮硕）。庄园里的是「销账」没销干净的家伙。
RABIDS = [
    dict(id="Rabid_Kiln", home=(36.5, 10.5), radius=2.0, brute=True),   # 焚化院（守着照片）
    dict(id="Rabid_Grove", home=(4.0, 22.0), radius=2.6, brute=False),  # 西松林
    dict(id="Rabid_Pond", home=(30.0, 26.5), radius=2.4, brute=False),  # 池塘边
    dict(id="Rabid_Gate", home=(12.0, 33.0), radius=2.2, brute=False),  # 压撤离路
]

# 回退半人：2 个。0771 是厨房帮工（烧灼伤），0128 躲在松林里等不存在的那班车。
HALFS = [
    dict(id="Half_0771", pos=(39.0, 10.0), tag="0771"),
    dict(id="Half_0128", pos=(6.5, 14.5), tag="0128"),
]

# 探照灯：东南角岗塔，从西扫到西北（正好掠过池塘与撤离路）
SEARCHLIGHT = dict(pos=(44.0, 32.4), sweep=(165.0, 255.0), period=12.0, range=26.0, half=10.0)

# 立面关键点（x 米）：split = 恒温库 / 焚化车间分界
FACADE_FEATURES = dict(
    split_x=24.0, sign_x=8.0, blast_x=13.0, freezer_x=20.5,
    windows_x=[4.0, 11.0, 17.0, 21.0], catwalk_y=320, catwalk_lamps_x=[6.0, 16.0],
    maw_x=34.0, chimney_x=40.0, hall_windows_x=[28.0, 43.0], hall_door_x=30.0,
)
