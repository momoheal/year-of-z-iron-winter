"""market · 铁路黑市（废弃工人镇）—— v4.2 第三幕 3-3 前半的夜潜舞台。

危险度 2 / 夜长 80 分钟（≈192 秒）/ 寒冷 0.9 —— 人比冷可怕，但人还肯讲理。

剧本锚点 = 总剧本 v4.2 场次 3-3（美术设计见
`docs/zh/Z年纪事_铁路黑市场景美术设计.md`）：

    抉择 C 的发生地——老谢苗守在药棚铁门外（C1 公平合作 / C2 锁门背叛抢盘尼西林与
    门禁磁卡 / C3 倾囊相助）；黑市最深的棚子上架着钉死在 6.66 MHz 的短波收音机，
    棚后巷的炭炉在做「烙铁烫鳞」；掺防冻液的假药和真药摆在同一个摊区里（辨药三分法）。

所以场景里必须有：**6.66 电台棚**（guaranteed `intel` = 专列调度记录）、**药棚铁门**
（C2 的锁点 + 盘尼西林冷柜）、**真药 / 假药对照摆位**、**烫鳞炭炉**（只有工具和痕迹，
不画行刑现场）、**老谢苗与拾荒老妇**（MARKET survivors 列表扩到 4 人）。

平面图（46 × 34 米，x 向东 y 向南；北侧 = 工人镇板房立面）：

      0        8        16       24       32       40      46
    0 ┌──────────────────────────────────────────────────────┐
    3 │ ▤板房▤ 烟囱  ▤板房▤   板房  ▤板房▤ 烟囱 ▤板房▤   │  工人镇立面
    5 │ 壁灯 规矩牌   破损供暖管▬▬▬▬▬▬▬▬▬▬▬▬▬▬  街灯      │  镇口街（白区）↑出生
   10 │   电柜                         木箱        垃圾箱    │
   13 │   板房01        板房02           板房03              │  棚户巷（红区）
   21 │                                                      │
   23 │ 药棚▣铁门  老谢苗 拾荒老妇 ▣假药摊  摊区▣(Market)    │  市集（黑区）
   25 │ 炭炉🔥(烫鳞)  真药箱       篝火🔥  6.66棚(天线)▤ 冻尸│
   27 │ ═══════════════ 铁路 1 道（y=27.0）══════════════════ │
   29 │ 感染者  撕裂网  ╳豁口╳  撕裂网      感染者           │  南侧铁丝网
   34 └──────────────────────────────────────────────────────┘
                              ↑ 撤离 (22.0, 32.6)

⚠️ 铁丝网贴图高 3.93 m（pivot 148/156）：轨道必须离 FENCE_Y ≥ 4 m，否则整条被网吞掉
   （第一版把轨道放在 30.5、围栏 32.2，渲染出来轨道直接消失——铁律）。

⚠️ 本文件是「出过图」的版本：改数值就要重跑
   `python gen_assets.py --level market ground`（+ `props --only …` 仅限新道具）
   与 `python build_scene.py --level market`，并且 `python check_levels.py` 必须全绿。
"""

META = dict(
    id="market",
    zh="铁路黑市（废弃工人镇）",
    en="Rail Black Market",
    scene="res://scenes/night_market.tscn",
    manifest="night_market_manifest.json",
    facade="town",                                   # 北侧立面：工人镇板房排屋
    objective_zh="目标：6.66 电台棚里的专列调度记录（intel）· 拿东西换东西，别信递过来的手",
    extract_zh="回铁路侧铁丝网豁口撤离",
    prize="intel",                                   # 专列调度记录 = C1 线的物证
    danger=2,
)

W, H = 46.0, 34.0
FACADE_H = 600

FACADE_BASE_Y = 3.0          # 板房排屋墙脚线
FENCE_Y = 33.2               # 南侧铁丝网（贴图高 3.93 m，顶到 29.3 m）
FENCE_GAP = (20.5, 23.5)
TRACKS = [27.0]              # 铁路 1 道（离围栏 6.2 m——网吞不掉）
BALLAST_W = (1.9, 1.5)
SLAB_BAND = (3.0, 9.0)       # 只有镇口街是旧沥青

SPAWN = (8.0, 4.6)           # 北侧镇口街（白区开局——先穿过人的地盘，再下到黑里）
EXIT = (22.0, 32.6)          # 撤离点：铁路侧豁口

# 道具：id, 资产名, 位置(底部中心), 碰撞脚印(米), 物理层, 容器
# 建筑与摊位一律坐在轨道（27.0±0.7 m）以北；只有演员 / 感染者 / 冻尸可以上轨道
PROPS = [
    # --- 镇口街（白区，y 3~11）：摊主们的规矩区 ---
    dict(id="StreetLamp", art="PRP_StreetLamp_Sodium", pos=(12.5, 5.4), fp=(0.3, 0.25), layer=1,
         occlude=False, ao="post"),
    dict(id="RulesBoard", art="PRP_DispatchBoard_Tin", pos=(7.5, 4.9), fp=(1.7, 0.6), layer=1,
         occlude=False),                            # 规矩牌：「拿东西换东西」
    dict(id="SteamPipe", art="PRP_SteamPipe_Long", pos=(22.0, 8.2), fp=(28.0, 0.55), layer=2,
         ao="pipe"),                                # 破损供暖管（steam 声源）
    dict(id="Locker", art="PRP_Locker_ElectricCabinet", pos=(5.0, 7.8), fp=(0.9, 0.4),
         layer=1, cont="locker"),
    # --- 棚户巷（红区，y 11~21）：各派系互不信任的地盘 ---
    dict(id="Shanty01", art="PRP_Shanty_Shed", pos=(10.0, 15.5), fp=(3.6, 1.6), layer=1,
         fade=True),
    dict(id="Shanty02", art="PRP_Shanty_Shed", pos=(22.0, 17.0), fp=(3.6, 1.6), layer=1,
         fade=True),
    dict(id="Shanty03", art="PRP_Shanty_Shed", pos=(34.0, 15.0), fp=(3.6, 1.6), layer=1,
         fade=True),
    dict(id="TownCrates", art="PRP_Crate_Wood_Stack", pos=(30.0, 12.4), fp=(1.7, 0.85),
         layer=1, cont="crate"),
    dict(id="Dumpster", art="PRP_Dumpster_Steel", pos=(42.0, 12.8), fp=(1.7, 0.9), layer=1,
         cont="dumpster"),
    # --- 市集（黑区，y 21~34）：抉择 C / 辨药 / 6.66 全在这一片 ---
    dict(id="MedShed", art="PRP_MedShed", pos=(12.0, 23.2), fp=(3.2, 1.6), layer=1,
         fade=True),                                # 药棚 + 铁门（C2 锁点）
    dict(id="MedFridge", art="PRP_ColdStore_Chest", pos=(12.8, 24.0), fp=(1.6, 0.8), layer=1,
         cont="fridge", guaranteed="abx"),          # ★ 盘尼西林（C2 的目标）
    dict(id="MedCache", art="PRP_MedCache", pos=(10.6, 24.6), fp=(1.2, 0.7), layer=1,
         cont="medcab"),                            # 真药（朴素白瓶）
    dict(id="ShedCrates", art="PRP_Crate_Wood_Stack", pos=(13.9, 24.4), fp=(1.7, 0.85),
         layer=1, cont="crate"),
    dict(id="QuackForge", art="PRP_QuackForge", pos=(7.0, 24.9), fp=(1.6, 1.0), layer=2,
         occlude=False),                            # 烫鳞炭炉（只有工具和痕迹）
    dict(id="MedStall", art="PRP_Market_Stall", pos=(19.0, 23.0), fp=(1.8, 0.9), layer=1),
    dict(id="FakeMeds", art="PRP_MedCache", pos=(19.2, 24.0), fp=(1.2, 0.7), layer=1,
         cont="medcab"),                            # 假药（花哨商标——对照摆位）
    dict(id="BazaarFire", art="PRP_Brazier_OilDrum", pos=(28.5, 25.2), fp=(0.6, 0.45), layer=2,
         occlude=False, fire=True),                 # 市集篝火（回温点 1）
    dict(id="SupplyCrates", art="PRP_SupplyCrates_Military", pos=(30.5, 23.6), fp=(1.9, 0.9),
         layer=1, cont="supply"),
    dict(id="Radio666", art="PRP_Radio666", pos=(36.5, 25.0), fp=(2.6, 1.4), layer=1,
         cont="briefcase", guaranteed="intel", reach=(0.0, 0.3)),  # ★ 6.66 电台棚
    dict(id="Corpse", art="PRP_Corpse_Tarp", pos=(33.0, 27.0), fp=(1.7, 0.5), layer=0,
         cont="corpse"),                            # 冻死在铁轨上的拾荒者
    dict(id="LampEast", art="PRP_StreetLamp_Sodium", pos=(41.5, 22.5), fp=(0.3, 0.25), layer=1,
         occlude=False, ao="post"),
]

# 铁丝网段：(x0, 资产)。每段 4m；豁口两侧用「撕裂」变体
FENCE_SEGMENTS = [(0.0, "a"), (4.0, "a"), (8.0, "b"), (12.0, "a"), (16.0, "a"),
                  (20.5, "torn"), (23.5, "torn_l"), (27.5, "a"), (31.5, "b"),
                  (35.5, "a"), (39.5, "a"), (43.5, "b")]

# 冻雪泥（踩上去 速度×0.65 噪声×2）：火边融雪 / 街灯下
SLUSH = [
    (28.5, 25.2, 2.0, 1.3),
    (7.0, 24.9, 1.7, 1.1),
    (24.5, 24.6, 2.4, 1.3),
    (12.5, 5.4, 2.2, 1.0),
]

# 煤渣黑雪
TAR_STAINS = [(20.0, 20.0, 1.2), (38.0, 17.0, 1.0), (9.0, 25.6, 1.1), (42.0, 25.0, 1.0)]

# 踩出来的雪径（折线）
PATHS = [
    [(8.0, 4.8), (9.0, 9.0), (11.0, 14.0), (14.0, 19.0), (18.0, 21.5), (24.5, 24.2)],
    [(24.5, 24.2), (18.0, 23.8), (12.0, 23.4)],          # → 药棚
    [(24.5, 24.2), (30.0, 24.8), (36.0, 24.9)],          # → 6.66 棚
    [(24.5, 24.2), (22.0, 27.5), (22.0, 32.2)],          # → 越过铁轨、撤离豁口
]

ASPHALT = []
GRAVEL = [
    (36.0, 28.6, 3.5, 1.2),
    (6.0, 22.0, 3.0, 1.2),
    (30.0, 21.0, 3.0, 1.0),
]
MELT_BANDS = None

LIGHTS = dict(
    lamp_nw=(12.5, 5.4),
    lamp_se=(41.5, 22.5),
    brazier_bazaar=(28.5, 25.2),
    brazier_forge=(7.0, 24.9),
)
LIGHT_RIG = ["facade_glow", "lamp_nw", "lamp_se", "brazier_bazaar", "brazier_forge"]
LIGHT_SEEDS = dict(lamp_nw=5, lamp_se=13)

AMBIENCE = ["wind", "fire", "steam", "buzz"]

# 清杀队：棚户巷巡逻 + 铁路哨兵（C2 里被老谢苗引开的就是铁路哨兵——他沿着铁轨走）
PATROLS = [
    dict(id="OSK_Town", mode="loop", pts=[(12.0, 13.0), (36.0, 13.0), (36.0, 20.0), (12.0, 20.0)],
         pause=2.0),
    dict(id="OSK_Rail", mode="pingpong", pts=[(20.0, 28.2), (42.0, 28.2)], pause=2.4),
]

# 感染者：铁轨上的流浪者（低危交易关，尸是注脚）
RABIDS = [
    dict(id="Rabid_Rail", home=(39.0, 27.4), radius=2.2, brute=False),
    dict(id="Rabid_Alley", home=(4.5, 27.6), radius=2.2, brute=False),
]

# 半人：无（老谢苗是幸存者，不是回退半人）
HALFS = []

# ===========================================================================
# 三个区（白 / 红 / 黑）—— 黑市老家版：轴 = 离「摊主规矩区」的距离
#   white: 镇口街（规矩牌下、街灯里）  red: 棚户巷（各派系的地盘）
#   black: 市集深处 + 铁路侧——摊区、6.66 棚、烫鳞后巷、药棚铁门（抉择 C 全在这）
# ===========================================================================
ZONES = [
    dict(id="white", zh="白区 · 安全区", en="WHITE ZONE · SAFE", rule="safe",
         rects=[(0.0, 0.0, 46.0, 11.0)],
         note_zh="镇口街：摊主们的规矩区，可以站定了搜包"),
    dict(id="red", zh="红区 · 管制带", en="RED ZONE · CURFEW", rule="curfew",
         rects=[(0.0, 11.0, 46.0, 21.0)],
         note_zh="棚户巷：各派系互不信任的地盘 · 禁止停留"),
    dict(id="black", zh="黑区 · 沉降带", en="BLACK ZONE · SUNKEN", rule="sunken",
         rects=[(0.0, 21.0, 46.0, 34.0)],
         note_zh="市集与铁路侧：黑市摊区、6.66 棚、烫鳞后巷、抉择 C 的铁门都在这一片"),
]

# 黑市摊区（build_scene 自动装配：摊位 + 摊主 + 幸存者 + 马灯；烟测要求在黑区）
MARKET = dict(
    pos=(24.5, 24.4), trader=(25.5, 24.8),
    survivors=[(23.0, 25.4), (26.2, 25.6), (12.5, 24.6), (17.5, 25.2)],
    cans=1, ammo=8,
    zh="黑市 · 一罐换八发", en="BLACK MARKET",
)
# survivors[2] = 老谢苗（药棚铁门旁）；survivors[3] = 拾荒老妇（角落里快冻死）

# 探照灯：无（危险度 2：这里是人和人互相看着的地方）
SEARCHLIGHT = None

# 立面关键点（x 米，供 gen_env._facade_town 取用；不设 terminal / vent / tower 灯位）
FACADE_FEATURES = dict(lamp_x=4.5, window_x=22.0, stove_x=36.0)
