"""夜间广轨货场（L03 · yard）手工关卡布局 —— 单位：逻辑米。

这是地面烘焙（gen_assets.py）与场景生成（build_scene.py）共用的唯一数据源。
坐标系：x 向东，y 向南；屏幕像素 = (x*64, y*64*0.62)。
"""

W, H = 48.0, 40.0

FACADE_BASE_Y = 3.0          # 赫鲁晓夫楼立面的墙脚线
FENCE_Y = 21.5               # 铁丝网
FENCE_GAP = (20.0, 23.5)     # 被剪开的豁口
TRACKS = [26.0, 33.0]        # 两条宽轨的中心线（轨距 1.52m）

SPAWN = (7.0, 4.3)           # 锅炉房通风口外
EXIT = (7.0, 3.4)            # 撤离点：锅炉房通风口

# 道具：id, 资产名, 位置(底部中心), 碰撞脚印(w,d 米, 以底边为准向北延伸), 物理层, 可搜刮类型
# layer: 1=World_Wall_Full(挡视线) 2=Low_Cover_SteamPipe(蹲下挡视线) 3=Wire_Mesh_Fence(只挡路)
PROPS = [
    # --- 院子 ---
    dict(id="Bench", art="PRP_Bench_Snowy", pos=(18.5, 6.4), fp=(1.8, 0.5), layer=2),
    dict(id="Dumpster", art="PRP_Dumpster_Steel", pos=(29.0, 5.4), fp=(1.9, 1.1), layer=1,
         cont="dumpster"),
    dict(id="ElectricCabinet", art="PRP_Locker_ElectricCabinet", pos=(36.5, 3.75), fp=(0.9, 0.4),
         layer=1, cont="locker"),
    dict(id="Playground", art="PRP_Playground_Dome", pos=(12.5, 14.6), fp=(2.8, 2.6), layer=1),
    dict(id="Brazier", art="PRP_Brazier_OilDrum", pos=(24.0, 10.2), fp=(0.6, 0.45), layer=2),
    dict(id="CrateStack", art="PRP_Crate_Wood_Stack", pos=(3.6, 15.8), fp=(1.7, 0.85), layer=1,
         cont="crate"),
    dict(id="CarWreck", art="PRP_Car_Moskvich_Wreck", pos=(38.0, 16.0), fp=(4.4, 1.7), layer=1,
         cont="car"),
    dict(id="SteamPipe", art="PRP_SteamPipe_Long", pos=(18.0, 17.8), fp=(18.0, 0.55), layer=2),
    dict(id="FrozenBody", art="PRP_Corpse_Tarp", pos=(31.6, 19.0), fp=(1.7, 0.5), layer=0,
         cont="corpse"),
    dict(id="LampWest", art="PRP_StreetLamp_Sodium", pos=(3.4, 10.0), fp=(0.3, 0.25), layer=1),
    dict(id="LampEast", art="PRP_StreetLamp_Sodium", pos=(41.5, 11.2), fp=(0.3, 0.25), layer=1),
    # --- 货场 ---
    dict(id="SignalPost", art="PRP_SignalPost_Red", pos=(22.6, 28.0), fp=(0.3, 0.25), layer=1),
    dict(id="Boxcar03", art="PRP_Buran_Boxcar03", pos=(34.0, 34.4), fp=(14.0, 2.8), layer=1,
         cont="supply", reach=(0.0, 0.3), guaranteed="dial"),
    dict(id="WaterTower", art="PRP_WaterTower", pos=(15.0, 38.8), fp=(3.6, 2.4), layer=1),
    dict(id="Watchtower", art="PRP_Watchtower_Searchlight", pos=(45.2, 24.2), fp=(2.6, 1.3), layer=1),
    dict(id="SupplyCrates", art="PRP_SupplyCrates_Military", pos=(6.0, 38.0), fp=(1.9, 0.9), layer=1,
         cont="supply"),
]

# 铁丝网段：(x0, 资产)。每段 4m；豁口两侧用「撕裂」变体
FENCE_SEGMENTS = [(0.0, "a"), (4.0, "a"), (8.0, "b"), (12.0, "a"), (16.0, "torn"),
                  (23.5, "torn_l"), (27.5, "a"), (31.5, "b"), (35.5, "a"), (39.5, "a"), (43.5, "b")]

# 冻雪泥 / 黑冰（踩上去 速度×0.65 噪声×2）：cx, cy, rx, ry
SLUSH = [
    (17.0, 29.6, 3.4, 1.35),
    (33.0, 23.4, 3.6, 0.95),
    (10.0, 19.6, 2.4, 0.9),
    (36.0, 37.6, 3.2, 1.2),
    (24.0, 10.2, 2.2, 1.5),   # 火堆融雪圈
]

# 焦油黑雪
TAR_STAINS = [(28.0, 28.2, 1.4), (40.5, 37.4, 1.8), (4.8, 35.2, 1.2), (42.0, 30.0, 0.9)]

# 踩出来的雪径（折线）
PATHS = [
    [(7.0, 3.6), (8.6, 7.8), (14.0, 9.0), (20.0, 9.6), (24.0, 10.2)],
    [(24.0, 10.2), (23.0, 14.0), (21.8, 19.0), (21.8, 22.5), (22.2, 27.0), (24.0, 30.0)],
    [(24.0, 10.2), (29.0, 8.4), (34.0, 7.4), (44.0, 7.4)],
    [(24.0, 30.0), (30.0, 29.6), (40.0, 29.6), (44.0, 28.0)],
]

# 灯具（ground light 带阴影 + objects light 不带阴影）
LIGHTS = dict(
    brazier=(24.0, 10.2),
    lamp_west=(3.4, 10.0),
    lamp_east=(41.5, 11.2),
    signal=(22.6, 28.0),
    terminal=(19.6, 3.0),
)

# 清杀队巡逻（世界米坐标），mode: loop | pingpong
PATROLS = [
    dict(id="OSK_Rail", mode="pingpong", pts=[(4.0, 29.6), (42.0, 29.6)], pause=2.6),
    dict(id="OSK_Yard", mode="loop", pts=[(33.0, 7.6), (45.0, 7.6), (45.0, 19.2), (33.0, 19.2)],
         pause=1.8),
]

# 灰鳞狂暴者（CHR_03）：home = 游荡中心；brute = 壮硕变体（慢、咬得重、更耐打）
# 摆位思路：都不在清杀兵的常规光锥里 —— 想让清杀队替你动手，得先用罐头 / 脚步把它们引过去。
RABIDS = [
    dict(id="Rabid_Car", home=(38.5, 12.6), radius=2.2, brute=False),      # 报废车北侧，靠近冻尸
    dict(id="Rabid_West", home=(5.5, 18.6), radius=2.8, brute=False),      # 西院木箱堆旁，挡在去豁口的路上
    dict(id="Rabid_Tower", home=(10.5, 36.8), radius=2.5, brute=False),    # 煤水塔西侧
    dict(id="Rabid_Brute", home=(36.5, 36.7), radius=1.8, brute=True),     # 守在三号车厢门口
]

# 探照灯塔：灯头世界位置 + 扫描角（度，0=东，90=南）
SEARCHLIGHT = dict(pos=(45.2, 24.2), sweep=(146.0, 188.0), period=11.0, range=26.0, half=11.0)

# 主立面上的关键点（x 米）
FACADE_FEATURES = dict(vent_x=7.0, door_x=22.0, terminal_x=19.6, board_x=26.4)
