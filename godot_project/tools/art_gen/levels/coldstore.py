"""coldstore · 城北四号铁路冷库（账面死人）—— v4.2 第一幕 1-3 白昼段的夜潜舞台。

危险度 2 / 夜长 80 分钟（≈192 秒）/ 寒冷 0.9 —— 冷库的恐怖是卫生的恐怖。

剧本锚点 = 总剧本 v4.2 场次 1-3（美术设计见
`docs/zh/Z年纪事_铁路冷库场景美术设计.md`）：

    「账面死人」关——磁卡终端跳红字【档案0892：已于昨日22:00移交乌拉尔山线站。
    当前南库坐标在册人数：0】，配给箱电子锁直接锁死；可南库 3 号立柱后缩着被转运车
    遗落、冻得濒死的谢尔盖与玛丽亚母子。北雨棚 12cm 排水窄缝里曾伸出一只刮烂的胳膊。

所以场景里必须有：**磁卡终端**（红字屏——全图唯一的红）、**3 号柱后的母子**、
**封存医疗耗材箱**（guaranteed `abx` = 关键物资）、**12cm 排水窄缝**（只有痕迹）、
**冷库铁门**（`wedge` 机关：LOCS hint2「冷库铁门可以撬棍卡死」）。

平面图（46 × 34 米，x 向东 y 向南；北侧 = 冷库主楼立面）：

      0        8        16       24       32       40      46
    0 ┌──────────────────────────────────────────────────────┐
    3 │ ▤▤▤冷库主楼：保温板+冷风机+值班窗+铁路大门(26) ▤▤▤ │  coldstore 立面
    5 │ 月台灯 收发亭 磁卡终端 配给箱  破损管▬▬▬▬▬▬  排水缝 │  月台（白区）↑出生
   10 │   电柜     封存耗材(托盘)        木箱      垃圾箱    │
   13 │   货架1           货架2            货架3             │  堆场（红区）
   22 │ 值班炉🔥 1号柱  2号柱  3号柱★母子  4号柱  冷库铁门▣  │  南库（黑区）
   25 │ 真药箱▣(abx)        吊灯(冷白)            冻尸 火桶🔥│
   27 │ ═════════ 铁路专用线（y=27.0）+ 冷藏车皮 ═══════════ │
   29 │ 感染者  撕裂网  ╳豁口╳  撕裂网      感染者           │  南侧铁丝网(33.2)
   34 └──────────────────────────────────────────────────────┘
                              ↑ 撤离 (22.0, 32.6)

⚠️ 铁丝网贴图高 3.93 m：轨道必须离 FENCE_Y ≥ 4 m（27.0 vs 33.2 = 6.2 m）；
   建筑与货架只许坐在轨道以北，冷藏车皮是车辆、可以上轨道。

⚠️ 本文件是「出过图」的版本：改数值就要重跑
   `python gen_assets.py --level coldstore ground`（+ `props --only …` 仅限新道具）
   与 `python build_scene.py --level coldstore`，并且 `python check_levels.py` 必须全绿。
"""

META = dict(
    id="coldstore",
    zh="城北四号铁路冷库",
    en="Rail Cold Storage No.4",
    scene="res://scenes/night_coldstore.tscn",
    manifest="night_coldstore_manifest.json",
    facade="coldstore",                              # 北侧立面：冷库主楼（保温板 + 冷风机）
    objective_zh="目标：南库封存的医疗耗材箱（abx）· 档案 0892 说这里在册人数 0，可柱子后面全是活人",
    extract_zh="回铁路专用线侧铁丝网豁口撤离",
    prize="abx",                                     # 封存抗生素 =「真药到底在哪」的另一半答案
    danger=2,
)

W, H = 46.0, 34.0
FACADE_H = 600

FACADE_BASE_Y = 3.0          # 冷库主楼墙脚线
FENCE_Y = 33.2               # 南侧铁丝网（贴图高 3.93 m，顶到 29.3 m）
FENCE_GAP = (20.5, 23.5)
TRACKS = [27.0]              # 铁路专用线（离围栏 6.2 m）
BALLAST_W = (1.9, 1.5)
SLAB_BAND = (3.0, 9.0)       # 只有月台是混凝土

SPAWN = (8.0, 4.6)           # 北侧月台（白区开局：先过「账面在册」的月台）
EXIT = (22.0, 32.6)          # 撤离点：铁路专用线侧豁口

# 道具：id, 资产名, 位置(底部中心), 碰撞脚印(米), 物理层, 容器
PROPS = [
    # --- 月台（白区，y 3~11）：「账面在册」的地方 ---
    dict(id="DockLamp", art="PRP_StreetLamp_Sodium", pos=(12.5, 5.4), fp=(0.3, 0.25), layer=1,
         occlude=False, ao="post"),
    dict(id="CardTerminal", art="PRP_CardTerminal", pos=(14.5, 5.2), fp=(1.1, 0.55), layer=1,
         occlude=False),                            # ★ 磁卡终端（红字：在册人数 0）
    dict(id="RationBox", art="PRP_SupplyCrates_Military", pos=(18.0, 5.0), fp=(1.9, 0.9),
         layer=1, cont="supply"),                   # 配给箱（电子锁锁死的那箱）
    dict(id="SteamPipe", art="PRP_SteamPipe_Long", pos=(30.0, 8.2), fp=(12.0, 0.55), layer=2,
         ao="pipe"),
    dict(id="Locker", art="PRP_Locker_ElectricCabinet", pos=(5.0, 7.8), fp=(0.9, 0.4),
         layer=1, cont="locker"),
    dict(id="DrainSlit", art="PRP_DrainSlit", pos=(33.5, 3.9), fp=(2.2, 0.5), layer=1,
         occlude=False),                            # ★ 12cm 排水窄缝 + 刮烂的铝饭盒
    # --- 堆场（红区，y 11~21）：「账上有货」的地方 ---
    dict(id="Rack01", art="PRP_Crate_Wood_Stack", pos=(10.0, 14.5), fp=(1.7, 0.85), layer=1,
         cont="crate"),
    dict(id="Rack02", art="PRP_Crate_Wood_Stack", pos=(24.0, 15.5), fp=(1.7, 0.85), layer=1,
         cont="crate"),
    dict(id="Rack03", art="PRP_Crate_Wood_Stack", pos=(38.0, 14.5), fp=(1.7, 0.85), layer=1,
         cont="crate"),
    dict(id="Dumpster", art="PRP_Dumpster_Steel", pos=(43.0, 12.0), fp=(1.7, 0.9), layer=1,
         cont="dumpster"),
    # --- 南库（黑区，y 21~34）：「账面死人」的舞台 ---
    dict(id="DutyBooth", art="PRP_Shanty_Shed", pos=(8.0, 23.6), fp=(3.6, 1.6), layer=1,
         fade=True),                                # 收发亭 / 值班室（板房 + 炉筒 = 暖）
    dict(id="DutyFire", art="PRP_Brazier_OilDrum", pos=(9.2, 25.2), fp=(0.6, 0.45), layer=2,
         occlude=False, fire=True),                 # 值班室火炉（回温点 1）
    dict(id="Column01", art="PRP_VaultColumn", pos=(14.0, 23.5), fp=(1.1, 1.1), layer=1),
    dict(id="Column02", art="PRP_VaultColumn", pos=(19.5, 23.5), fp=(1.1, 1.1), layer=1),
    dict(id="Column03", art="PRP_VaultColumn", pos=(25.0, 23.5), fp=(1.1, 1.1), layer=1),
    dict(id="Column04", art="PRP_VaultColumn", pos=(30.5, 23.5), fp=(1.1, 1.1), layer=1),
    dict(id="SealedMeds", art="PRP_SealedMedCrate", pos=(11.5, 25.2), fp=(1.5, 0.8), layer=1,
         cont="medcab", guaranteed="abx"),          # ★ 封存医疗耗材箱
    dict(id="ColdVaultDoor", art="PRP_ColdVaultDoor", pos=(37.5, 23.6), fp=(3.4, 1.0),
         layer=1, fade=True),                       # ★ 冷库铁门（wedge 机关载体）
    dict(id="Freezer", art="PRP_ColdStore_Chest", pos=(33.0, 25.4), fp=(2.6, 1.1), layer=1,
         cont="fridge"),
    dict(id="Corpse", art="PRP_Corpse_Tarp", pos=(28.5, 27.2), fp=(1.7, 0.5), layer=0,
         cont="corpse"),                            # 冻死在专用线上的装卸工
    dict(id="WorkerFire", art="PRP_Brazier_OilDrum", pos=(41.0, 25.2), fp=(0.6, 0.45), layer=2,
         occlude=False, fire=True),                 # 工人火桶（回温点 2）
    dict(id="Reefer", art="PRP_Buran_Boxcar03", pos=(2.0, 27.0), fp=(10.8, 1.7), layer=1,
         fade=True),   # 冷藏车皮（专用线西端、探出画面西缘——11m 车体不许埋住封存药箱）
]

# 铁丝网段：(x0, 资产)。每段 4m；豁口两侧用「撕裂」变体
FENCE_SEGMENTS = [(0.0, "a"), (4.0, "a"), (8.0, "b"), (12.0, "a"), (16.0, "a"),
                  (20.5, "torn"), (23.5, "torn_l"), (27.5, "a"), (31.5, "b"),
                  (35.5, "a"), (39.5, "a"), (43.5, "b")]

# 冻雪泥（踩上去 速度×0.65 噪声×2）：火边与灯下融雪
SLUSH = [
    (9.2, 25.2, 1.7, 1.1),
    (41.0, 25.2, 1.7, 1.1),
    (24.5, 24.6, 2.2, 1.2),
    (12.5, 5.4, 2.2, 1.0),
]

# 煤渣黑雪
TAR_STAINS = [(20.0, 20.0, 1.2), (38.0, 17.0, 1.0), (9.0, 25.6, 1.1), (42.0, 25.0, 1.0)]

# 踩出来的雪径（折线）
PATHS = [
    [(8.0, 4.8), (9.0, 9.0), (11.0, 14.0), (14.0, 19.0), (18.0, 21.5), (24.5, 24.2)],
    [(24.5, 24.2), (18.0, 23.8), (11.5, 24.6)],          # → 封存医疗箱
    [(24.5, 24.2), (30.0, 23.8), (37.0, 23.6)],          # → 冷库铁门
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
    lamp_dock=(12.5, 5.4),
    lamp_hall=(24.5, 24.6),
    brazier_duty=(9.2, 25.2),
    brazier_worker=(41.0, 25.2),
)
LIGHT_RIG = ["facade_glow", "lamp_dock", "lamp_hall", "brazier_duty", "brazier_worker"]
LIGHT_SEEDS = dict(lamp_dock=5, lamp_hall=17)
LIGHT_COLORS = dict(lamp_hall=(0.72, 0.85, 1.0))   # 南库吊灯：冷白（_rig_lamp 按 key 覆盖琥珀默认）

AMBIENCE = ["wind", "fire", "steam", "buzz"]

# 清杀队：堆场巡逻 + 专用线哨兵
PATROLS = [
    dict(id="OSK_Dock", mode="loop", pts=[(12.0, 13.0), (36.0, 13.0), (36.0, 20.0), (12.0, 20.0)],
         pause=2.0),
    dict(id="OSK_Rail", mode="pingpong", pts=[(20.0, 28.2), (42.0, 28.2)], pause=2.4),
]

# 感染者：专用线上的两只（低危关，尸是注脚）
RABIDS = [
    dict(id="Rabid_Rail", home=(39.0, 27.4), radius=2.2, brute=False),
    dict(id="Rabid_Store", home=(4.5, 27.6), radius=2.2, brute=False),
]

# 半人：无（1-3 的回退半人在 yard——探照灯下的母亲；冷库是账面死人的舞台）
HALFS = []

# ===========================================================================
# 三个区（白 / 红 / 黑）—— 账面死人版：轴 = 离「账面在册」的地方越远越黑
#   white: 月台（收发亭 / 磁卡终端 / 配给箱——「在册」的地方）
#   red:   堆场（货架 / 托盘 / 车皮——「账上有货」的地方）
#   black: 南库（柱列、3 号柱的活人、封存药、铁轨——「账面没人」的地方）
# ===========================================================================
ZONES = [
    dict(id="white", zh="白区 · 安全区", en="WHITE ZONE · SAFE", rule="safe",
         rects=[(0.0, 0.0, 46.0, 11.0)],
         note_zh="月台：磁卡终端管着的地方——「在册」的地方，可以站定了搜包"),
    dict(id="red", zh="红区 · 管制带", en="RED ZONE · CURFEW", rule="curfew",
         rects=[(0.0, 11.0, 46.0, 21.0)],
         note_zh="堆场：账上有货的地方 · 禁止停留"),
    dict(id="black", zh="黑区 · 沉降带", en="BLACK ZONE · SUNKEN", rule="sunken",
         rects=[(0.0, 21.0, 46.0, 34.0)],
         note_zh="南库：账面说没人——柱列、3 号柱后的活人、封存药、铁轨都在这一片"),
]

# 黑市：无（冷库里没有生意，只有账）
MARKET = None

# 平民幸存者（build_scene 的 SURVIVORS 钩子 → World/Survivor_<i>，night_survivor 组）：
# 被转运车遗落、冻得濒死的母子——「账面死人」里唯一能证明账错了的两个人。
SURVIVORS = [
    (24.2, 24.8),   # Sergey（Survivor_0）：通行证查无此人
    (25.8, 25.0),   # Maria（Survivor_1）：把孩子护在怀里
]

# 探照灯：无（危险度 2：冷库的恐怖在灯下，不在光柱里）
SEARCHLIGHT = None

# 立面关键点（x 米，供 gen_env._facade_coldstore 取用；不设 terminal / vent / tower 灯位）
FACADE_FEATURES = dict(door_x=26.0, office_x=10.0, unit_x=38.0)
