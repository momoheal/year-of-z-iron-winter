"""L04 · 西站调车场（marshalling）—— 第二张节点化地图（P4.2）。

危险度 4 / 夜长 100 分钟（≈240 秒）/ 寒冷 1.1 / 解锁条件 flag `lana_car3`（安娜入队）。
战役里的既有文案就是本关的剧本锚点，布局必须对得上：

    hint_zh  「报废守车里有零件，调度室外贴着今晚的发车令。」
    hint2_zh 「机车水箱里可能塞着手稿复写件。」
    story    《十一点的发车令》：调度室外的铁皮板上钉着一张还没撕的发车令，红章新鲜得发黏。

所以：
    * 关键物资 = `intel`（调度单/底单），钉在调度塔外的铁皮发车令板上（新增道具）；
    * 两台报废守车 = `car` 容器（零件），其中一台必出莫辛枪机；
    * 煤水塔 = `hidden` 容器，必出复写件；
    * 五股道 + 驼峰溜放线的道砟场，比货场开阔 —— 藏身的地方少了，探照灯却多扫 40 米。

平面图（44 × 36 米，x 向东 y 向南；北侧是机车库 / 调度塔立面）：

      0        8        16       24       32       40      44
    0 ┌──────────────────────────────────────────────────────┐  机车库砖墙（立面）
    3 │  电柜   木箱   守车门   蒸汽管        发车令板  调度塔 │  站台便道（沥青）
    6 │  值班车        ▬▬▬▬▬▬▬▬ 蒸汽管 ▬▬▬▬▬▬      垃圾桶    │
    9 │  木箱(asp) 转辙器 火堆              探照灯塔 ─────────│  道砟肩 / 驼峰
   12 │ ══════════════ 1 道 ═════════════════════════════════ │
   14 │            ▬▬▬ 守车 01 ▬▬▬   信号机                   │
   16 │ ══════════════ 2 道 ═════════════════════════════════ │
   18 │  ← OSK_Hump 在这条道间来回 →              冻尸        │
   20 │ ══════════════ 3 道 ═════════════════════════════════ │
   22 │                    ▬▬▬ 守车 02 ▬▬▬        半人 0244   │
   25 │ ══════════════ 4 道 ═════════════════════════════════ │
   27 │  火堆(东)                              煤水塔(复写件) │
   29 │ ══════════════ 5 道 ═══════ ▬▬▬ 闷罐 07 ▬▬▬ ═════════ │
   31 │  半人 0613（躺在你自己那条撤离路上）    OSK_Culvert    │
   33 │ ─ ─ ─ ─ 铁丝网 ─ ─ ─ ╳涵洞╳ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │
   36 └──────────────────────────────────────────────────────┘
                                ↑ 出生点 / 撤离点（9.0, 34.8 / 34.0）
"""

META = dict(
    id="marshalling",
    zh="西站调车场",
    en="West Station Marshalling Yard",
    scene="res://scenes/night_marshalling.tscn",
    manifest="night_marshalling_manifest.json",
    facade="depot",                                    # 北侧立面：机车库砖墙 + 调度塔
    objective_zh="目标：调度塔外那张还没撕的发车令（红章新鲜）· 探照灯每 13 秒扫过整片道砟",
    extract_zh="回南边铁丝网下的涵洞口撤离",
    prize="intel",                                     # 发车令 = 调度单/底单
    danger=4,
)

W, H = 44.0, 36.0
FACADE_H = 600

FACADE_BASE_Y = 3.0          # 机车库墙脚线
FENCE_Y = 33.0               # 南侧铁丝网（你是从涵洞钻进来的）
FENCE_GAP = (8.0, 10.0)      # 涵洞 / 被撕开的网口
TRACKS = [11.0, 15.6, 20.2, 24.8, 29.4]   # 五股道的中心线（4.6m 间距）
BALLAST_W = (1.95, 1.5)      # 道砟肩比 yard 窄：股道之间要留出能走的雪道
SLAB_BAND = (3.0, 8.6)       # 只有站台便道那一段是混凝土，股道区全是道砟

SPAWN = (9.0, 34.8)          # 涵洞口外侧
EXIT = (9.0, 34.0)           # 撤离点：涵洞

PROPS = [
    # --- 站台便道（y 3~8，机车库墙脚）---
    dict(id="ElectricCabinet", art="PRP_Locker_ElectricCabinet", pos=(6.5, 3.8), fp=(0.9, 0.4),
         layer=1, cont="locker"),
    dict(id="SupplyCrates", art="PRP_SupplyCrates_Military", pos=(17.0, 4.0), fp=(1.9, 0.9), layer=1,
         cont="supply"),
    dict(id="DispatchBoard", art="PRP_DispatchBoard_Tin", pos=(26.0, 4.4), fp=(1.7, 0.6), layer=1,
         cont="briefcase", reach=(0.0, 0.35), guaranteed="intel", occlude=False),   # ★ 发车令
    dict(id="Dumpster", art="PRP_Dumpster_Steel", pos=(35.0, 4.2), fp=(1.9, 1.1), layer=1,
         cont="dumpster"),
    dict(id="DutyCar", art="PRP_Car_Moskvich_Wreck", pos=(2.6, 5.2), fp=(4.4, 1.7), layer=1,
         cont="car", fade=True),
    dict(id="SteamPipe", art="PRP_SteamPipe_Long", pos=(22.0, 7.2), fp=(14.0, 0.55), layer=2,
         ao="pipe"),                                        # 站台南沿的暖管：蹲下能藏，管下是融雪带
    dict(id="LampWest", art="PRP_StreetLamp_Sodium", pos=(6.0, 4.4), fp=(0.3, 0.25), layer=1,
         occlude=False, ao="post"),
    dict(id="LampEast", art="PRP_StreetLamp_Sodium", pos=(38.0, 4.4), fp=(0.3, 0.25), layer=1,
         occlude=False, ao="post"),
    # --- 驼峰 / 道砟肩（y 8~11）---
    dict(id="CrateStack", art="PRP_Crate_Wood_Stack", pos=(5.0, 9.2), fp=(1.7, 0.85), layer=1,
         cont="crate", guaranteed="asp"),     # 必出阿司匹林：喂半人退烧要用（离 0613 有 6m）
    dict(id="SwitchStand01", art="PRP_SwitchStand", pos=(13.5, 9.4), fp=(0.9, 0.7), layer=1,
         occlude=False),
    dict(id="Brazier", art="PRP_Brazier_OilDrum", pos=(10.0, 10.6), fp=(0.6, 0.45), layer=2,
         occlude=False, fire=True),           # 扳道员的火堆：本关两个回温点之一
    dict(id="Watchtower", art="PRP_Watchtower_Searchlight", pos=(41.0, 8.6), fp=(2.6, 1.3), layer=1,
         fade=True),
    # --- 股道之间（y 12~31）---
    dict(id="SignalPost", art="PRP_SignalPost_Red", pos=(18.4, 13.3), fp=(0.3, 0.25), layer=1,
         occlude=False, ao="post"),
    dict(id="BrakeVan01", art="PRP_BrakeVan_Dead", pos=(14.0, 17.0), fp=(9.0, 2.6), layer=1,
         cont="car", reach=(0.0, 0.3), fade=True),
    dict(id="SwitchStand02", art="PRP_SwitchStand", pos=(27.0, 13.3), fp=(0.9, 0.7), layer=1,
         occlude=False),
    dict(id="FrozenBody", art="PRP_Corpse_Tarp", pos=(24.0, 22.5), fp=(1.7, 0.5), layer=0,
         cont="corpse"),
    dict(id="BrakeVan02", art="PRP_BrakeVan_Dead", pos=(30.0, 26.2), fp=(9.0, 2.6), layer=1,
         cont="car", reach=(0.0, 0.3), guaranteed="bolt", fade=True),   # 守车工具箱：必出莫辛枪机
    dict(id="Boxcar07", art="PRP_Buran_Boxcar03", pos=(18.0, 30.8), fp=(14.0, 2.8), layer=1,
         cont="supply", reach=(0.0, 0.3), fade=True),
    dict(id="BrazierEast", art="PRP_Brazier_OilDrum", pos=(33.5, 31.2), fp=(0.6, 0.45), layer=2,
         occlude=False, fire=True),           # 东头的火堆：第二个回温点（离涵洞 25m）
    dict(id="WaterTower", art="PRP_WaterTower", pos=(40.0, 31.4), fp=(3.6, 2.4), layer=1,
         cont="hidden", guaranteed="intel", fade=True),     # 机车水箱里的手稿复写件
]

# 铁丝网段：(x0, 资产)。每段 4m；涵洞两侧用「撕裂」变体
FENCE_SEGMENTS = [(0.0, "a"), (4.0, "torn"), (10.0, "torn_l"), (14.0, "a"), (18.0, "b"), (22.0, "a"),
                  (26.0, "a"), (30.0, "b"), (34.0, "a"), (38.0, "a"), (42.0, "b")]

# 冻雪泥 / 黑冰（踩上去 速度×0.65 噪声×2）
SLUSH = [
    (10.0, 10.6, 2.0, 1.4),    # 火堆融雪圈
    (33.5, 31.2, 2.0, 1.4),    # 东火堆融雪圈
    (22.5, 22.5, 3.2, 1.0),   # 3、4 道之间：溜放时洒的水
    (39.0, 33.4, 2.6, 1.1),    # 煤水塔下的积水
    (9.0, 32.4, 2.2, 1.0),     # 涵洞口
]

# 焦油 / 煤渣黑雪
TAR_STAINS = [(16.0, 27.0, 1.6), (30.0, 15.0, 1.2), (7.0, 6.4, 1.0), (40.0, 24.0, 1.4)]

# 踩出来的雪径（折线）
PATHS = [
    [(9.0, 34.4), (9.4, 31.2), (11.0, 27.1), (12.4, 22.5), (12.4, 13.3), (13.6, 8.0), (14.0, 5.6)],
    [(14.0, 5.6), (20.0, 4.8), (26.0, 4.6), (30.0, 4.2)],
    [(12.4, 22.5), (18.0, 22.5), (26.0, 22.5), (34.0, 22.5), (40.0, 24.0)],
    [(34.0, 22.5), (36.0, 25.4), (38.4, 29.4), (40.0, 31.0)],
    [(9.4, 31.2), (16.0, 31.6), (24.0, 32.0), (33.5, 31.4)],
]

# 沥青便道（新增地面层）：折线 + 宽度（米）。机车库前的检修通道，雪扫到两边
ASPHALT = [dict(pts=[(0.4, 5.6), (43.6, 5.6)], w=3.0)]

# 道砟 / 煤渣堆（新增地面层）：(cx, cy, rx, ry)
GRAVEL = [
    (20.0, 9.6, 7.0, 1.1),      # 驼峰溜放线前的道砟肩
    (38.4, 12.4, 3.6, 2.0),     # 塔下的煤渣堆
    (4.0, 30.0, 3.0, 1.8),      # 西头的备用枕木堆
]

MELT_BANDS = None     # 沿用「有 SteamPipe 就在管下烘一条融雪带」

LIGHTS = dict(
    brazier=(10.0, 10.6),
    brazier_east=(33.5, 31.2),
    lamp_west=(6.0, 4.4),
    lamp_east=(38.0, 4.4),
    signal=(18.4, 13.3),
    tower=(30.0, 3.0),
)
LIGHT_RIG = ["facade_glow", "tower", "lamp_west", "lamp_east", "brazier", "brazier_east", "signal",
             "searchlight"]
LIGHT_SEEDS = dict(lamp_west=11, lamp_east=19)

AMBIENCE = ["wind", "steam", "buzz", "fire"]

# 清杀队巡逻：3 组（危险度 4）。路线刻意压在雪径与道间通道上。
PATROLS = [
    dict(id="OSK_Depot", mode="loop", pts=[(12.0, 6.0), (38.0, 6.0), (38.0, 9.0), (12.0, 9.0)],
         pause=1.6),
    dict(id="OSK_Hump", mode="pingpong", pts=[(4.0, 22.5), (40.0, 22.5)], pause=2.2),
    dict(id="OSK_Culvert", mode="pingpong", pts=[(4.0, 32.2), (20.0, 32.2)], pause=2.8),
]

# 灰鳞狂暴者：5 只，其中 2 只壮硕（危险度 4）。
# 摆位思路：BrakeVan 那只守在零件车上；涵洞那只压在你的撤离路上 —— 想用清杀队清它，
# 得先把它引进站台便道的钠灯 / 探照灯里，而那里正好是 OSK_Depot 的巡逻线。
RABIDS = [
    dict(id="Rabid_Van", home=(16.6, 18.4), radius=2.0, brute=True),    # 守着守车 01（零件）
    dict(id="Rabid_Hump", home=(6.0, 13.3), radius=2.6, brute=False),   # 驼峰西头
    dict(id="Rabid_Tower", home=(33.0, 8.0), radius=2.2, brute=False),  # 调度塔下
    dict(id="Rabid_Culvert", home=(13.0, 33.4), radius=2.4, brute=False),  # 压撤离路
    dict(id="Rabid_Tender", home=(37.6, 27.1), radius=1.8, brute=True),    # 守着煤水塔（复写件）
]

# 回退半人：2 个。0613 躺在你自己的撤离路上 —— 绕开、退烧、还是灭口，都在探照灯的扫区里。
HALFS = [
    dict(id="Half_0613", pos=(10.4, 32.8), tag="0613"),   # 涵洞东侧，离 Rabid_Culvert 2.6m
    dict(id="Half_0244", pos=(37.0, 22.8), tag="0244"),   # 4 道东头，缩在守车 02 的背风侧
]

# 探照灯：装在调度塔东侧的灯桥上，扫整片道砟（比货场那盏远 4m、宽 2°、慢 2s）
SEARCHLIGHT = dict(pos=(41.0, 8.6), sweep=(138.0, 206.0), period=13.0, range=24.0, half=12.0)

# 立面关键点（x 米）：tower = 调度塔中心，door = 乘务员门，freight = 两扇卷帘货门
FACADE_FEATURES = dict(tower_x=30.0, door_x=14.0, freight_x=[5.0, 21.0], sign_x=24.0)
