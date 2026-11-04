# Z年纪事 · 第三幕《铁路黑市（废弃工人镇）》场景美术设计与接入（market）

> 2026-11 · v4.2 七幕结构第三幕 3-3 的**夜潜舞台**（`levels/market.py` → `scenes/night_market.tscn`）。
> 一句话：**这张图的美术只讲一件事——在这条街上，救人和骗人用的是同一盏灯。**
> 风格依据：`assets/concept_art/ART_STYLE_REFERENCE_v4.2.md` + CON_05（黑市商贩群像）+ CON_07（6.66 MHz 烙铁烫鳞）+ 总剧本 v4.2 场次 3-3。

---

## 一、场景定位（设计锚点）

| 项 | 内容 |
|---|---|
| 剧本锚点 | 总剧本 v4.2 场次 3-3「夜潜黑市**抉择 C** 与松林庄园的『焦油黑雪』」前半：穿过互不信任的废弃工人镇，摸进铁路边的黑市交易点 |
| 关卡代号 | **market**（LOCS 第 7 条；危险度 2 / 夜长 80 分钟 ≈192 秒 / 寒冷 0.9——人比冷可怕，但人还肯讲理） |
| 玩法定位 | 交易与抉择关：低战斗压力、高叙事密度。**抉择 C**（C1 公平合作 / C2 锁门背叛抢盘尼西林与门禁磁卡 / C3 倾囊相助）+ **6.66 MHz 辨药**（看色 / 闻味 / 试喂三分法）的场景载体 |
| 关键物资 | **intel**（6.66 电台棚里的专列调度记录——C1 线「共同摸清专列路线」的物证；也是可交易情报） |
| 叙事意象 | 钉死在 6.66 MHz 的短波收音机与女声循环、烙铁烫鳞的炭炉后巷、掺防冻液的假药与被挤到角落的真药、**药棚铁门**（C2 的锁点）、老谢苗与拾荒老妇 |
| 出生 / 撤离 | **从北侧镇口走进来**（白区开局：先穿过人的地盘，再下到黑里）；撤离 = 铁路侧铁丝网豁口 |

**剧本-美术一致性纪律**（对齐《美术风格参考 v4.2》）：

1. 6.66 MHz 是**清杀队的鱼钩**：收音机棚要画得像生意、不像祭坛；女声循环靠音频层（P2 配音），
   画面只给「指针钉死」的刻度特写载体——**绝不做魔法绿光**，只有老电子管的病态微绿
   （夜色下是「最病的一团光」，可以做辉光晕，但色相必须是电子管绿，不是荧光绿）；
2. 烙铁烫鳞是**给死人化妆**：炭炉、烧红的马蹄铁、折叠凳、焦臭的皮肉味留给文字——
   画面上只有**工具**和**痕迹**（烫焦的绷带、地上的人形灰印），不画行刑现场；
3. 假药与真药**摆在一起**：防冻液假药瓶贴花哨商标，真药朴素无华——辨药小玩法的全部信息在道具画里；
4. 暖色纪律：**全图暖色只代表「有人在守着自己的生意」**——马灯、炭炉、篝火、窗洞。
   最暖的一块光在摊区（人的规矩），最恶的一块光在烫鳞炭炉（值守邪恶），最病的一块光在 6.66 棚里（骗人的规矩）；
5. 老谢苗是**重伤幸存者**（不是半人、不是狂暴者）：站在药棚铁门旁，姿态是「等着」，不是「求着」。

---

## 二、色彩脚本与光照设计（对齐 CON_01）

| 层 | 色 | 说明 |
|---|---|---|
| 雪底 | `#95a4b6 → #d8e1ea` | 共用配方（bake_ground） |
| 板房木 | `#6b5138 / #555b62` | 棚户板墙棕灰、柏油纸屋顶深灰 |
| 马灯 / 篝火 | `#f2b866 / #ffd9a0` | 摊区暖光 = 全图最暖 |
| 6.66 电台 | `#cfe8a6`（病绿，收音机面板 + 辉光晕） | 老电子管微绿，不是魔法光 |
| 炭炉（烫鳞） | `#e0442e → #f08a3a` | 烧红的马蹄铁与炭火——暖色纪律里的「值守邪恶」 |
| 夜色 CanvasModulate | `#455273`（共用） | 冷调夜色 |

**LIGHTS / LIGHT_RIG（固定顺序）**：

| key | 类型 | 位置（米） | 色 | 用途 |
|---|---|---|---|---|
| `facade_glow` | 窗光 | 立面贴图自带 | 橙 | 板房排屋的两扇亮窗 + 镇口壁灯 |
| `lamp_nw` | 钠灯 | (12.5, 5.4) | 黄 | 镇口街中段街灯——出生点的光 |
| `lamp_se` | 钠灯 | (41.5, 22.5) | 黄 | 市集东缘的旧路灯 |
| `brazier_bazaar` | 火堆 | (28.5, 25.2) | 橙 | 市集篝火（回温点 1） |
| `brazier_forge` | 炭炉 | (7.0, 24.9) | 橙红 | 烫鳞后巷的炭炉（回温点 2——**暖色即邪恶**） |

`LIGHT_RIG = ["facade_glow", "lamp_nw", "lamp_se", "brazier_bazaar", "brazier_forge"]`
`LIGHT_SEEDS = dict(lamp_nw=5, lamp_se=13)`

**SEARCHLIGHT = None**（危险度 2：这里是人和人互相看着的地方，探照灯是外面的世界）。

`AMBIENCE = ["wind", "fire", "steam", "buzz"]`（steam 来自镇口街的破损供暖管 `PRP_SteamPipe_Long`）。

> 6.66 MHz 女声循环 = **P2 音频待办**（需要配音；先不做程序化占位——假人声会毁掉这段）。

---

## 三、平面图与三带（46 × 34 米）

```text
      0        8        16       24       32       40      46
    0 ┌──────────────────────────────────────────────────────┐
    3 │ ▤板房▤ 烟囱  ▤板房▤   板房  ▤板房▤ 烟囱 ▤板房▤   │  北立面 town（TIL_Facade_Town_A）
    5 │ 壁灯 规矩牌   破损供暖管▬▬▬▬▬▬▬▬▬▬▬▬▬▬  街灯      │  镇口街（白区）↑出生 (8.0,4.6)
   10 │   电柜                         木箱        垃圾箱    │
   13 │   板房01        板房02           板房03              │  棚户巷（红区）
   21 │                                                      │
   23 │ 药棚▣铁门  老谢苗 拾荒老妇 ▣假药摊  摊区▣(Market)    │  市集（黑区）
   25 │ 炭炉🔥(烫鳞)  真药箱       篝火🔥  6.66棚(天线)▤ 冻尸│
   27 │ ═══════════════ 铁路 1 道（y=27.0）══════════════════ │
   29 │ 感染者  撕裂网  ╳豁口╳  撕裂网      感染者           │  南侧铁丝网（y=33.2）
   34 └──────────────────────────────────────────────────────┘
                              ↑ 撤离 (22.0, 32.6)
```

**三带**（规则同《三区与黑市》；轴 = 离「摊主规矩区」的距离——**黑市的老家，摊区就是黑区的中心**）：

| 区 | y 范围 | 地带 | 丧尸 | 玩法 |
|---|---|---|---|---|
| 白区 | 0 – 11 | 镇口街（规矩牌下、街灯里） | 0 | safe：可以站定了搜包 |
| 红区 | 11 – 21 | 棚户巷（各派系的地盘） | 0 | curfew：不能停——`OSK_Town` 巡逻盘问链 |
| 黑区 | 21 – 34 | 市集深处 + 铁路侧（摊区、6.66 棚、烫鳞后巷、药棚铁门） | 2 | sunken：`loot_bonus` + **抉择 C 全部发生在这里** |

`SPAWN = (8.0, 4.6)`（镇口街）；`EXIT = (22.0, 32.6)`（南侧豁口）；
`FENCE_Y = 33.2`，`FENCE_GAP = (20.5, 23.5)`；`TRACKS = [27.0]`（铁路 1 道）；
`SLAB_BAND = (3.0, 9.0)`（只有镇口街是旧沥青，往南全是踩实的雪与煤渣）。

> **⚠️ 围栏高度铁律（第一版返工教训）**：`PRP_Fence_ChainLink_*` 贴图高 **3.93 m**（266×156，
> pivot 148/156），站在 `FENCE_Y` 上会向上罩住整整 4 米。**轨道必须离 FENCE_Y ≥ 4 m**
> （本关 27.0 vs 33.2，净距 6.2 m），否则整条铁轨被铁丝网和雪堆吞掉、渲染出来直接消失。
> 建筑 / 摊位只许坐在轨道以北；**只有演员、感染者和冻尸可以上轨道**（铁轨上的冻尸=3-3 的踩雪声）。

---

## 四、摆位表（PROPS / 演员 / 容器）

### 4.1 道具（id, 资产, 位置(米), 容器, 备注）

| id | 资产 | 位置 | 容器 | 说明 |
|---|---|---|---|---|
| `StreetLamp` | `PRP_StreetLamp_Sodium`（复用） | (12.5, 5.4) | — | 镇口街灯（与立面壁灯错开） |
| `RulesBoard` | `PRP_DispatchBoard_Tin`（复用） | (7.5, 4.9) | — | **规矩牌**：「拿东西换东西」的木板（无字底图） |
| `SteamPipe` | `PRP_SteamPipe_Long`（复用） | (22.0, 8.2) | — | 破损供暖管（steam 声源 + 融雪带） |
| `Locker` | `PRP_Locker_ElectricCabinet`（复用） | (5.0, 7.8) | locker | |
| `TownCrates` | `PRP_Crate_Wood_Stack`（复用） | (30.0, 12.4) | crate | |
| `Dumpster` | `PRP_Dumpster_Steel`（复用） | (42.0, 12.8) | dumpster | |
| `Shanty01` | `PRP_Shanty_Shed`（**新**） | (10.0, 15.5) | — | 棚户巷板房（炉筒 + 烟） |
| `Shanty02` | `PRP_Shanty_Shed`（新） | (22.0, 17.0) | — | |
| `Shanty03` | `PRP_Shanty_Shed`（新） | (34.0, 15.0) | — | |
| `MedShed` | `PRP_MedShed`（**新**） | (12.0, 23.2) | — | **药棚 + 铁门**（C2 锁点：门禁磁卡读头 + 可锁死的挂环） |
| `MedFridge` | `PRP_ColdStore_Chest`（复用） | (12.8, 24.0) | fridge，**guaranteed `abx`** | C2 的盘尼西林 |
| `MedCache` | `PRP_MedCache`（**新**） | (10.6, 24.6) | medcab | **真药**（朴素白瓶） |
| `ShedCrates` | `PRP_Crate_Wood_Stack`（复用） | (13.9, 24.4) | crate | |
| `QuackForge` | `PRP_QuackForge`（**新**） | (7.0, 24.9) | — | 烫鳞后巷：炭炉 + 烧红马蹄铁 + 折叠凳（行刑者不在图上） |
| `MedStall` | `PRP_Market_Stall`（复用） | (19.0, 23.0) | — | **假药摊**（花哨商标） |
| `FakeMeds` | `PRP_MedCache`（新） | (19.2, 24.0) | medcab | **假药**（同款道具、摆位即对照） |
| `Market` | **MARKET 集群**（自动装配） | (24.5, 24.4) | — | 摊位 + 摊主 + 幸存者 + 马灯；cans=1 / ammo=8 |
| `BazaarFire` | `PRP_Brazier_OilDrum`（复用） | (28.5, 25.2) | — | 市集篝火（fire=True） |
| `SupplyCrates` | `PRP_SupplyCrates_Military`（复用） | (30.5, 23.6) | supply | |
| `Radio666` | `PRP_Radio666`（**新**） | (36.5, 25.0) | briefcase，**guaranteed `intel`** | **6.66 电台棚**（收音机 + 天线 + 假药瓶柜台）——「黑市最深的棚子」 |
| `Corpse` | `PRP_Corpse_Tarp`（复用） | (33.0, 27.0) | corpse | **冻死在铁轨上的拾荒者** |
| `LampEast` | `PRP_StreetLamp_Sodium`（复用） | (41.5, 22.5) | — | 市集东缘路灯 |

### 4.2 演员（MARKET 集群的 survivors 列表 = 4 人）

| 角色 | 位置 | 说明 |
|---|---|---|
| Trader（摊主） | (25.5, 24.8) | 红袖标，一罐换八发 |
| Survivor_0/1 | (23.0, 25.4) / (26.2, 25.6) | 摊边两人（烟测：5 m 内 ≥2 人） |
| **老谢苗**（Survivor_2） | (12.5, 24.6) | 重伤幸存者，守在药棚铁门旁——**抉择 C 的人** |
| **拾荒老妇**（Survivor_3） | (17.5, 25.2) | 快冻死在角落里（C3 的对象） |

### 4.3 巡逻 / 感染者 / 半人

| 组 | 模式 | 路线 / 位置 | 说明 |
|---|---|---|---|
| `OSK_Town` | loop | (12,13)→(36,13)→(36,20)→(12,20) | 棚户巷巡逻——红区「不能停」 |
| `OSK_Rail` | pingpong | (20,28.2)→(42,28.2) | 铁路哨兵，沿铁轨走——C2 里被老谢苗引开的就是他 |
| `Rabid_Rail` | 固定 | (39.0, 27.4) r2.2 | 铁轨上的感染者 |
| `Rabid_Alley` | 固定 | (4.5, 27.6) r2.2 | 后巷感染者 |
| 半人 | — | **无** | 本关没有回退半人（老谢苗是幸存者） |

`PATROL 总数 2 / RABID 总数 2 / HALF 0`；`night_zones_smoke` 的 `LEVEL_RULES["market"] =
{"black_min": 2, "red_max": 1, "market": True}`（低危交易关，尸是注脚）。

### 4.4 地表（bake_ground 配方）

`SLUSH` = [(28.5,25.2,2.0,1.3), (7.0,24.9,1.7,1.1), (24.5,24.6,2.4,1.3), (12.5,5.4,2.2,1.0)]（火边与灯下融雪）；
`TAR_STAINS` = [(20,20,1.2), (38,17,1.0), (9,25.6,1.1), (42,25.0,1.0)]（煤渣黑雪）；
`GRAVEL` = [(36,28.6,3.5,1.2), (6,22,3.0,1.2), (30,21,3.0,1.0)]；
`PATHS` = 镇口→市集主径、市集→药棚、市集→6.66 棚、市集→越铁轨到豁口 四条折线；
`ASPHALT = []`；`MELT_BANDS = None`（供暖管下自动烘融雪带）。

---

## 五、资产清单（美术成果）

### 5.1 新增（本关专属）

| 资产 | 尺寸（约） | 生成器 | Prompt 规格书 |
|---|---|---|---|
| `TIL_Facade_Town_A` | 2944×600 | `gen_env._facade_town()` | §7.9 |
| `VFX_Facade_WindowGlow_Town` | 2944×770 | `_facade_glow()`（共用） | — |
| `TIL_Ground_NightMarket_Baked` | 2944×1349 | `bake_ground()`（共用配方） | — |
| `PRP_Radio666` | 240×236 | `gen_props.radio666()` | §7.9 |
| `PRP_QuackForge` | 180×158 | `gen_props.quack_forge()` | §7.9 |
| `PRP_MedShed` | 260×230 | `gen_props.med_shed()` | §7.9 |
| `PRP_MedCache` | 150×108 | `gen_props.med_cache()` | §7.9 |
| `PRP_Shanty_Shed` | 260×260 | `gen_props.shanty_shed()` | §7.9 |

### 5.2 复用（manifest 自 yard/marshalling/manor 继承条目，不重出图）

CHR_01/03/04/05 · `PRP_Market_Stall` / `PRP_Trader_Stand` / `PRP_Survivor_Stand`（gen_market 三件套）·
`PRP_StreetLamp_Sodium` · `PRP_Brazier_OilDrum`+`VFX_Fire_Brazier_Sheet` · `PRP_SteamPipe_Long` ·
`PRP_Locker_ElectricCabinet` · `PRP_DispatchBoard_Tin` · `PRP_ColdStore_Chest` · `PRP_Crate_Wood_Stack` ·
`PRP_SupplyCrates_Military` · `PRP_Dumpster_Steel` · `PRP_Corpse_Tarp` · `PRP_Fence_ChainLink_*` · 全部 VFX / AMB_*。

> **铁律**（同矿坑）：生成新关卡资产一律 `--only`，绝不重跑旧资产；`PRP_DispatchBoard_Tin` /
> `PRP_ColdStore_Chest` 这类跨关共享道具的 manifest 条目从旧关 manifest **复制 JSON**（byte-identical），
> 绝不 `--only` 重出图。
>
> **道具画布铁律**：道具里所有笔画（天线、炉筒、烟、招牌）必须留在画布内——
> 基线 base 之上的高度要算进画布高度，负 y 会被直接裁掉（第一版 radio666 天线 / shanty 烟就是这样丢的）。
> 出图后跑一行顶边检查（`np.flatnonzero(alpha.any(1))[0]`）确认没有触顶截断。

---

## 六、接入与验收

### 6.0 接入文件（一次性清单）

| 文件 | 改什么 |
|---|---|
| `tools/art_gen/levels/market.py` + `levels/__init__.py` | 关卡规格（本设计文档的落地值）+ 注册 |
| `tools/art_gen/gen_props.py` | 5 件新道具 + `ALL` 注册 |
| `tools/art_gen/gen_env.py` | `_facade_town()` + `facade_keys` / `bake_facade` 分派 |
| `tools/art_gen/check_levels.py` | 立面白名单 + `town` |
| `tools/art_gen/render_preview.py` | `SCENES` / `CROPS` + market 特写窗 |
| `tools/art_gen/build_acceptance_page.py` | `SHEETS` 三张（grey / night / outpost） |
| `godot_project/scripts/CampaignData.gd` | LOCS `market` 条目补 `"scene"` 字段 |
| `godot_project/scripts/night/LevelBeats.gd` | `LEVELS.market` 档案层（厂标 / 简报 / 4 地标 / 无环境节拍） |
| `godot_project/tests/night_level_smoke.gd` | `_market()` 段 + 场景计数 4→5 |
| `godot_project/tests/night_zones_smoke.gd` | SCENES + SPAWN_ZONE（white）+ `LEVEL_RULES.market` |
| `godot_project/tests/night_beats_smoke.gd` | `_market()` 段（档案层 `_common` 口径） |

### 6.1 管线命令（`godot_project/tools/art_gen` 下）

```bash
python gen_assets.py --level market ground facade               # 地面 + 工人镇立面 + 窗光
python gen_assets.py --level market props --only PRP_Radio666,PRP_QuackForge,PRP_MedShed,PRP_MedCache,PRP_Shanty_Shed
python build_scene.py --level market                            # → scenes/night_market.tscn
python check_levels.py                                          # 五关全过（含 market）
python render_preview.py --level market                         # → docs/ui/verify/market_grey|night.png
python3 godot_project/tools/art_gen/build_acceptance_page.py    # 验收页收录
```

### 6.2 验收标准（check_levels + 目测）

- [x] `check_levels.py` 五关 PASS（market：spec 字段 / manifest 键 / 场景组数 / metadata / 镜头边界 / CampaignData 接线）
- [x] 三个区分界（0–11 / 11–21 / 21–34）与《三区与黑市》规则一致；出生点在白区、MARKET 集群在黑区
- [x] **辨药信息全在道具画里**：真药朴素、假药花哨，两者摆在一起（10.6 vs 19.2）——不靠 UI 标注
- [x] 烫鳞后巷「只有工具和痕迹」：炭炉、马蹄铁、凳子、烫焦的绷带——不画行刑现场
- [x] 全图暖色只出现在：两扇板房窗、镇口壁灯、两盏街灯、市集篝火、炭炉、马灯——炭炉最暖也最恶
- [x] 6.66 棚的收音机面板是**电子管微绿 + 辉光晕**，不是魔法绿光；夜色下是「最病的一团光」
- [x] 关键物资 intel 只在 Radio666 容器；盘尼西林（abx）只在 MedFridge
- [x] grey / night 两版：夜色版能一眼读出「摊区暖、6.66 病、后巷烫」三团光
- [x] 铁路 1 道离围栏 6.2 m，轨道 + 枕木完整可读，不糊成黑带；冻尸在铁轨上
- [x] 道具画布无裁切（天线 / 炉筒 / 烟全在画布内）
- [ ] 四套 Godot smoke 的断言同步——沙箱无引擎，合并前需本地跑

### 6.3 与 v4.2 概念图的对照

| 概念图 | 本关落点 |
|---|---|
| **CON_07**（6.66 MHz 烙铁烫鳞） | `PRP_QuackForge` 后巷 + `PRP_Radio666` 电台棚 |
| **05 号图**（人物群像：黑市商贩等） | Trader / Survivor 立绘（gen_market 三件套） |
| **CON_05**（柳德米拉大火托孤） | 不出现（第五幕的舞台） |

---

> **最后一句**：这张图的美术验收标准只有一条——**玩家扫一眼摊区，必须同时想救人和想骗人**。
> 马灯下的罐头与炭炉边的马蹄铁共用同一种橙色，这就是黑市。
