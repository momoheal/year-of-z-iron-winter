"""sanitarium · 旧传染病疗养院 · 地下室（3-2 地底铁笼 / L06）—— 室内关。

危险度 4 / 夜长 110 分钟（≈264 秒）/ 寒冷 0.8 —— 灰鳞病回退的现场：第四天熬过来的人
在这里掉鳞屑、瞳孔回色。铁笼、铁架床、两根皮带——安娜（0419）就是在这张床上把自己捆住的。

剧本锚点 = 总剧本 v4.2 场次 3-2（美术设计见
`docs/zh/Z年纪事_旧传染病疗养院场景美术设计.md`）：

    「档案号 0419 的年轻姑娘安娜正用两根旧皮带将自己的双手死死捆在铁架床栏杆上，
    硬生生熬过了退烧前最后一次神经风暴。」——头顶换气铁窗外，「铁壳号」贴路基驶过，
    闷罐车厢里退烧的人把病历单往雪地里抛。

所以场景里必须有：**钢筋铁笼列**（地底铁笼区）、**铁架床 + 两根皮带**（安娜的床）、
**药柜**（guaranteed `asp` = 关键物资，阿司匹林——安娜的最后半片的回声）、
**换气铁窗**（立面：贴路基的高窗）、**回退半人**（笼里掉鳞屑的活标本——「灰鳞病回退」）。

室内关：FENCE_Y = None；平面图（44 × 30 米，x 向东 y 向南；北侧 = 地下室北墙立面）：

     0        8        16       24       32       40   44
   0 ┌────────────────────────────────────────────────┐
   3 │ ▤▤▤地下室北墙：换气铁窗+铁门+管道(立面)▤▤▤▤▤▤▤ │  sanitarium 立面
   5 │ 笼1  笼2  ★铁架床(安娜+皮带) 笼3(回退半人) 笼4🔥│  铁笼区（黑区）
  11 │   石灰桶           笼区铁栅门▣(wedge)           │
  13 │ 蒸汽管▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ │
  16 │    尸袋          走廊              木箱         │  走廊（红区）
  21 │  药柜★(asp) 读片灯箱   标本冷柜   火炉🔥 火桶🔥  │  医生工作区（白区）
  25 │ 铁柜          梁诺夫 古丽娅                      │
  28 │ ──────────── 楼梯间（出生 22,27.5 → 撤离 22,29.2）│
  30 └────────────────────────────────────────────────┘

⚠️ 本文件是「出过图」的版本：改数值就要重跑
   `python gen_assets.py --level sanitarium ground facade`（+ `props --only …` 仅限新道具）
   与 `python build_scene.py --level sanitarium`，并且 `python check_levels.py` 必须全绿。
"""

META = dict(
    id="sanitarium",
    zh="旧传染病疗养院 · 地下室",
    en="Old Sanatorium · Basement",
    scene="res://scenes/night_sanitarium.tscn",
    manifest="night_sanitarium_manifest.json",
    facade="sanitarium",                            # 北侧立面：地下室北墙（换气铁窗 + 铁门）
    objective_zh="目标：药柜里的阿司匹林（asp）· 地底铁笼里有人熬过了第四天",
    extract_zh="从南侧楼梯间撤离",
    prize="asp",                                    # 阿司匹林 = 安娜的最后半片的回声
    danger=4,
)

W, H = 44.0, 30.0
FACADE_H = 600

FACADE_BASE_Y = 3.0          # 地下室北墙墙脚线
FENCE_Y = None               # 室内关：没有铁丝网
FENCE_GAP = (0.0, 0.0)
FENCE_SEGMENTS = []
TRACKS = []                  # 「铁壳号」在墙外的广轨弯道上——只在立面换气铁窗里看得见
BALLAST_W = (1.9, 1.5)
SLAB_BAND = (3.0, 30.0)      # 室内：混凝土地面
INTERIOR = True              # 室内关：混凝土地面打底（bake_ground 全片曝光）
# 室内地面材质（gen_env._interior_floor）：铁笼区是渗水的湿混凝土，走廊 + 医生区是起皮的牛血红地坪漆
FLOOR = {"zones": [("concrete", 3.0, 13.4), ("painted", 13.4, 30.0)]}

SPAWN = (22.0, 27.5)         # 南侧楼梯间（下地下室）
EXIT = (22.0, 29.2)          # 撤离点：原路回楼梯

# 道具：id, 资产名, 位置(底部中心), 碰撞脚印(米), 物理层, 容器
PROPS = [
    # --- 铁笼区（黑区，y 3~12）：灰鳞病回退的现场 ---
    dict(id="Cage01", art="PRP_IronCage", pos=(8.0, 5.0), fp=(3.2, 1.4), layer=1,
         cont="hidden"),                            # 钢筋铁笼（空的——账上的人去向不明）
    dict(id="Cage02", art="PRP_IronCage", pos=(15.0, 5.0), fp=(3.2, 1.4), layer=1,
         cont="hidden"),
    dict(id="CageBed", art="PRP_CageBed", pos=(23.0, 5.0), fp=(2.2, 1.2), layer=1,
         cont="hidden"),                            # ★ 安娜的铁架床 + 两根皮带
    dict(id="Cage03", art="PRP_IronCage", pos=(31.0, 5.0), fp=(3.2, 1.4), layer=1,
         cont="hidden"),                            # 回退半人关在这一笼（摆位注脚）
    dict(id="Cage04", art="PRP_IronCage", pos=(38.0, 5.0), fp=(3.2, 1.4), layer=1,
         cont="hidden"),
    dict(id="ChemDrum", art="PRP_ChemDrum", pos=(5.0, 9.5), fp=(1.2, 1.0), layer=1,
         cont="crate"),                             # 石灰 / 消毒桶
    dict(id="CageGate", art="PRP_CageGate", pos=(22.0, 11.0), fp=(3.4, 0.7), layer=1,
         fade=True),                                # ★ 笼区铁栅门（wedge 机关载体）
    # --- 走廊（红区，y 12~21）：收集班走的路 ---
    dict(id="SteamPipe", art="PRP_SteamPipe_Long", pos=(22.0, 13.5), fp=(12.0, 0.55), layer=2,
         ao="pipe"),                                # 暖气管（steam 声源）
    dict(id="CorridorCorpse", art="PRP_Corpse_Tarp", pos=(12.0, 16.5), fp=(1.7, 0.5), layer=0,
         cont="corpse"),                            # 盖着的——没熬过第四天的
    dict(id="CorridorCrate", art="PRP_Crate_Wood_Stack", pos=(34.0, 17.5), fp=(1.7, 0.85),
         layer=1, cont="crate"),
    # --- 医生工作区（白区，y 21~30）：师徒双医的地盘 ---
    dict(id="MedCabinet", art="PRP_MedCabinet", pos=(10.0, 23.5), fp=(1.6, 0.8), layer=1,
         cont="medcab", guaranteed="asp"),          # ★ 药柜（关键物资）
    dict(id="XrayBoard", art="PRP_XrayLightbox", pos=(16.0, 23.0), fp=(1.8, 0.6), layer=1,
         cont="briefcase"),                         # 读片灯箱 + 病历（回退手稿的前身）
    dict(id="SampleFridge", art="PRP_ColdStore_Chest", pos=(28.0, 24.0), fp=(2.6, 1.1),
         layer=1, cont="fridge"),                   # 标本冷柜
    dict(id="ClinicStove", art="PRP_Brazier_OilDrum", pos=(35.0, 22.5), fp=(0.6, 0.45),
         layer=2, occlude=False, fire=True),        # 火炉（回温点 1）
    dict(id="ClinicBrazier", art="PRP_Brazier_OilDrum", pos=(39.5, 25.5), fp=(0.6, 0.45),
         layer=2, occlude=False, fire=True),        # 火桶（回温点 2）
    dict(id="Locker", art="PRP_Locker_ElectricCabinet", pos=(6.0, 26.5), fp=(0.9, 0.4),
         layer=1, cont="locker"),
]

# 冻雪泥：楼梯间飘雪 + 火边融水
SLUSH = [
    (22.0, 28.2, 2.0, 1.0),
    (35.0, 23.8, 1.6, 0.9),
]

# 石灰渍 / 霉斑
TAR_STAINS = [(5.0, 9.5, 1.2), (31.0, 8.5, 1.0), (12.0, 16.5, 1.1), (28.0, 24.0, 1.0)]

# 踩出来的路径（折线）：楼梯 → 工作区 → 走廊 → 笼区
PATHS = [
    [(22.0, 28.6), (18.0, 23.5), (10.0, 23.5)],
    [(18.0, 23.5), (22.0, 17.0), (12.0, 16.5)],
    [(22.0, 17.0), (22.0, 11.5), (23.0, 6.0)],
    [(22.0, 11.5), (31.0, 6.5), (38.0, 6.0)],
]

ASPHALT = []
GRAVEL = [
    (23.0, 6.2, 2.2, 1.0),      # 铁架床周的草屑
    (12.0, 16.5, 1.8, 0.9),
]
MELT_BANDS = None

# ---- 灯光（对齐既有口径：LIGHTS 蛇形键 + LIGHT_RIG 序）----
LIGHTS = dict(
    lamp_cage=(22.0, 7.5),       # 笼区吊灯（冷白——LIGHT_COLORS）
    lamp_office=(14.0, 23.2),    # 工作区灯（暖）
    brazier_clinic=(35.0, 22.5), # 火炉
    brazier_heater=(39.5, 25.5), # 火桶
)
LIGHT_RIG = ["facade_glow", "lamp_cage", "lamp_office", "brazier_clinic", "brazier_heater"]
LIGHT_SEEDS = dict(lamp_cage=5, lamp_office=13)
LIGHT_COLORS = dict(lamp_cage=(0.72, 0.85, 1.0))   # 笼区冷白吊灯

AMBIENCE = ["wind", "fire", "steam", "buzz"]

# 清杀队：收集班（把退烧的人装上「铁壳号」的那班人）
PATROLS = [
    dict(id="OSK_Cages", mode="loop", pts=[(8.0, 9.0), (36.0, 9.0), (36.0, 11.5), (8.0, 11.5)],
         pause=2.2),
    dict(id="OSK_Corridor", mode="pingpong", pts=[(8.0, 17.0), (36.0, 17.0)], pause=2.4),
]

# 感染者：笼里没熬过第四天的（brute = 那个一直撞栏杆的）
RABIDS = [
    dict(id="Rabid_Cage01", home=(8.5, 6.2), radius=1.5, brute=False),
    dict(id="Rabid_Cage02", home=(15.5, 6.2), radius=1.5, brute=False),
    dict(id="Rabid_Cage04", home=(38.5, 6.2), radius=1.6, brute=True),
]

# 半人：笼3 的回退半人（掉鳞屑、瞳孔正在回色——「灰鳞病回退」的活标本）
HALFS = [
    dict(id="Half_Cage0442", pos=(31.0, 6.2), tag="0442"),   # 笼3 的回退半人（掉鳞屑、瞳孔回色）
]

# ===========================================================================
# 三个区（白 / 红 / 黑）—— 轴 = 离医生的工作区越远越黑
#   white: 医生工作区（药柜 / 读片灯箱 / 火炉——活着的人在照顾人）
#   red:   走廊（收集班走的路）
#   black: 铁笼区（笼列 / 铁架床 / 回退半人——掉鳞屑的地方）
# ===========================================================================
ZONES = [
    dict(id="white", zh="白区 · 安全区", en="WHITE ZONE · SAFE", rule="safe",
         rects=[(0.0, 21.0, 44.0, 30.0)],
         note_zh="医生工作区：师徒双医照顾人的地方，可以站定了搜包"),
    dict(id="red", zh="红区 · 管制带", en="RED ZONE · CURFEW", rule="curfew",
         rects=[(0.0, 12.0, 44.0, 21.0)],
         note_zh="走廊：收集班走的路 · 禁止停留"),
    dict(id="black", zh="黑区 · 沉降带", en="BLACK ZONE · SUNKEN", rule="sunken",
         rects=[(0.0, 0.0, 44.0, 12.0)],
         note_zh="铁笼区：掉鳞屑的地方——笼列、铁架床、回退半人都在这一片"),
]

# 黑市：无（疗养院里没有生意，只有病）
MARKET = None

# 探照灯：无（室内关）
SEARCHLIGHT = None

# 平民幸存者（build_scene 的 SURVIVORS 钩子 → World/Survivor_<i>，night_survivor 组）：
# 安娜（0419，铁架床边）+ 梁诺夫医生 + 古丽娅（工作区）。
SURVIVORS = [
    (22.3, 5.8),   # 安娜（Survivor_0）：档案号 0419，熬过第四天
    (13.5, 23.8),  # 梁诺夫医生（Survivor_1）：老眼科主任
    (17.5, 24.2),  # 古丽娅（Survivor_2）：女流调医师
]

# 立面关键点（x 米，供 gen_env._facade_sanitarium 取用；不设 terminal / vent / tower 灯位）
FACADE_FEATURES = dict(vent_x=22.0, door_x=8.0, pipe_x=36.0)
