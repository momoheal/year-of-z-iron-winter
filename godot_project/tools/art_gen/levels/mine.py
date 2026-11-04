"""L07M · 3 号矿坑 · 温压爆破作业面（mine）—— v4.2 新增幕（第四幕）的场景美术。

危险度 5 / 夜长 100 分钟（≈240 秒）/ 寒冷 1.2 / 解锁条件 flag `lana_car3`（安娜入队、
知道了「铁壳号开往 3 号矿坑炸山填埋」）。

剧本锚点 = 总剧本 v4.2 第四幕场次 4-1 / 4-2（美术设计见
`docs/zh/Z年纪事_3号矿坑场景美术设计.md`）：

    场次 4-1 「炸穿的冻土与会发光的粉尘」—— 温压爆破把永冻层整层掀开，
             断面深处嵌着灰黑色的远古孢子粉尘层：灰鳞病是他们自己炸出来的。
    场次 4-2 「铝热剂阵列与抉择 E」—— 起爆器旁码着铝热剂装药，
             任务代号「净账」：爆破坍塌矿坑，账面数与实存数在山体内部闭合。

所以场景里必须有：**爆破断面（孢子层）**、**铝热剂装药堆**、**起爆器**
（guaranteed `intel` = 孢子岩芯与爆破台账，第六幕广播的物证）、留守技术员
**博伊科**（回退半人 0417，蜷在看守火堆旁）、**假人哨塔第二座**（远看是防线，
近看是塑料模特）——以及塌方注脚：侧翻矿车、来不及架上的坑木。

平面图（46 × 34 米，x 向东 y 向南；北侧 = 矿山岩壁立面）：

      0        8        16       24       32       40      46
    0 ┌──────────────────────────────────────────────────────┐
    3 │ ▤斜井坑木门脸    工棚(窗光)   矿仓     井架 ▤爆破断面 │  矿山立面（TIL_Facade_Mine_A）
    6 │ 灯   电柜  台账板  压风管▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬    灯   │  装卸台（白区）
   10 │      木箱(asp)         信号机                        │
   12 │ ══════════════ 运矸专线（1 道，y=15.5）══════════════│
   14 │ 火堆        ▬矿车▬    坑木    坑木        假人哨塔    │  工业广场（红区）
   18 │        矿车(侧翻)                铝热剂堆▬          │
   21 │                  孢子断面02        ▬▬ 铝热剂 ▬▬      │
   24 │   冻尸        博伊科  起爆器▣(intel)  火堆           │  爆破作业面（黑区）
   27 │            ▬▬▬ 孢子断面01（主断面）▬▬▬    矸石堆      │
   30 │        撕裂网 ╳豁口╳ 撕裂网                          │  南侧铁丝网
   34 └──────────────────────────────────────────────────────┘
                  ↑ 出生 (10.0, 33.2) / 撤离 (10.0, 32.4)

⚠️ 本文件是「出过图」的版本：改数值就要重跑
   `python gen_assets.py --level mine ground facade`（+ `props --only …` 仅限新道具）
   与 `python build_scene.py --level mine`，并且 `python check_levels.py` 必须全绿。
"""

META = dict(
    id="mine",
    zh="3 号矿坑 · 温压爆破作业面",
    en="Mine Shaft No.3 · Blast Face",
    scene="res://scenes/night_mine.tscn",
    manifest="night_mine_manifest.json",
    facade="mine",                                   # 北侧立面：矿山岩壁 + 斜井 + 井架 + 断面
    objective_zh="目标：起爆器旁的孢子岩芯与爆破台账 · 铝热剂已经码到断面根上",
    extract_zh="回南侧铁丝网豁口（运矸专线）撤离",
    prize="intel",                                   # 孢子岩芯与爆破台账 = 第六幕广播物证
    danger=5,
)

W, H = 46.0, 34.0
FACADE_H = 600

FACADE_BASE_Y = 3.0          # 岩壁墙脚线
FENCE_Y = 31.5               # 南侧铁丝网（运矸专线缺口 = 进出口）
FENCE_GAP = (8.5, 11.5)
TRACKS = [15.5]              # 运矸专线（一条窄轨工业线）
BALLAST_W = (1.9, 1.5)
SLAB_BAND = (3.0, 8.6)       # 只有装卸台是混凝土，广场以下全是煤渣与冻土

SPAWN = (10.0, 33.2)         # 南侧豁口外
EXIT = (10.0, 32.4)          # 撤离点：豁口

# 道具：id, 资产名, 位置(底部中心), 碰撞脚印(米), 物理层, 容器
PROPS = [
    # --- 装卸台（白区，y 3~11）：换岗队盯着的地方 ---
    dict(id="ElectricCabinet", art="PRP_Locker_ElectricCabinet", pos=(8.5, 3.9), fp=(0.9, 0.4),
         layer=1, cont="locker"),
    dict(id="DispatchBoard", art="PRP_DispatchBoard_Tin", pos=(14.0, 4.3), fp=(1.7, 0.6),
         layer=1, cont="briefcase", reach=(0.0, 0.35), occlude=False),   # 班前会铁皮板
    dict(id="SteamPipe", art="PRP_SteamPipe_Long", pos=(22.0, 7.0), fp=(14.0, 0.55), layer=2,
         ao="pipe"),                                                     # 压风管（本关的"蒸汽"声源）
    dict(id="SupplyCrates", art="PRP_SupplyCrates_Military", pos=(30.5, 4.2), fp=(1.9, 0.9),
         layer=1, cont="supply"),
    dict(id="LampWest", art="PRP_StreetLamp_Sodium", pos=(6.0, 4.4), fp=(0.3, 0.25), layer=1,
         occlude=False, ao="post"),
    dict(id="LampEast", art="PRP_StreetLamp_Sodium", pos=(40.0, 4.4), fp=(0.3, 0.25), layer=1,
         occlude=False, ao="post"),
    # --- 工业广场（红区，y 11~21）：假人哨塔 + 换岗巡逻 ---
    dict(id="Brazier", art="PRP_Brazier_OilDrum", pos=(14.5, 13.2), fp=(0.6, 0.45), layer=2,
         occlude=False, fire=True),                 # 装药队的火（回温点 1）
    dict(id="CrateStack", art="PRP_Crate_Wood_Stack", pos=(5.0, 15.8), fp=(1.7, 0.85), layer=1,
         cont="crate", guaranteed="asp"),           # 必出阿司匹林：给博伊科退烧
    dict(id="SignalPost", art="PRP_SignalPost_Red", pos=(20.0, 12.0), fp=(0.3, 0.25), layer=1,
         occlude=False, ao="post"),
    dict(id="OreCart01", art="PRP_OreCart_Rusty", pos=(12.5, 16.2), fp=(2.6, 1.3), layer=1,
         cont="car"),
    dict(id="OreCart02", art="PRP_OreCart_Rusty", pos=(17.0, 18.2), fp=(2.6, 1.3), layer=1,
         cont="car", fade=True),
    dict(id="Timber01", art="PRP_Timber_Support", pos=(18.0, 21.5), fp=(1.5, 0.8), layer=1,
         ao="post"),
    dict(id="Timber02", art="PRP_Timber_Support", pos=(26.0, 22.6), fp=(1.5, 0.8), layer=1,
         ao="post"),
    dict(id="DummyTower", art="PRP_DummyTower_Mannequin", pos=(38.5, 13.4), fp=(2.2, 1.2),
         layer=1, fade=True),                       # 假人哨塔第二座（无灯 · 空壳）
    dict(id="Thermite01", art="PRP_Thermite_Charge", pos=(33.5, 22.4), fp=(1.8, 1.0), layer=1,
         cont="crate"),
    dict(id="Thermite02", art="PRP_Thermite_Charge", pos=(37.2, 24.6), fp=(1.8, 1.0), layer=1,
         cont="crate"),
    # --- 爆破作业面（黑区，y 21~31）：证据、铝热剂、博伊科 ---
    dict(id="DetonatorRig", art="PRP_Detonator_Rig", pos=(29.5, 26.8), fp=(1.4, 0.8), layer=1,
         cont="locker", guaranteed="intel", reach=(0.0, 0.3)),   # ★ 岩芯与爆破台账
    dict(id="BrazierCut", art="PRP_Brazier_OilDrum", pos=(32.2, 25.6), fp=(0.6, 0.45), layer=2,
         occlude=False, fire=True),                 # 看守断面的火（回温点 2）
    dict(id="SporeFace01", art="PRP_SporeFace", pos=(36.5, 28.4), fp=(7.0, 1.4), layer=1,
         fade=True),                                # 主断面（孢子层）
    dict(id="SporeFace02", art="PRP_SporeFace", pos=(24.0, 30.6), fp=(4.5, 1.0), layer=1,
         fade=True),
    dict(id="FrozenBody", art="PRP_Corpse_Tarp", pos=(22.0, 26.0), fp=(1.7, 0.5), layer=0,
         cont="corpse"),
]

# 铁丝网段：(x0, 资产)。每段 4m；豁口两侧用「撕裂」变体
FENCE_SEGMENTS = [(0.0, "a"), (4.0, "a"), (8.5, "torn"), (11.5, "torn_l"), (15.5, "a"),
                  (19.5, "b"), (23.5, "a"), (27.5, "a"), (31.5, "b"), (35.5, "a"),
                  (39.5, "a"), (43.5, "b")]

# 冻雪泥（踩上去 速度×0.65 噪声×2）：火堆融雪圈 / 井口 / 断面下的粉尘湿泥
SLUSH = [
    (14.5, 13.2, 2.0, 1.4),
    (32.2, 25.6, 2.0, 1.4),
    (7.5, 5.2, 2.6, 1.1),
    (30.0, 28.6, 3.0, 1.0),
]

# 矸石 / 煤渣黑雪
TAR_STAINS = [(24.0, 16.0, 1.6), (36.0, 21.0, 1.4), (12.0, 24.0, 1.2), (30.0, 8.0, 1.0)]

# 踩出来的雪径（折线）
PATHS = [
    [(10.0, 32.6), (11.0, 28.0), (13.0, 22.0), (14.5, 16.0), (14.5, 13.2)],
    [(14.5, 13.2), (16.0, 9.0), (19.0, 5.2)],                     # → 工棚
    [(14.5, 13.2), (22.0, 14.0), (30.0, 15.5), (38.0, 14.0)],     # 广场横路
    [(30.0, 15.5), (30.2, 21.0), (30.2, 26.2)],                   # → 起爆器 / 断面
    [(30.2, 26.2), (36.5, 27.6), (24.5, 29.8)],                   # 断面脚下的便道
]

ASPHALT = []
GRAVEL = [
    (23.8, 30.4, 4.2, 1.5),      # 孢子断面 02 脚下的粉尘泻堆
    (36.5, 28.2, 5.2, 1.7),      # 主断面泻堆
    (6.0, 11.5, 3.0, 1.4),       # 装卸台下的煤渣
    (30.0, 20.2, 3.6, 1.2),
]
MELT_BANDS = None

LIGHTS = dict(
    brazier=(14.5, 13.2),
    brazier_cut=(32.2, 25.6),
    lamp_west=(6.0, 4.4),
    lamp_east=(40.0, 4.4),
    signal=(20.0, 12.0),
)
LIGHT_RIG = ["facade_glow", "lamp_west", "lamp_east", "brazier", "brazier_cut", "signal"]
LIGHT_SEEDS = dict(lamp_west=5, lamp_east=13)

AMBIENCE = ["wind", "fire", "steam", "buzz"]

# 清杀队换岗（危险度 5，但没有探照灯——黑暗是这张图的第一属性）
PATROLS = [
    dict(id="OSK_Shift", mode="pingpong", pts=[(5.0, 7.2), (41.0, 7.2)], pause=2.4),
    dict(id="OSK_Square", mode="loop", pts=[(12.0, 12.4), (38.0, 12.4), (38.0, 20.2), (12.0, 20.2)],
         pause=1.8),
]

# 感染掘进工（孢子源头的注脚）：2 只，一只守断面
RABIDS = [
    dict(id="Rabid_Cart", home=(15.5, 18.8), radius=2.4, brute=False),
    dict(id="Rabid_Cut", home=(35.0, 26.2), radius=2.6, brute=True),
]

# 回退半人：留守技术员博伊科（0417）——守着起爆器，手背鳞屑正在剥落
HALFS = [
    dict(id="Half_Boiko", pos=(28.2, 27.6), tag="0417"),
]

# ===========================================================================
# 三个区（白 / 红 / 黑）—— 矿坑版：离「有人管」越远越黑
#   white: 装卸台（换岗队盯着的地方）  red: 工业广场（假人哨塔 + 巡逻）
#   black: 爆破作业面（证据、铝热剂、博伊科）—— 出生点与目标物都在黑区
# ===========================================================================
ZONES = [
    dict(id="white", zh="白区 · 安全区", en="WHITE ZONE · SAFE", rule="safe",
         rects=[(0.0, 0.0, 46.0, 11.0)],
         note_zh="装卸台：换岗队盯着的地方，可以站定了搜包"),
    dict(id="red", zh="红区 · 管制带", en="RED ZONE · CURFEW", rule="curfew",
         rects=[(0.0, 11.0, 46.0, 21.0)],
         note_zh="工业广场 · 假人哨塔 + 换岗巡逻 · 禁止停留"),
    dict(id="black", zh="黑区 · 沉降带", en="BLACK ZONE · SUNKEN", rule="sunken",
         rects=[(0.0, 21.0, 46.0, 34.0)],
         note_zh="爆破作业面：孢子断面、铝热剂与证据都在这一片"),
]

# 探照灯：无（假人哨塔是空壳——远看是防线，近看是塑料模特）
SEARCHLIGHT = None

# 立面关键点（x 米，供 gen_env._facade_mine 取用；本关不设 terminal / vent / tower 灯位）
FACADE_FEATURES = dict(portal_x=7.5, shack_x=19.0, bin_x=29.5, head_x=37.5, blast_x=42.0,
                       sign_x=13.0)
