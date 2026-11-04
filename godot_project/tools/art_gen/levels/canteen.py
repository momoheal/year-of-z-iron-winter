"""canteen · 东街工人食堂 · 后厨（2-1 白昼的溃烂 / L05 狭窄空间肉搏）—— 室内关。

危险度 3 / 夜长 90 分钟（≈216 秒）/ 寒冷 0.5 —— 冷库的恐怖是卫生的恐怖，食堂的恐怖是
「账面已清空」的恐怖：楼里还有十九只碗。

剧本锚点 = 总剧本 v4.2 场次 2-1（美术设计见
`docs/zh/Z年纪事_东街工人食堂场景美术设计.md`）：

    「账面已清空」的东街危楼里还有十九只碗。备餐台砧板上插着宽背生锈砍骨刀；
    杂物间单向窄门会被 40 度高烧的瓦西里冲开——独眼老炊事员费奥多尔守着灶。

所以场景里必须有：**十九只碗的长条桌**（账面 vs 活人的对照）、**砧板砍骨刀**
（guaranteed `blade` = 关键物资/武器）、**杂物间窄门**（`wedge` 机关：LOCS hint2
「窄门会被冲开」）、**黑麦糊桶**（送饭锚点）、**独眼老炊事员**（survivors）。

室内关（第一次）：FENCE_Y = None（build_scene 对无围栏关卡有护栏）；
平面图（44 × 32 米，x 向东 y 向南；北侧 = 厨房后墙立面）：

     0        8        16       24       32       40   44
   0 ┌────────────────────────────────────────────────┐
   3 │ ▤▤▤厨房后墙：炉罩+出餐口+磨砂窗(立面)▤▤▤▤▤▤▤▤ │  canteen 立面
   5 │ 灶🔥 蒸汽管▬▬▬▬▬▬▬▬▬▬▬  砧板★砍骨刀  窄门▣瓦西里│  后厨（黑区）
  10 │ 黑麦糊桶  独眼炊事员          后库:尸袋+铁柜     │
  15 │   配给箱        备餐台货架          铁柜        │  备餐间（红区）
  22 │                                               │
  25 │ 长桌1(碗)      长桌2(碗)      长桌3(碗)   火桶🔥│  礼堂（白区）←19只碗
  30 │ ──────────── 南门入口（出生 22,29.5 → 撤离 22,31.4）│
  32 └────────────────────────────────────────────────┘

⚠️ 本文件是「出过图」的版本：改数值就要重跑
   `python gen_assets.py --level canteen ground facade`（+ `props --only …` 仅限新道具）
   与 `python build_scene.py --level canteen`，并且 `python check_levels.py` 必须全绿。
"""
from math import pi

META = dict(
    id="canteen",
    zh="东街工人食堂 · 后厨",
    en="East Street Canteen · Kitchen",
    scene="res://scenes/night_canteen.tscn",
    manifest="night_canteen_manifest.json",
    facade="canteen",                               # 北侧立面：厨房后墙（炉罩 + 出餐口 + 磨砂窗）
    objective_zh="目标：备餐台砧板上的宽背砍骨刀（blade）· 账面已清空的楼里还有十九只碗",
    extract_zh="从南门礼堂入口撤离",
    prize="blade",                                  # 宽背生锈砍骨刀 =「东街锁骨里的砍骨刀」
    danger=3,
)

W, H = 44.0, 32.0
FACADE_H = 600

FACADE_BASE_Y = 3.0          # 厨房后墙墙脚线
FENCE_Y = None               # 室内关：没有铁丝网（build_scene 有护栏）
FENCE_GAP = (0.0, 0.0)
FENCE_SEGMENTS = []
TRACKS = []                  # 室内关：没有轨道
BALLAST_W = (1.9, 1.5)
SLAB_BAND = (3.0, 32.0)      # 室内：整层都是混凝土地面（雪只从破门/破窗飘进来）
INTERIOR = True              # 室内关：混凝土地面打底（bake_ground 全片曝光）

SPAWN = (22.0, 29.5)         # 南门入口（礼堂）
EXIT = (22.0, 31.4)          # 撤离点：原路出南门

# 道具：id, 资产名, 位置(底部中心), 碰撞脚印(米), 物理层, 容器
PROPS = [
    # --- 后厨（黑区，y 3~12）：40 度烧出来的东西住的地方 ---
    dict(id="Stove", art="PRP_Canteen_Stove", pos=(12.0, 5.0), fp=(2.6, 1.4), layer=2,
         occlude=False, fire=True),                 # 铸铁食堂灶（回温点 1）
    dict(id="SteamPipe", art="PRP_SteamPipe_Long", pos=(22.0, 4.6), fp=(12.0, 0.55), layer=2,
         ao="pipe"),                                # 厨房蒸汽管（steam 声源）
    dict(id="PrepBoard", art="PRP_CleaverBoard", pos=(24.0, 8.2), fp=(2.2, 1.1), layer=1,
         cont="hidden", guaranteed="blade"),        # ★ 砧板 + 宽背生锈砍骨刀
    dict(id="RyeVat", art="PRP_RyeVat", pos=(18.0, 9.8), fp=(1.6, 1.2), layer=1,
         cont="supply"),                            # ★ 黑麦糊大桶（十九个人的晚饭）
    dict(id="NarrowDoor", art="PRP_NarrowDoor", pos=(32.0, 4.6), fp=(2.0, 0.8), layer=1,
         fade=True),                                # ★ 杂物间单向窄门（wedge 机关载体）
    dict(id="BackLocker", art="PRP_Locker_ElectricCabinet", pos=(40.0, 7.5), fp=(0.9, 0.4),
         layer=1, cont="locker"),
    dict(id="BackCorpse", art="PRP_Corpse_Tarp", pos=(39.0, 10.6), fp=(1.7, 0.5), layer=0,
         cont="corpse"),                            # 后库的死者——「账面已清空」的反证
    # --- 备餐间（红区，y 12~22）：配给与货架 ---
    dict(id="SupplyCrates", art="PRP_SupplyCrates_Military", pos=(10.0, 15.5), fp=(1.9, 0.9),
         layer=1, cont="supply"),
    dict(id="PrepShelf", art="PRP_Crate_Wood_Stack", pos=(30.0, 16.5), fp=(1.7, 0.85),
         layer=1, cont="crate"),
    dict(id="LineLocker", art="PRP_Locker_ElectricCabinet", pos=(38.0, 19.0), fp=(0.9, 0.4),
         layer=1, cont="locker"),
    # --- 礼堂（白区，y 22~32）：十九只碗的地方 ---
    dict(id="Table1", art="PRP_Canteen_BenchTable", pos=(11.0, 25.0), fp=(5.2, 1.3), layer=1,
         cont="crate"),                             # 光板长条桌（碗都端在主桌那一排）
    dict(id="Table2", art="PRP_Canteen_Table", pos=(22.0, 25.0), fp=(5.2, 1.3), layer=1,
         cont="crate"),                             # ★ 十九只碗的主桌
    dict(id="Table3", art="PRP_Canteen_BenchTable", pos=(33.0, 25.0), fp=(5.2, 1.3), layer=1,
         cont="crate"),
    dict(id="HallStove", art="PRP_Brazier_OilDrum", pos=(39.5, 27.5), fp=(0.6, 0.45), layer=2,
         occlude=False, fire=True),                 # 礼堂火桶（回温点 2）
    dict(id="Stash", art="PRP_Crate_Wood_Stack", pos=(5.5, 28.5), fp=(1.7, 0.85), layer=1,
         cont="crate"),                             # 老工友们攒的私货
]

# 室内关：无铁丝网段
# 冻雪泥（踩上去 速度×0.65 噪声×2）：破门飘雪 + 灶边融水
SLUSH = [
    (22.0, 28.6, 2.2, 1.1),
    (12.5, 6.2, 1.8, 1.0),
]

# 油污 / 煤渣黑渍
TAR_STAINS = [(16.0, 7.0, 1.3), (28.0, 9.0, 1.1), (30.0, 16.0, 1.0), (12.0, 24.0, 1.2)]

# 踩出来的路径（折线）：南门 → 各桌 → 备餐台 → 灶
PATHS = [
    [(22.0, 30.5), (22.0, 25.0), (11.0, 25.0)],
    [(22.0, 25.0), (33.0, 25.0)],
    [(22.0, 25.0), (20.0, 16.0), (18.0, 9.8)],
    [(18.0, 9.8), (24.0, 8.2), (32.0, 5.5)],
]

ASPHALT = []
GRAVEL = [
    (24.0, 8.2, 2.4, 1.2),      # 砧板周的油腻地
    (39.0, 10.6, 2.0, 1.0),     # 后库尸袋周
]
MELT_BANDS = None

# ---- 灯光（对齐既有口径：LIGHTS 蛇形键 + LIGHT_RIG 序）----
# 灯位 rig 名由 `key.title().replace("_","")` 得出：lamp_dining→Lights/LampDining 等。
LIGHTS = dict(
    lamp_kitchen=(22.0, 8.5),    # 后厨吊灯
    lamp_dining=(22.0, 25.5),    # 礼堂吊灯
    brazier_stove=(12.0, 5.0),   # 食堂灶（火）
    brazier_hall=(39.5, 27.5),   # 礼堂火桶
)
LIGHT_RIG = ["facade_glow", "lamp_kitchen", "lamp_dining", "brazier_stove", "brazier_hall"]
LIGHT_SEEDS = dict(lamp_kitchen=7, lamp_dining=11)

AMBIENCE = ["wind", "fire", "steam", "buzz"]

# 清杀队：清楼小队穿过礼堂 + 备餐线巡一遍（「账面已清空」——他们清的是账）
PATROLS = [
    dict(id="OSK_Hall", mode="loop", pts=[(6.0, 26.0), (38.0, 26.0), (38.0, 18.0), (6.0, 18.0)],
         pause=2.2),
    dict(id="OSK_Line", mode="pingpong", pts=[(8.0, 15.0), (36.0, 15.0)], pause=2.0),
]

# 感染者：杂物间里的瓦西里（brute——40 度高烧的冲撞）+ 后库一只先变的
RABIDS = [
    dict(id="Rabid_Vasily", home=(32.5, 6.5), radius=2.0, brute=True),
    dict(id="Rabid_Back", home=(40.5, 5.5), radius=1.8, brute=False),
]

# 半人：无（瓦西里的回退发生在剧情里，不在关卡态里）
HALFS = []

# ===========================================================================
# 三个区（白 / 红 / 黑）—— 轴 = 离十九只碗越远越黑
#   white: 礼堂（长桌 + 十九只碗 + 火桶——活人吃饭的地方）
#   red:   备餐间（配给箱 / 货架——账上有数的地方）
#   black: 后厨与后库（砧板 / 窄门 / 尸袋——账面清空的地方）
# ===========================================================================
ZONES = [
    dict(id="white", zh="白区 · 安全区", en="WHITE ZONE · SAFE", rule="safe",
         rects=[(0.0, 22.0, 44.0, 32.0)],
         note_zh="礼堂：十九只碗的地方——活人吃饭的地方，可以站定了搜包"),
    dict(id="red", zh="红区 · 管制带", en="RED ZONE · CURFEW", rule="curfew",
         rects=[(0.0, 12.0, 44.0, 22.0)],
         note_zh="备餐间：账上有数的地方 · 禁止停留"),
    dict(id="black", zh="黑区 · 沉降带", en="BLACK ZONE · SUNKEN", rule="sunken",
         rects=[(0.0, 0.0, 44.0, 12.0)],
         note_zh="后厨与后库：账面清空的地方——砧板、窄门、尸袋都在这一片"),
]

# 黑市：无（食堂里没有生意，只有饭）
MARKET = None

# 探照灯：无（室内关）
SEARCHLIGHT = None

# 平民幸存者（build_scene 的 SURVIVORS 钩子 → World/Survivor_<i>，night_survivor 组）：
# 独眼老炊事员费奥多尔（守着灶）+ 一名没被清账的老铁路工（守着他的碗）。
SURVIVORS = [
    (13.5, 8.8),   # 费奥多尔（Survivor_0）：独眼老炊事员，儿子在窄门后面
    (15.0, 25.8),  # 老铁路工（Survivor_1）：十九只碗的主人之一
]

# 立面关键点（x 米，供 gen_env._facade_canteen 取用；不设 terminal / vent / tower 灯位）
FACADE_FEATURES = dict(hood_x=12.0, hatch_x=22.0, window_x=33.0)
