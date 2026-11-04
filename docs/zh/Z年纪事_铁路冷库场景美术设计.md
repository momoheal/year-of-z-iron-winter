# Z年纪事 · 第一幕《城北四号铁路冷库（账面死人）》场景美术设计与接入（coldstore）

> 2026-11 · v4.2 七幕结构第一幕 1-3 的**夜潜舞台**（`levels/coldstore.py` → `scenes/night_coldstore.tscn`）。
> 一句话：**这张图的美术只讲一件事——档案说这里没有人，可柱子后面全是活人。**
> 风格依据：`assets/concept_art/ART_STYLE_REFERENCE_v4.2.md` + 总剧本 v4.2 场次 1-3（白昼冷库段）+ LOCS 提示语。

---

## 一、场景定位（设计锚点）

| 项 | 内容 |
|---|---|
| 剧本锚点 | 总剧本 v4.2 场次 1-3 白昼段：阿列克谢随切尔诺夫中士到**城北四号铁路冷库**搬运封口膜与医疗耗材；在南库 3 号立柱后遇到被转运车遗落、冻得濒死发紫的**谢尔盖与玛丽亚母子**；磁卡终端跳红字 `【档案0892：已于昨日22:00移交乌拉尔山线站。当前南库坐标在册人数：0】`，配给箱电子锁直接锁死 |
| 关卡代号 | **coldstore**（LOCS 第 1 条；危险度 2 / 夜长 80 分钟 ≈192 秒 / 寒冷 0.9） |
| 玩法定位 | **「账面死人」关**：低战斗压力、高叙事密度。核心是「档案 vs 活人」的对照 + **撬棍卡死铁门**机制（LOCS hint2 原话） |
| 关键物资 | **abx**（封存医疗耗材箱里的抗生素——「据说封着一批医疗耗材」里最硬的货；与 market 抢的盘尼西林互文：**真药到底在哪**） |
| 叙事意象 | 磁卡终端的红字「在册人数：0」、配给箱电子锁、南库 3 号柱后的母子、北雨棚 12cm 排水窄缝里刮烂的胳膊、废弃收发亭、冻死在货堆旁的装卸工 |
| 出生 / 撤离 | **从北侧月台走进来**（白区开局：先过「账面在册」的月台，再下到「账面死人」的南库）；撤离 = 铁路专用线侧铁丝网豁口 |

**剧本-美术一致性纪律**（对齐《美术风格参考 v4.2》）：

1. **账面 vs 活人**是全图唯一的戏剧：终端屏幕只画**红字块**（不写具体字，避免乱码文字），配给箱画**电子锁的冷光**，
   3 号柱后画**两个依偎的人形**（母子，静态立绘，不画濒死惨状——他们活着，这就够了）；
2. **12cm 排水窄缝**只画**缝、霜、一只被刮烂的铝饭盒**——胳膊在白天出现过，夜里只有痕迹（同 market 烫鳞的「工具与痕迹」纪律）；
3. 冷库的恐怖是**卫生的恐怖**：冷白日光灯照着一切，霜挂整齐，货架笔直——越干净越冷；
4. 暖色纪律：**全图暖色只代表「有人在给自己烧火」**——值班室的火炉、工人的火桶、月台钠灯。
   **他们烤着火，账面在冻死人**——这就是这张图的「暖色即邪恶」；
5. 冷暖对比 = 身份对比：月台（暖、有人管）→ 南库（冷白、账面没人）→ 3 号柱（一丝体温）。

---

## 二、色彩脚本与光照设计（对齐 CON_01）

| 层 | 色 | 说明 |
|---|---|---|
| 雪底 | `#95a4b6 → #d8e1ea` | 共用配方（bake_ground） |
| 保温板 | `#8a97a4 / #6c7a88` | 冷库板墙灰蓝 + 霜挂 `#dfe8f0` |
| 冷白灯 | `#cfe0ee` | 南库吊灯——全图最冷的一块光 |
| 值班暖光 | `#f2b866 / #ffd9a0` | 火炉 / 火桶 / 钠灯——「有人在给自己烧火」 |
| 终端红字 | `#e0442e` | 磁卡终端的红色显示屏（全图唯一的红） |
| 封条 | `#c9c2a8` + 红十字 `#a03428` | 封存医疗箱的封条与十字 |
| 夜色 CanvasModulate | `#455273`（共用） | 冷调夜色 |

**LIGHTS / LIGHT_RIG（固定顺序）**：

| key | 类型 | 位置（米） | 色 | 用途 |
|---|---|---|---|---|
| `facade_glow` | 窗光 | 立面贴图自带 | 橙 | 值班室小窗（暖）+ 铁路大门灯 |
| `lamp_dock` | 钠灯 | (12.5, 5.4) | 黄 | 月台灯——出生点的光 |
| `lamp_hall` | **冷白吊灯** | (24.5, 24.6) | **蓝白**（`LIGHT_COLORS`） | 南库吊灯——账面死人的光 |
| `brazier_duty` | 火炉 | (7.0, 25.2) | 橙 | 值班室火炉（回温点 1） |
| `brazier_worker` | 火桶 | (41.0, 25.2) | 橙 | 装卸工人的火桶（回温点 2） |

`LIGHT_RIG = ["facade_glow", "lamp_dock", "lamp_hall", "brazier_duty", "brazier_worker"]`
`LIGHT_SEEDS = dict(lamp_dock=5, lamp_hall=17)`
`LIGHT_COLORS = dict(lamp_hall=(0.72, 0.85, 1.0))` ← **新机制**：`_rig_lamp` 读 `LY.LIGHT_COLORS[key]`
覆盖默认琥珀色（向后兼容：不定义的关卡照旧）。

**SEARCHLIGHT = None**（危险度 2：冷库的恐怖在灯下，不在光柱里）。

`AMBIENCE = ["wind", "fire", "steam", "buzz"]`（steam = 冷风机化霜白汽；buzz = 荧光灯镇流器）。

---

## 三、平面图与三带（46 × 34 米）

```text
      0        8        16       24       32       40      46
    0 ┌──────────────────────────────────────────────────────┐
    3 │ ▤▤▤冷库主楼：保温板+冷风机+值班窗+铁路大门(26) ▤▤▤ │ 北立面 coldstore
    5 │ 月台灯 收发亭 磁卡终端 配给箱  破损管▬▬▬▬▬▬  排水缝 │ 月台（白区）↑出生
   10 │   电柜     封存耗材(托盘)        木箱      垃圾箱    │
   13 │   货架1           货架2            货架3             │ 堆场（红区）
   20 │                                                      │
   22 │ 值班炉🔥 1号柱  2号柱  3号柱★母子  4号柱  冷库铁门▣  │ 南库（黑区）
   25 │ 真药箱▣(abx)        吊灯(冷白)            冻尸 火桶🔥│
   27 │ ═════════ 铁路专用线（y=27.0）+ 冷藏车皮 ═══════════ │
   29 │ 感染者  撕裂网  ╳豁口╳  撕裂网      感染者           │ 南侧铁丝网(33.2)
   34 └──────────────────────────────────────────────────────┘
                              ↑ 撤离 (22.0, 32.6)
```

**三带**（规则同《三区与黑市》；轴 = 离「账面在册」的地方越远越黑）：

| 区 | y 范围 | 地带 | 丧尸 | 玩法 |
|---|---|---|---|---|
| 白区 | 0 – 11 | 月台（收发亭、磁卡终端、配给箱——「在册」的地方） | 0 | safe：可以站定了搜包 |
| 红区 | 11 – 21 | 堆场（货架、托盘、车皮——「账上有货」的地方） | 0 | curfew：不能停——`OSK_Dock` 巡逻盘问链 |
| 黑区 | 21 – 34 | 南库（柱列、3 号柱的活人、封存药、铁轨） | 2 | sunken：`loot_bonus` + **账面死人的全部戏在这里** |

`SPAWN = (8.0, 4.6)`（月台）；`EXIT = (22.0, 32.6)`（铁路侧豁口）；
`FENCE_Y = 33.2`，`FENCE_GAP = (20.5, 23.5)`；`TRACKS = [27.0]`（铁路专用线——离围栏 6.2 m，
围栏贴图 3.93 m 高的铁律见 market 设计文档）；`SLAB_BAND = (3.0, 9.0)`（月台是混凝土）。

---

## 四、摆位表（PROPS / 演员 / 容器 / 机关）

### 4.1 道具（id, 资产, 位置(米), 容器, 备注）

| id | 资产 | 位置 | 容器 | 说明 |
|---|---|---|---|---|
| `DockLamp` | `PRP_StreetLamp_Sodium`（复用） | (12.5, 5.4) | — | 月台灯 |
| `DutyBooth` | `PRP_Shanty_Shed`（复用） | (8.0, 23.6) | — | **收发亭 / 值班室**（板房+炉筒=暖） |
| `CardTerminal` | `PRP_CardTerminal`（**新**） | (14.5, 5.2) | — | **磁卡终端**：红字屏「在册人数：0」的载体 |
| `RationBox` | `PRP_SupplyCrates_Military`（复用） | (18.0, 5.0) | supply | **配给箱**（电子锁锁死的那箱） |
| `SteamPipe` | `PRP_SteamPipe_Long`（复用） | (30.0, 8.2) | fp(12) | 破损供暖管（steam 声源） |
| `Locker` | `PRP_Locker_ElectricCabinet`（复用） | (5.0, 7.8) | locker | |
| `DrainSlit` | `PRP_DrainSlit`（**新**） | (33.5, 3.9) | — | **12cm 排水窄缝**+ 刮烂的铝饭盒（只有痕迹） |
| `Rack01` | `PRP_Crate_Wood_Stack`（复用） | (10.0, 14.5) | crate | 堆场货架 |
| `Rack02` | `PRP_Crate_Wood_Stack`（复用） | (24.0, 15.5) | crate | |
| `Rack03` | `PRP_Crate_Wood_Stack`（复用） | (38.0, 14.5) | crate | |
| `Dumpster` | `PRP_Dumpster_Steel`（复用） | (43.0, 12.0) | dumpster | |
| `Column01` | `PRP_VaultColumn`（**新**） | (14.0, 23.5) | — | 南库立柱（霜挂 + 柱号牌） |
| `Column02` | `PRP_VaultColumn`（新） | (19.5, 23.5) | — | |
| `Column03` | `PRP_VaultColumn`（新） | (25.0, 23.5) | — | ★ **3 号柱**：母子就缩在柱后 |
| `Column04` | `PRP_VaultColumn`（新） | (30.5, 23.5) | — | |
| `SealedMeds` | `PRP_SealedMedCrate`（**新**） | (11.5, 25.2) | medcab，**guaranteed `abx`** | ★ **封存医疗耗材箱**（封条 + 红十字） |
| `ColdVaultDoor` | `PRP_ColdVaultDoor`（**新**） | (37.5, 23.6) | — | ★ **冷库铁门**（`wedge` 机关的载体） |
| `Freezer` | `PRP_ColdStore_Chest`（复用） | (33.0, 25.4) | fridge | 药房冷柜 |
| `Corpse` | `PRP_Corpse_Tarp`（复用） | (28.5, 27.2) | corpse | 冻死在专用线上的装卸工 |
| `WorkerFire` | `PRP_Brazier_OilDrum`（复用） | (41.0, 25.2) | fire | 工人火桶（回温点 2） |
| `DutyFire` | `PRP_Brazier_OilDrum`（复用） | (9.2, 25.2) | fire | 值班室火炉（回温点 1） |
| `Reefer` | `PRP_Buran_Boxcar03`（复用） | (2.0, 27.0) | — | **冷藏车皮**（专用线西端、探出画面西缘——11 m 车体不许埋住封存药箱） |

### 4.2 演员（survivors = 2 人，3 号柱后）

| 角色 | 位置 | 说明 |
|---|---|---|
| Sergey（Survivor_0） | (24.2, 24.8) | 被转运车遗落的男子，通行证查无此人 |
| Maria（Survivor_1） | (25.8, 25.0) | 母亲，把孩子护在怀里 |

### 4.3 巡逻 / 感染者 / 半人

| 组 | 模式 | 路线 / 位置 | 说明 |
|---|---|---|---|
| `OSK_Dock` | loop | (12,13)→(36,13)→(36,20)→(12,20) | 堆场巡逻——红区「不能停」 |
| `OSK_Rail` | pingpong | (20,28.2)→(42,28.2) | 专用线哨兵 |
| `Rabid_Rail` | 固定 | (39.0, 27.4) r2.2 | 专用线上的感染者 |
| `Rabid_Store` | 固定 | (4.5, 27.6) r2.2 | 南库角落的感染者 |
| 半人 | — | **无** | 1-3 的回退半人在 yard（探照灯下的母亲）；冷库是账面死人的舞台 |

`LEVEL_RULES["coldstore"] = {"black_min": 2, "red_max": 1, "market": false}`。

### 4.4 机关（LevelBeats `mechanisms` → NightExplore `use_mechanism`）

| kind | 节点 | 提示 | 效果 |
|---|---|---|---|
| **`wedge`**（新） | `World/Props/ColdVaultDoor` | 「用撬棍卡死铁门（把它们引过去）」 | `crowbar_hit`+`wedge` 音、12 m 噪声诱离、浮字「铁门砰地卡死——它们撞在门上，却进不来了」（P2：真封门阻挡留给 AI） |

`use_mechanism` 补 `"wedge"` 分支；`LevelBeats._mechanism_names` 补 `"wedge": "卡死铁门"`。

### 4.5 地表（bake_ground 配方）

`SLUSH` = [(7.0,25.2,1.7,1.1), (41.0,25.2,1.7,1.1), (24.5,24.6,2.2,1.2), (12.5,5.4,2.2,1.0)]（火边与灯下融雪）；
`TAR_STAINS` = [(20,20,1.2), (38,17,1.0), (9,25.6,1.1), (42,25.0,1.0)]；
`GRAVEL` = [(36,28.6,3.5,1.2), (6,22,3.0,1.2), (30,21,3.0,1.0)]；
`PATHS` = 月台→南库主径、→3 号柱、→冷库铁门、→越铁轨到豁口 四条折线；
`ASPHALT = []`；`MELT_BANDS = None`。

---

## 五、资产清单（美术成果）

### 5.1 新增（本关专属）

| 资产 | 尺寸（约） | 生成器 | Prompt 规格书 |
|---|---|---|---|
| `TIL_Facade_ColdStore_A` | 2944×600 | `gen_env._facade_coldstore()` | §7.10 |
| `VFX_Facade_WindowGlow_ColdStore` | 2944×770 | `_facade_glow()`（共用） | — |
| `TIL_Ground_NightColdStore_Baked` | 2944×1349 | `bake_ground()`（共用配方） | — |
| `PRP_CardTerminal` | ~170×160 | `gen_props.card_terminal()` | §7.10 |
| `PRP_VaultColumn` | ~110×230 | `gen_props.vault_column()` | §7.10 |
| `PRP_SealedMedCrate` | ~150×110 | `gen_props.sealed_med_crate()` | §7.10 |
| `PRP_ColdVaultDoor` | ~300×220 | `gen_props.cold_vault_door()` | §7.10 |
| `PRP_DrainSlit` | ~240×90 | `gen_props.drain_slit()` | §7.10 |

### 5.2 复用（manifest 条目从旧关 manifest 复制 JSON，不重出图）

CHR_01/03/04/05 · `PRP_Shanty_Shed`（market）· `PRP_ColdStore_Chest`（manor）·
`PRP_Buran_Boxcar03`（marshalling）· `PRP_StreetLamp_Sodium` · `PRP_Brazier_OilDrum` · `PRP_SteamPipe_Long` ·
`PRP_Locker_ElectricCabinet` · `PRP_Crate_Wood_Stack` · `PRP_SupplyCrates_Military` · `PRP_Dumpster_Steel` ·
`PRP_Corpse_Tarp` · `PRP_Fence_ChainLink_*` · 全部 VFX / AMB_*。

> **铁律**（同 mine / market）：`--only` 只出新资产；共享 manifest 条目复制 JSON（byte-identical）；
> 道具所有笔画留在画布内（顶边检查）；铁轨离围栏 ≥ 4 m。

---

## 六、接入与验收

### 6.0 接入文件（一次性清单）

| 文件 | 改什么 |
|---|---|
| `tools/art_gen/levels/coldstore.py` + `levels/__init__.py` | 关卡规格 + 注册 |
| `tools/art_gen/gen_props.py` | 5 件新道具 + `ALL` 注册 |
| `tools/art_gen/gen_env.py` | `_facade_coldstore()` + `facade_keys` / `bake_facade` 分派 |
| `tools/art_gen/check_levels.py` | 立面白名单 + `coldstore` |
| `tools/art_gen/build_scene.py` | `_rig_lamp` 支持 `LIGHT_COLORS`（可选，向后兼容） |
| `tools/art_gen/render_preview.py` | `SCENES` / `CROPS` |
| `tools/art_gen/build_acceptance_page.py` | `SHEETS` 三张（grey / night / outpost） |
| `godot_project/scripts/CampaignData.gd` | LOCS `coldstore` 条目补 `"scene"` 字段 |
| `godot_project/scripts/night/LevelBeats.gd` | `LEVELS.coldstore` 档案层 + 机关名 `wedge` |
| `godot_project/scripts/night/NightExplore.gd` | `use_mechanism` 补 `wedge` 分支 |
| `godot_project/tests/night_level_smoke.gd` | `_coldstore()` 段 + 场景计数 5→6 |
| `godot_project/tests/night_zones_smoke.gd` | SCENES + SPAWN_ZONE（white）+ `LEVEL_RULES.coldstore` |
| `godot_project/tests/night_beats_smoke.gd` | `_coldstore()` 段（档案 + 机关断言） |

### 6.1 管线命令（`godot_project/tools/art_gen` 下）

```bash
python gen_assets.py --level coldstore ground facade
python gen_assets.py --level coldstore props --only PRP_CardTerminal,PRP_VaultColumn,PRP_SealedMedCrate,PRP_ColdVaultDoor,PRP_DrainSlit
python build_scene.py --level coldstore
python check_levels.py                                          # 六关全过
python render_preview.py --level coldstore
python3 godot_project/tools/art_gen/build_acceptance_page.py
```

### 6.2 验收标准（check_levels + 目测）

- [ ] `check_levels.py` 六关 PASS
- [ ] 三带（0–11 / 11–21 / 21–34）一致；出生点白区、3 号柱母子在黑区
- [ ] **账面 vs 活人对照一眼读得出**：终端红字块 + 配给箱电子锁冷光 vs 3 号柱后依偎的人形
- [ ] 排水窄缝「只有痕迹」：缝、霜、刮烂的铝饭盒——不画胳膊
- [ ] 暖色只在：值班室火炉、工人火桶、月台钠灯、值班窗——**烤着火的人 vs 账面死人**
- [ ] 南库吊灯是**冷白**（`LIGHT_COLORS` 生效），是全图最冷的一块光
- [ ] 关键物资 abx 只在 SealedMeds；冷库铁门挂着 `wedge` 机关
- [ ] grey / night 两版：夜色版能一眼读出「月台暖、南库冷白、终端血红」三层
- [ ] 道具画布无裁切；铁轨离围栏 6.2 m 完整可读
- [ ] 四套 Godot smoke 断言同步——沙箱无引擎，合并前需本地跑

### 6.3 与概念图的对照

| 概念图 | 本关落点 |
|---|---|
| 05 号图（人物群像） | Sergey / Maria 立绘（`PRP_Survivor_Stand` 复用） |
| **1-3 剧本原文** | 磁卡终端红字 / 3 号柱 / 排水窄缝 / 双面工作日志（日志是 UI 层，不出图） |

---

> **最后一句**：这张图的美术验收标准只有一条——**玩家看着那块红色显示屏，再看看柱子后面抱在一起的两个人，必须想砸了那台终端**。
> 冷白灯把一切都照得很干净。这就是账面死人。
